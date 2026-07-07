//
//  KQScheduler.swift
//  TetraRunLoopConcurrency
//
//  The kqueue run-loop ENGINE. Ported from swift-platform-executors'
//  `KQScheduler2` (the engine half of `StackBoundRunLoopExecutor2`), adapted to
//  Tetra's primitives:
//
//    * `AtomicStore` (not Synchronization `Atomic`) for the phase / wake / stop flags.
//    * `SlicedJobQueue` (ready lanes only) for the 5-QoS ready queues.
//    * The timer state lives HERE (DESIGN A): three `Heap<TimestampJob>` domains
//      behind one `createCheckedStateLock`, replacing the reference's `MinMaxHeap`
//      `TimerState`. The queue no longer owns any timer state.
//
//  The engine wraps the kqueue in a CFFileDescriptor run-loop source, drains the
//  ready lanes in `handleReadable`, fires due timers into the ready lanes, and arms
//  the earliest pending deadline per domain via `EVFILT_TIMER`.
//

#if canImport(Darwin)
import Atomics
import Darwin
import Dispatch
import Foundation
import CoreFoundation
import CriticalSection
import HeapModule
import Builtin

@available(macOS 10.15, iOS 13, *)
final class KQScheduler: @unchecked Sendable {

    /// Lifecycle phase. Stored as a raw `UInt8` in an `AtomicStore` (Tetra's atomic
    /// primitive), since `AtomicStore` requires `Value: AtomicValue`.
    enum Phase: UInt8 { case live = 0, closing = 1, dead = 2 }

    // MARK: Stored state

    private let facade: StackBoundRunLoopExecutor
    private let serial: UnownedSerialExecutor
    /// Optional task-executor reference threaded through to `processLane`.
    private let taskRefOrNil: Builtin.Executor?
    let cfRunLoop: CFRunLoop
    let thread: pthread_t
    /// Raw kqueue descriptor, valid from init; exposed for cross-thread wakeups.
    let kqueueFD: Int32

    /// The 5-QoS ready lanes. Drained (only) by `drainReadyJobs` on the owning thread.
    let ready = SlicedJobQueue(cacheSize: 2048)

    /// Pending-timer heaps and the armed-deadline record, per clock domain, together
    /// behind one lock — the reference engine's `TimerState` shape. Producers arm the
    /// kqueue `EVFILT_TIMER` directly under this lock (`kevent64` is thread-safe), so
    /// there is no producer/owning-thread split-brain over the armed idents and no
    /// `EVFILT_USER` wakeup per timer enqueue.
    struct TimerState {
        /// Monotonic insertion counter — the FIFO tie-break for equal deadlines.
        var sequence: UInt64 = 0
        /// One min-heap per clock domain — continuous / suspending / wall. MOVED here
        /// from `SlicedJobQueue` (DESIGN A).
        var heaps: ThreeElement<Heap<TimestampJob>> = .init(repeating: .init())
        /// The deadline currently armed on the kqueue per domain (`nil` = unarmed).
        /// `armIfEarlierLocked` re-arms a domain only when the candidate is strictly
        /// earlier than what is armed, and one-shot fires clear the entry —
        /// eliminating the per-pump re-arm `kevent64` thrash of unconditional arming.
        var armed: ThreeElement<Timestamp?> = .init(repeating: nil)
    }

    let timers: some UnfairStateLock<TimerState> =
        createCheckedStateLock(checkedState: TimerState())

    /// Timers currently in the heaps. Lets the drain pump skip the whole timer pass
    /// (no lock, no clock reads) when zero — the common, timer-free case.
    private let timerCount = ManagedAtomic<Int>(0)

    /// Owning-thread-only scratch for due jobs, so fired timer jobs are moved into
    /// the ready lanes OUTSIDE the timer lock; reused so steady state allocates nothing.
    private nonisolated(unsafe) var dueBuffer = ContiguousArray<UnownedJob>()

    /// Arm `index` if `candidate` is strictly earlier than what is armed (or nothing
    /// is). Caller holds `timers`. Reads the domain clock only when it actually arms.
    private func armIfEarlierLocked(_ state: inout TimerState, index: SlicedJobQueue.ClockIndex, candidate: Timestamp) {
        let raw = index.rawValue
        if let armedStamp = state.armed[raw], candidate.deadline >= armedStamp.deadline { return }
        KQueueSelector.armTimer(fileDescriptor: kqueueFD, index: index,
                                target: candidate.target, leeway: candidate.leeway,
                                now: KQueueSelector.now(index: index))
        state.armed[raw] = candidate
    }

