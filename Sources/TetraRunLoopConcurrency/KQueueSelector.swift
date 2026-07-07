//
//  KQueueSelector.swift
//  TetraRunLoopConcurrency
//
//  A STATELESS kqueue syscall wrapper. Holds NO state — every function takes the
//  raw descriptor. Ported from swift-platform-executors KQueueSelector2.swift.
//
//  * Wakeups use an `EVFILT_USER` event (ident 0).
//  * Timers use one-shot `EVFILT_TIMER` events in the mach clock domains
//    (idents 1/2/3 = continuous/suspending/wall, matching ClockIndex rawValues 0/1/2).
//

#if canImport(Darwin)
import Darwin
import Dispatch

/// Minimal error type for `kevent64(2)` failures, available at iOS 13 / macOS 10.15.
/// Callers only `assertionFailure`/`preconditionFailure` on catch, so the exact type
/// is cosmetic — `System.Errno` (macOS 11+) is intentionally avoided here.
struct KQueueSyscallError: Error {
    let code: Int32
}

/// Thin `kqueue` descriptor wrapper: issues `kevent64(2)` and surfaces failures as
/// `KQueueSyscallError`. `rawValue` is the kqueue file descriptor. Stateless — safe
/// to construct on demand around a descriptor from any thread.
struct KQueueHelper: RawRepresentable, @unchecked Sendable {
    var rawValue: Int32
    init(rawValue: Int32) { self.rawValue = rawValue }

    /// Direct `kevent64(2)` call. Returns the number of events placed in `eventlist`
    /// (0 for a pure registration); throws `Errno` on a -1 return.
    @discardableResult
    func kevent64(
        changelist: UnsafePointer<kevent64_s>?, nchanges: CInt,
        eventlist: UnsafeMutablePointer<kevent64_s>?, nevents: CInt,
        flags: UInt32, timeout: UnsafePointer<timespec>?
    ) throws -> CInt {
        let result = Darwin.kevent64(rawValue, changelist, nchanges, eventlist, nevents, flags, timeout)
        if result == -1 { throw KQueueSyscallError(code: errno) }
        return result
    }

    /// Registers a change set (no events collected): a pure `kevent64` registration.
    func applyEventChangeSet(_ changes: UnsafeMutableBufferPointer<kevent64_s>) throws {
        _ = try kevent64(
            changelist: UnsafePointer(changes.baseAddress), nchanges: CInt(changes.count),
            eventlist: nil, nevents: 0, flags: 0, timeout: nil
        )
    }
}

enum KQueueSelector {

    /// Which timer domains fired in a `drainEvents` pass. The engine uses this to
    /// clear the corresponding armed deadline under its timer mutex.
    struct FiredDomains {
        var continuous = false
        var suspending = false
        var wall = false
    }

    // MARK: Setup

    /// Creates a kqueue and registers the `EVFILT_USER` wakeup channel (ident 0).
    static func makeKQueue() -> Int32 {
        let fd = Darwin.kqueue()
        precondition(fd >= 0, "kqueue() failed: \(String(cString: strerror(errno)))")
        var event = kevent64_s()
        event.ident = 0
        event.filter = Int16(EVFILT_USER)
        event.fflags = UInt32(bitPattern: NOTE_FFNOP)
        event.flags = UInt16(EV_ADD | EV_ENABLE | EV_CLEAR)
        do {
            try withUnsafeMutablePointer(to: &event) {
                try KQueueHelper(rawValue: fd).applyEventChangeSet(
                    UnsafeMutableBufferPointer(start: $0, count: 1)
                )
            }
        } catch {
            preconditionFailure("Failed to install kqueue user event: \(error)")
        }
        return fd
    }

    // MARK: Wakeup

    /// Posts the `EVFILT_USER` wakeup, making the kqueue readable. Safe from any
    /// thread; touches no shared state beyond the descriptor.
    static func wakeup(fileDescriptor: Int32) {
        var event = kevent64_s()
        event.ident = 0
        event.filter = Int16(EVFILT_USER)
        event.fflags = UInt32(NOTE_TRIGGER | NOTE_FFNOP)
        do {
            _ = try withUnsafePointer(to: &event) {
                try KQueueHelper(rawValue: fileDescriptor).kevent64(
                    changelist: $0, nchanges: 1, eventlist: nil, nevents: 0,
                    flags: UInt32(KEVENT_FLAG_IMMEDIATE), timeout: nil
                )
            }
        } catch {
            preconditionFailure("Failed to signal kqueue wakeup: \(error)")
        }
    }

