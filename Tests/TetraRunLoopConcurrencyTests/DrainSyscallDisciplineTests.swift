//
//  DrainSyscallDisciplineTests.swift
//  TetraRunLoopConcurrencyTests
//
//  Characterization tests pinning the behaviors at stake in the drain-path
//  syscall optimizations:
//
//    * QoS discipline (platform convention): `runBatch` never alters the owning
//      thread's own QoS — no per-lane demotion while a job runs, and the entry
//      class AND relative priority are intact after any drain. Effective priority
//      is thread base + producer-installed overrides, as in libdispatch's
//      runloop queues and the reference engine.
//    * A strictly-earlier timer enqueued from INSIDE a job (owning thread, mid-pump)
//      must be armed by the end of that pump pass — it may not wait for the
//      previously-armed later deadline. This is what allows `enqueueTimer` to skip
//      the producer self-wake on the owning-thread-in-pump path.
//

#if canImport(Darwin)
import Testing
import Foundation
import CoreFoundation
import Dispatch
import HeapModule
@testable import TetraRunLoopConcurrency
import CriticalSection

private final class WeakRef<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
}
private final class Canary {}

@Suite
struct DrainSyscallDisciplineTests {

    /// After a mixed-lane drain the owning thread still has its entry QoS class AND
    /// relative priority — the drain leaves the thread's own QoS untouched.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *)
    func threadQoSClassAndRelativePriorityIntactAfterMixedLaneDrain() {
        let restored = ManagedUnfairLock<(UInt32, Int32)?>(initialState: nil)
        onThread {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INITIATED, -4)
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                // .medium -> DEFAULT lane, .low -> UTILITY lane: both differ from the
                // entry class, exercising the lanes that used to demote the thread.
                executor.enqueue(makeJob(priority: .medium) { })
                executor.enqueue(makeJob(priority: .low) { executor.stop() })
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
            var qos = QOS_CLASS_UNSPECIFIED
            var relative = Int32(0)
            pthread_get_qos_class_np(pthread_self(), &qos, &relative)
            restored.withLockUnchecked { $0 = (qos.rawValue, relative) }
        }
        let result = restored.withLockUnchecked { $0 }
        #expect(result?.0 == QOS_CLASS_USER_INITIATED.rawValue)
        #expect(result?.1 == -4)
    }

    /// Platform-convention QoS discipline (libdispatch runloop queues, the reference
    /// engine): the drain never demotes the owning thread below its base QoS — a
    /// background-lane job observes the thread's own requested QoS class, not
    /// QOS_CLASS_BACKGROUND. Priority-inversion avoidance is the overrides' job.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *)
    func jobRunsAtThreadBaseQoSNotLaneQoS() {
        let observed = ManagedUnfairLock<UInt32?>(initialState: nil)
        onThread {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INITIATED, 0)
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                executor.enqueue(makeJob(priority: .background) {
                    var qos = QOS_CLASS_UNSPECIFIED
                    var relative = Int32(0)
                    pthread_get_qos_class_np(pthread_self(), &qos, &relative)
                    observed.withLockUnchecked { $0 = qos.rawValue }
                    executor.stop()
                })
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(observed.withLockUnchecked { $0 } == QOS_CLASS_USER_INITIATED.rawValue)
    }

    /// A 30ms timer enqueued from inside a job while a 200ms timer is already armed
    /// fires near its own deadline (not at the stale 200ms arming), proving the pump
    /// re-arms the earlier deadline by the end of the pass without a producer wake.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *) @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    func earlierTimerEnqueuedMidPumpRearmsWithoutProducerWake() {
        let order = ManagedUnfairLock<[Int]>(initialState: [])
        let earlyElapsed = ManagedUnfairLock<Duration?>(initialState: nil)
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            let start = ContinuousClock.now
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                executor.enqueue(makeJob(priority: .medium) {
                    order.withLockUnchecked { $0.append(200) }
                    executor.stop()
                }, after: .milliseconds(200), clock: .continuous)
                executor.enqueue(makeJob(priority: .medium) {
                    // Mid-pump, owning thread: this becomes the strictly-earlier min.
                    executor.enqueue(makeJob(priority: .medium) {
                        order.withLockUnchecked { $0.append(30) }
                        earlyElapsed.withLockUnchecked { $0 = start.duration(to: ContinuousClock.now) }
                    }, after: .milliseconds(30), clock: .continuous)
                })
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(order.withLockUnchecked { $0 } == [30, 200])
        if let actual = earlyElapsed.withLockUnchecked({ $0 }) {
            #expect(actual >= .milliseconds(30))
            // Firing anywhere near the stale 200ms arming means the re-arm was lost.
            #expect(actual < .milliseconds(150))
        } else {
            Issue.record("early timer never fired")
        }
    }

    /// Objects autoreleased by a job must be released by the end of that pump pass —
    /// the drain runs inside its own autorelease pool (a bare-thread CFRunLoop pushes
    /// none of its own, so without one they pile up until the thread exits).
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *) @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    func autoreleasedObjectsDrainBetweenPumpPasses() {
        let stillAlive = ManagedUnfairLock<Bool?>(initialState: nil)
        let ref = WeakRef<Canary>()
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                executor.enqueue(makeJob(priority: .medium) {
                    let canary = Canary()
                    ref.value = canary
                    Unmanaged.passRetained(canary).autorelease()
                    // A later, separate pump pass observes whether the pool drained.
                    executor.enqueue(makeJob(priority: .medium) {
                        stillAlive.withLockUnchecked { $0 = ref.value != nil }
                        executor.stop()
                    }, after: .milliseconds(50), clock: .continuous)
                })
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(stillAlive.withLockUnchecked { $0 } == false)
    }

    /// Delayed jobs with IDENTICAL deadlines pop in enqueue (FIFO) order — the heap
    /// ordering must carry a sequence tie-break, not leave equal keys unordered.
    @Test @available(macOS 9999, *)
    func equalDeadlineTimerJobsPopInFifoOrder() {
        var heap = Heap<TimestampJob>()
        let stamp = Timestamp(target: 1_000, leeway: 0)
        var insertion: [UnsafeRawPointer] = []
        for i in 0..<8 {
            // Identity-only jobs: never run, deliberately leaked (test process only).
            let job = UnownedJob(makeJob(priority: .medium) { })
            insertion.append(unsafeBitCast(job, to: UnsafeRawPointer.self))
            heap.insert(TimestampJob(job: job, sequence: UInt64(i), timestamp: stamp))
        }
        var popped: [UnsafeRawPointer] = []
        while let min = heap.popMin() {
            popped.append(unsafeBitCast(min.job, to: UnsafeRawPointer.self))
        }
        #expect(popped == insertion)
    }

    /// Priority→lane mapping uses the reference engine's `>=` band boundaries: a raw
    /// priority maps to the lane of the highest named priority it meets or exceeds
    /// (33/25/21/17, else background). Named priorities land where they always did;
    /// this pins the in-between raw values.
    @Test func priorityLaneMappingUsesInclusiveBandBoundaries() {
        let expected: [(UInt8, Int)] = [
            (33, 0),           // userInteractive
            (26, 1), (25, 1),  // (high, userInteractive) band + high itself
            (24, 2), (21, 2),  // (medium, high) band + medium itself
            (20, 3), (17, 3),  // (low, medium) band + low itself
            (16, 4), (10, 4), (9, 4), (1, 4),  // below low -> background lane
        ]
        for (raw, lane) in expected {
            #expect(TaskPriority(rawValue: raw).jobQueueIndex == lane,
                    "rawValue \(raw) should map to lane \(lane)")
        }
    }
}

#endif // canImport(Darwin)