    /// True while a drain is pending/imminent; producers elide the wakeup when they
    /// lose the false→true race. RMW-only (see `handleReadable`).
    private let pendingJobPop = AtomicStore<Bool>(false)
    private let stopFlag = AtomicStore<Bool>(false)
    private let phaseStorage = AtomicStore<UInt8>(Phase.live.rawValue)

    nonisolated(unsafe) var deferredReadable = false
    /// True once the CFFileDescriptor exists: from then it owns the kqueue fd
    /// (closeOnInvalidate) and the frame invalidates it, so `deinit` must not close.
    private nonisolated(unsafe) var didCreateFileDescriptor = false

    // MARK: Init / deinit

    /// - Parameter taskRef: the facade's task-executor reference (its
    ///   `asUnownedTaskExecutor()._executor`) on the iOS-18 `TaskExecutor` path, or
    ///   `nil` on the iOS-13 `SerialExecutor`-only path. When non-nil, `processLane`
    ///   runs jobs via `runSynchronously(isolatedTo:taskExecutor:)` so a task's
    ///   preferred task executor is respected (Task 5).
    init(facade: StackBoundRunLoopExecutor, serial: UnownedSerialExecutor,
         taskRef: Builtin.Executor?, cfRunLoop: CFRunLoop) {
        self.facade = facade
        self.serial = serial
        self.taskRefOrNil = taskRef
        self.cfRunLoop = cfRunLoop
        self.thread = pthread_self()
        self.kqueueFD = KQueueSelector.makeKQueue()
    }

    deinit {
        // Only the never-mounted path (no descriptor ever created) closes the fd;
        // otherwise the CFFileDescriptor closes it on invalidation.
        if !didCreateFileDescriptor {
            close(kqueueFD)
        }
    }

    // MARK: Phase helpers

    private var phase: Phase { Phase(rawValue: phaseStorage.load(ordering: .acquiring))! }

    var isStopRequested: Bool { stopFlag.load(ordering: .acquiring) }

    // MARK: Enqueue (producer side — the facade holds `producerGate` across this)

    func enqueueReady(_ job: UnownedJob) {
        let phase = self.phase
        if phase == .dead {
            preconditionFailure("StackBoundRunLoopExecutor.enqueue(_:) called after its run loop finished.")
        }
        if phase == .closing, pthread_equal(thread, pthread_self()) == 0 {
            preconditionFailure("StackBoundRunLoopExecutor.enqueue(_:) raced with its run loop shutting down.")
        }
        ready.enqueue(job, thread)
        if phase == .live {
            // Deliberately an unconditional RMW, never load-then-exchange: the RMW
            // chain on this variable is what guarantees the pump's clearing
            // `exchange(false)` synchronizes-with our lane push when we skip the wake.
            if pendingJobPop.exchange(true, ordering: .acquiringAndReleasing) == false {
                KQueueSelector.wakeup(fileDescriptor: kqueueFD)
            }
        }
    }

    func enqueueBatch(_ jobs: ContiguousArray<UnownedJob>) {
        precondition(phase == .live,
                     "StackBoundRunLoopExecutor.enqueueBatch(_:) called after its run loop finished.")
        for job in jobs {
            ready.enqueue(job, thread)
        }
    }