    // MARK: Drain

    /// Consumes pending events non-blocking; returns which timer domains fired.
    /// The `EVFILT_USER` wakeup is consumed and reported by no flag (it only
    /// exists to make the kqueue readable).
    static func drainEvents(fileDescriptor: Int32, maxEvents: Int = 8) -> FiredDomains {
        var fired = FiredDomains()
        withUnsafeTemporaryAllocation(of: kevent64_s.self, capacity: maxEvents) { buffer in
            do {
                let count = try KQueueHelper(rawValue: fileDescriptor).kevent64(
                    changelist: nil, nchanges: 0,
                    eventlist: buffer.baseAddress!, nevents: CInt(maxEvents),
                    flags: UInt32(KEVENT_FLAG_IMMEDIATE), timeout: nil
                )
                for index in 0..<Int(count) where Int32(buffer[index].filter) == EVFILT_TIMER {
                    switch buffer[index].ident {
                    case 1: fired.continuous = true
                    case 2: fired.suspending = true
                    case 3: fired.wall = true
                    default: assertionFailure("Unknown timer identifier: \(buffer[index].ident)")
                    }
                }
            } catch {
                assertionFailure("Failed to drain kqueue events: \(error)")
            }
        }
        return fired
    }

    // MARK: Clock

    /// The domain's current instant in the same units that `Timestamp.target` is stored in.
    static func now(index: SlicedJobQueue.ClockIndex) -> UInt64 {
        switch index {
        case .continuous:
            // continuous: __dispatch_time(1<<63, 0) & ~(1<<63)
            Dispatch.__dispatch_time(1 << 63, 0) & ~(1 << 63)
        case .suspending:
            // suspending: __dispatch_time(0, 0)
            Dispatch.__dispatch_time(0, 0)
        case .walltime:
            // walltime: 0 &- __dispatch_walltime(nil, 0)
            0 &- Dispatch.__dispatch_walltime(nil, 0)
        }
    }

    // MARK: Arm

    /// Arms (or replaces) the one-shot timer for `index`. Re-arming the same
    /// ident replaces the prior arming, so a producer installing an earlier
    /// deadline overwrites a later one. `data` is the interval in the domain's
    /// mach units; a past deadline arms `0`, firing immediately.
    ///
    /// - Parameters:
    ///   - fileDescriptor: The kqueue file descriptor.
    ///   - index: The clock domain (`SlicedJobQueue.ClockIndex`).
    ///   - target: The earliest acceptable instant (same units as `now(index:)`).
    ///   - leeway: Leeway window for timer coalescing (0 = no leeway).
    ///   - now: The current instant from `now(index:)` for computing the interval.
    static func armTimer(
        fileDescriptor: Int32,
        index: SlicedJobQueue.ClockIndex,
        target: UInt64,
        leeway: UInt64,
        now: UInt64
    ) {
        var event = kevent64_s()
        event.filter = Int16(EVFILT_TIMER)
        event.flags = UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT)
        event.data = target > now ? Int64(target - now) : 0
        switch index {
        case .continuous:
            // ident 1, fflags: NOTE_MACH_CONTINUOUS_TIME | NOTE_MACHTIME
            event.ident = 1
            event.fflags = UInt32(NOTE_MACH_CONTINUOUS_TIME | NOTE_MACHTIME)
        case .suspending:
            // ident 2, fflags: NOTE_MACHTIME
            event.ident = 2
            event.fflags = UInt32(NOTE_MACHTIME)
        case .walltime:
            // ident 3, fflags: NOTE_NSECONDS | NOTE_MACH_CONTINUOUS_TIME
            event.ident = 3
            event.fflags = UInt32(NOTE_NSECONDS | NOTE_MACH_CONTINUOUS_TIME)
        }
        if leeway != 0 {
            event.fflags |= UInt32(NOTE_LEEWAY)
            event.ext = (event.ext.0, leeway)
        }
        do {
            try withUnsafeMutablePointer(to: &event) {
                try KQueueHelper(rawValue: fileDescriptor).applyEventChangeSet(
                    UnsafeMutableBufferPointer(start: $0, count: 1)
                )
            }
        } catch {
            assertionFailure("Failed to arm kqueue timer: \(error)")
        }
    }
}
#endif