    /// Inserts a delayed job and, if it is a strictly-earlier deadline for its domain,
    /// arms that domain's kqueue timer right here, under the lock — no `EVFILT_USER`
    /// wakeup round trip (an already-due deadline arms `0` and fires immediately, so
    /// the kernel itself wakes the pump). The timestamp computation was MOVED here
    /// from `SlicedJobQueue.enqueue(_:after:...)`.
    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, visionOS 1, *)
    func enqueueTimer(_ job: UnownedJob, after delay: Duration, tolerance: Duration?, index: SlicedJobQueue.ClockIndex) {
        guard phase == .live else {
            preconditionFailure("StackBoundRunLoopExecutor.enqueue(_:after:...) called while shutting down.")
        }
        let timestamp = Self.timestamp(after: delay, tolerance: tolerance, index: index)
        timerCount.wrappingIncrement(ordering: .releasing)
        timers.withLock { state in
            state.sequence &+= 1
            state.heaps[index.rawValue].insert(
                TimestampJob(job: job, sequence: state.sequence, timestamp: timestamp)
            )
            armIfEarlierLocked(&state, index: index, candidate: timestamp)
        }
    }

    /// Resolves a delay + tolerance into a domain fire deadline in the same mach units
    /// `KQueueSelector.now(index:)` reports. Moved verbatim from the old
    /// `SlicedJobQueue.enqueue(_:after:tolerance:index:)`.
    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, visionOS 1, *)
    private static func timestamp(after delay: Duration, tolerance: Duration?, index: SlicedJobQueue.ClockIndex) -> Timestamp {
        let (delaySec, delayAtto) = delay.components
        let dispatch_now: UInt64
        switch index {
        case .continuous:
            let mask = 1 << 63 as dispatch_time_t
            dispatch_now = mask
        case .suspending:
            dispatch_now = 0
        case .walltime:
            dispatch_now = .init(DISPATCH_WALLTIME_NOW)
        }
        let dispatch_target = Dispatch.__dispatch_time(
            dispatch_now,
            delaySec * Int64(Dispatch.NSEC_PER_SEC) + Int64(delayAtto / 1_000_000_000)
        )
        let dispatch_deadline: dispatch_time_t
        if let tolerance {
            let (tol_sec, tol_atto) = tolerance.components
            dispatch_deadline = Dispatch.__dispatch_time(
                dispatch_target,
                Int64(Dispatch.NSEC_PER_SEC) * tol_sec + Int64(tol_atto / 1_000_000_000)
            )
        } else {
            dispatch_deadline = dispatch_target
        }
        switch index {
        case .continuous:
            return .init(target: dispatch_target & ~dispatch_now,
                         leeway: (dispatch_deadline & ~dispatch_now) - (dispatch_target & ~dispatch_now))
        case .suspending:
            return .init(target: dispatch_target, leeway: dispatch_deadline - dispatch_target)
        case .walltime:
            return .init(target: 0 &- dispatch_target,
                         leeway: (0 &- dispatch_deadline) - (0 &- dispatch_target))
        }
    }

    // MARK: Stop

    func requestStop() {
        stopFlag.store(true, ordering: .releasing)
        KQueueSelector.wakeup(fileDescriptor: kqueueFD)
    }
    func clearStopRequested() { stopFlag.store(false, ordering: .releasing) }

    // MARK: Drain pump (owning thread, from the CFFileDescriptor callout)

    func handleReadable(_ fd: CFFileDescriptor) {
        if withUnsafeCurrentTask(body: { $0 != nil }) {
            deferredReadable = true
            // Leave the callback disabled; the beforeWaiting observer re-enables it.
            return
        }
        deferredReadable = false
        pendingJobPop.store(true, ordering: .relaxed)
        // The explicit pool bounds job-autoreleased objects to this pass — a bare
        // thread's CFRunLoop is not guaranteed to push one of its own on every OS
        // Tetra supports.
        autoreleasepool {
            let fired = KQueueSelector.drainEvents(fileDescriptor: kqueueFD)   // consume wake + timer fires
            let hadTimers = timerCount.load(ordering: .acquiring) > 0
            // Fire the due pass whenever timers exist OR the kqueue reported a timer
            // firing (so a fire is never dropped even if the count just changed).
            if hadTimers || fired.continuous || fired.suspending || fired.wall {
                fireDueTimers(fired)                                   // pop due timers -> ready lanes
            }
            drainReadyJobs()                                           // drain the 5 ready lanes only
            if timerCount.load(ordering: .acquiring) > 0 {
                armNextDeadlines()                                     // arm EVFILT_TIMER from heap mins
            }
        }
        var refire = !readyLanesEmpty()
        if !refire {
            _ = pendingJobPop.exchange(false, ordering: .acquiringAndReleasing)
            refire = !readyLanesEmpty()
        }
        if refire {
            KQueueSelector.wakeup(fileDescriptor: kqueueFD)
        } else {
            // Busy period ended (I4a): release the QoS overrides here, once, instead of
            // per drain. Mirrors libdispatch's runloop-queue discipline.
            ready.endAllBoosts()
        }
        // Predicate unwinding (Task 3 concern #1): the facade binds `currentPredicate`
        // around a `runUntil` frame. After draining, evaluate it; if satisfied, stop
        // the run loop so the frame unwinds. `run()` binds it to nil, so this is a
        // no-op there.
        let predicateSatisfied: Bool = StackBoundRunLoopExecutor.currentPredicate?.block() ?? false
        if stopFlag.load(ordering: .acquiring) {
            CFRunLoopStop(CFRunLoopGetCurrent())
        } else if predicateSatisfied {
            stopFlag.store(true, ordering: .releasing)
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        CFFileDescriptorEnableCallBacks(fd, kCFFileDescriptorReadCallBack)
    }

    /// Pop due entries (per domain, `timestamp.target <= now`) into `dueBuffer` and
    /// feed them to the ready lanes OUTSIDE the lock, so no MPSC push (or override
    /// syscall) ever happens while producers wait on `timers`. Also clears the armed
    /// record for domains the kqueue reported as fired — a one-shot EVFILT_TIMER that
    /// fired is disarmed in the kernel, so the next arm pass must re-arm that domain.
    /// Clock reads happen lazily, only for non-empty heaps.
    private func fireDueTimers(_ fired: KQueueSelector.FiredDomains) {
        dueBuffer.removeAll(keepingCapacity: true)
        var firedCount = 0
        timers.withLockUnchecked { state in
            if fired.continuous { state.armed[0] = nil }
            if fired.suspending { state.armed[1] = nil }
            if fired.wall       { state.armed[2] = nil }
            for raw in 0..<3 {
                guard state.heaps[raw].min != nil else { continue }
                let now = KQueueSelector.now(index: SlicedJobQueue.ClockIndex(rawValue: raw)!)
                var popped = false
                while let box = state.heaps[raw].min, box.timestamp.target <= now {
                    state.heaps[raw].removeMin()
                    dueBuffer.append(box.job)
                    firedCount &+= 1
                    popped = true
                }
                // The armed min was just consumed — clear so the next arm pass re-arms
                // the new min (guards against a stale `armed` skipping the next deadline).
                if popped { state.armed[raw] = nil }
            }
        }
        if firedCount > 0 {
            timerCount.wrappingDecrement(by: firedCount, ordering: .releasing)
        }
        // `thread: nil`: the pump is about to drain these itself — no boost install.
        for job in dueBuffer {
            ready.enqueue(job, nil)
        }
        dueBuffer.removeAll(keepingCapacity: true)
    }

    /// Arm the earliest not-yet-due deadline per domain — but only when it is strictly
    /// earlier than what is already armed, so a steady state with an unchanged min
    /// issues no `kevent64` per pump pass.
    private func armNextDeadlines() {
        timers.withLockUnchecked { state in
            for raw in 0..<3 {
                let index = SlicedJobQueue.ClockIndex(rawValue: raw)!
                guard let stamp = state.heaps[raw].min?.timestamp else { continue }
                armIfEarlierLocked(&state, index: index, candidate: stamp)
            }
        }
    }

    /// Drains the 5 ready lanes on the owning thread, highest-priority-first.
    ///
    /// Two disciplines ported from the reference engine:
    ///   * I4a (QoS-once): the per-lane `pthread_override` boosts are NOT ended
    ///     here. They are held across drains and released ONCE by `endAllBoosts()`
    ///     on the idle path (no refire) / at teardown — avoiding per-drain start/end
    ///     syscall thrash and a mid-busy priority drop. The drain never alters the
    ///     owning thread's own QoS: effective priority is thread base + overrides,
    ///     matching libdispatch's runloop-queue discipline — low-QoS jobs are not
    ///     demoted below the thread's base.
    ///   * I4b (fairness cap): each lane's dequeue loop is capped at
    ///     `getDrainIterations(queueIndex:)`, so a high-priority flood cannot starve
    ///     the run loop's other CFRunLoop sources. A capped lane may leave jobs; the
    ///     pump re-checks `readyLanesEmpty()` and re-fires until empty.
    private func drainReadyJobs() {
        for index in 0..<5 {
            processLane(index)
        }
    }

    private func processLane(_ index: Int) {
        let iterations = getDrainIterations(queueIndex: index)
        var count = 0
        if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *), let t = taskRefOrNil {
            let taskExecutor = UnownedTaskExecutor(t)
            while count < iterations, let j = ready.jobs[index].dequeue() {
                j.runSynchronously(isolatedTo: serial, taskExecutor: taskExecutor)
                count &+= 1
            }
        } else {
            while count < iterations, let j = ready.jobs[index].dequeue() {
                j.runSynchronously(on: serial)
                count &+= 1
            }
        }
    }

    private func readyLanesEmpty() -> Bool {
        for i in 0..<5 where !ready.jobs[i].isEmpty { return false }
        return true
    }

    // MARK: Shutdown

    func beginClosing() {
        let old = phaseStorage.exchange(Phase.closing.rawValue, ordering: .acquiringAndReleasing)
        precondition(old == Phase.live.rawValue, "KQScheduler.beginClosing() called in an invalid phase.")
    }

    /// Drains the ready lanes to empty once the facade's producer gate quiesces, drops
    /// any not-yet-due timers, and transitions to `.dead`.
    func finishAndDie() {
        while true {
            drainReadyJobs()
            if facade.producerGate.load(ordering: .acquiring) == 0 {
                drainReadyJobs()
                if readyLanesEmpty() {
                    // Final teardown release of any QoS overrides (I4a backstop before
                    // the SlicedJobQueue.deinit backstop).
                    ready.endAllBoosts()
                    dropPendingTimers()
                    phaseStorage.store(Phase.dead.rawValue, ordering: .releasing)
                    break
                }
            } else {
                _ = sched_yield()
            }
        }
    }


    /// Not-yet-due timers are dropped at unwind (lifecycle contract). The kqueue
    /// timers themselves die when the descriptor is invalidated in the frame's defer.
    private func dropPendingTimers() {
        timers.withLockUnchecked { state in
            for raw in 0..<3 {
                state.heaps[raw] = .init()
                state.armed[raw] = nil
            }
        }
        timerCount.store(0, ordering: .releasing)
    }

    // MARK: Run-loop source

    /// Creates the CFFileDescriptor wrapping the kqueue. Its context retains this
    /// scheduler; the facade's frame owns the descriptor and invalidates it on exit
    /// (closeOnInvalidate closes the kqueue then). Called exactly once, from the
    /// facade's outermost run frame.
    func makeFileDescriptor() -> CFFileDescriptor {
        precondition(!didCreateFileDescriptor, "makeFileDescriptor() called more than once")
        let names = ["CFRetain", "CFRelease", "CFCopyDescription"]
        var buffer = Array<UnsafeMutableRawPointer?>(repeating: nil, count: names.count)
        CFBundleGetFunctionPointersForNames(
            CFBundleGetBundleWithIdentifier("com.apple.CoreFoundation" as CFString),
            names as CFArray, &buffer
        )
        let _CFRetain = unsafeBitCast(buffer[0], to: (@convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?).self)
        let _CFRelease = unsafeBitCast(buffer[1], to: (@convention(c) (UnsafeMutableRawPointer?) -> Void).self)
        let _CFCopyDescription = unsafeBitCast(buffer[2], to: (@convention(c) (UnsafeMutableRawPointer?) -> Unmanaged<CFString>?).self)

        var context = CFFileDescriptorContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: _CFRetain,
            release: _CFRelease,
            copyDescription: _CFCopyDescription
        )
        let callback: CFFileDescriptorCallBack = { fd, _, info in
            guard let info, let fd else { return }
            Unmanaged<KQScheduler>.fromOpaque(info).takeUnretainedValue().handleReadable(fd)
        }
        guard let created = CFFileDescriptorCreate(nil, kqueueFD, true, callback, &context) else {
            preconditionFailure("Failed to create CFFileDescriptor for kqueue")
        }
        didCreateFileDescriptor = true
        return created
    }

    /// Owning-thread teardown, run in the facade frame's defer. The kqueue's one-shot
    /// timers are torn down with the descriptor (closeOnInvalidate); nothing to disarm
    /// here beyond clearing the deferred-readable latch.
    func teardown() {
        deferredReadable = false
    }
}

#endif
