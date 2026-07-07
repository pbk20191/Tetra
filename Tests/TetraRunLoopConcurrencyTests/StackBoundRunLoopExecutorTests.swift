//
//  StackBoundRunLoopExecutorTests.swift
//  TetraRunLoopConcurrencyTests
//
//  Behavioral-verification suite for StackBoundRunLoopExecutor.
//  Ported from swift-platform-executors'
//  DarwinRunLoopExecutorTests/StackBoundRunLoopExecutor2Tests.swift (10 tests).
//
//  Adaptations:
//    * Type: StackBoundRunLoopExecutor (from @testable import TetraRunLoopConcurrency)
//    * makeJob / onThread: from TestSupport.swift (Task 1). Not redefined here.
//    * Synchronization.Mutex → ManagedUnfairLock (iOS 13+ compatible).
//    * Timer clock arg: SlicedJobQueue.ClockIndex (.continuous / .suspending / .walltime).
//    * Tests are NOT async: onThread(_:) is synchronous-blocking.
//    * Timer tests gated @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
//      in addition to the @available(macOS 9999, *) makeJob gate.
//

#if canImport(Darwin)
import Testing
import Foundation
import CoreFoundation
import Dispatch
@testable import TetraRunLoopConcurrency
// CriticalSection is an internal dependency; ManagedUnfairLock is accessible
// because the test target imports TetraRunLoopConcurrency @testable.
import CriticalSection

@Suite
struct StackBoundRunLoopExecutorTests {

    // MARK: Non-timer tests

    /// Jobs enqueued while the executor is dormant buffer and flush once run() mounts.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *)
    func dormantEnqueueBuffersUntilRun() {
        let order = ManagedUnfairLock<[Int]>(initialState: [])
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            executor.enqueue(makeJob(priority: .medium) { order.withLockUnchecked { $0.append(1) } })
            executor.enqueue(makeJob(priority: .medium) { order.withLockUnchecked { $0.append(2) } })
            executor.enqueue(makeJob(priority: .medium) {
                order.withLockUnchecked { $0.append(3) }
                executor.stop()
            })
            try! executor.run()
        }
        #expect(order.withLockUnchecked { $0 } == [1, 2, 3])
    }

    /// Stress: many threads enqueue concurrently; every job runs exactly once.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *)
    func concurrentEnqueueFromManyThreadsRunsEveryJob() {
        let producers = 6
        let perProducer = 200
        let target = producers * perProducer
        let ran = ManagedUnfairLock<Int>(initialState: 0)
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                let priorities: [TaskPriority] = [.high, .medium, .low, .background, .high, .medium]
                DispatchQueue.global(qos: .userInteractive).async {
                    DispatchQueue.concurrentPerform(iterations: producers) { p in
                        let priority = priorities[p % priorities.count]
                        for _ in 0..<perProducer {
                            executor.enqueue(makeJob(priority: priority) {
                                var count = 0
                                ran.withLockUnchecked { count = ($0 + 1); $0 = count }
                                if count == target { executor.stop() }
                            })
                        }
                    }
                }
            }
            try! executor.run()
        }
        #expect(ran.withLockUnchecked { $0 } == target)
    }

    /// A job re-enqueuing onto its own executor makes progress to completion.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *)
    func selfEnqueueChainRunsToCompletion() {
        let hops = 10_000
        let count = ManagedUnfairLock<Int>(initialState: 0)
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            func hop() {
                var n = 0
                count.withLockUnchecked { n = $0 + 1; $0 = n }
                if n < hops {
                    executor.enqueue(makeJob(priority: .medium) { hop() })
                } else {
                    executor.stop()
                }
            }
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                executor.enqueue(makeJob(priority: .medium) { hop() })
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(count.withLockUnchecked { $0 } == hops)
    }

    /// Jobs drain highest-priority-first (FIFO within a priority); `stop()` unwinds.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *)
    func serialPriorityOrderingAndStop() {
        let order = ManagedUnfairLock<[Int]>(initialState: [])
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                func job(_ n: Int, _ priority: TaskPriority) -> ExecutorJob {
                    makeJob(priority: priority) { order.withLockUnchecked { $0.append(n) } }
                }
                executor.enqueue(job(3, .medium))
                executor.enqueue(job(5, .low))
                executor.enqueue(job(1, .high))
                executor.enqueue(job(6, .low))
                executor.enqueue(job(4, .medium))
                executor.enqueue(job(2, .high))
                executor.enqueue(makeJob(priority: .low) {
                    order.withLockUnchecked { $0.append(7) }
                    executor.stop()
                })
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(order.withLockUnchecked { $0 } == [1, 2, 3, 4, 5, 6, 7])
    }

    /// `runUntil` unwinds as soon as its predicate turns true after a drain.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *)
    func runUntilPredicateUnwinds() {
        let counter = ManagedUnfairLock<Int>(initialState: 0)
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                for _ in 0..<5 {
                    executor.enqueue(makeJob(priority: .medium) {
                        counter.withLockUnchecked { $0 += 1 }
                    })
                }
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.runUntil { counter.withLockUnchecked { $0 } >= 5 }
        }
        #expect(counter.withLockUnchecked { $0 } == 5)
    }

    /// After quiescence the executor re-arms for a fresh timer correctly.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *) @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    func rearmAfterQuiescence() {
        let fires = ManagedUnfairLock<Int>(initialState: 0)
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                executor.enqueue(makeJob(priority: .medium) {
                    fires.withLockUnchecked { $0 += 1 }
                    executor.enqueue(makeJob(priority: .medium) {
                        fires.withLockUnchecked { $0 += 1 }
                        executor.stop()
                    }, after: .milliseconds(30), clock: .continuous)
                }, after: .milliseconds(30), clock: .continuous)
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(fires.withLockUnchecked { $0 } == 2)
    }

    // MARK: Timer tests

    /// A continuous-clock delayed job fires no earlier than its deadline.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *) @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    func scheduledJobFiresAfterDelay() {
        let fired = ManagedUnfairLock<Bool>(initialState: false)
        let elapsed = ManagedUnfairLock<Duration?>(initialState: nil)
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            let start = ContinuousClock.now
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                let job = makeJob(priority: .medium) {
                    fired.withLockUnchecked { $0 = true }
                    elapsed.withLockUnchecked { $0 = start.duration(to: ContinuousClock.now) }
                    executor.stop()
                }
                executor.enqueue(job, after: .milliseconds(50), clock: .continuous)
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(fired.withLockUnchecked { $0 })
        if let actual = elapsed.withLockUnchecked({ $0 }) {
            #expect(actual >= .milliseconds(50))
            #expect(actual < .milliseconds(650))
        }
    }

    /// Timers inserted out of deadline order fire in deadline order (re-arm path).
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *) @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    func multipleTimersFireInDeadlineOrder() {
        let order = ManagedUnfairLock<[Int]>(initialState: [])
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                func fire(_ n: Int, last: Bool = false) -> ExecutorJob {
                    makeJob(priority: .medium) {
                        order.withLockUnchecked { $0.append(n) }
                        if last { executor.stop() }
                    }
                }
                executor.enqueue(fire(90, last: true), after: .milliseconds(90), clock: .continuous)
                executor.enqueue(fire(30), after: .milliseconds(30), clock: .continuous)
                executor.enqueue(fire(60), after: .milliseconds(60), clock: .continuous)
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(order.withLockUnchecked { $0 } == [30, 60, 90])
    }

    /// The suspending-clock domain works (uptime deadline).
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *) @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    func suspendingClockTimerFires() {
        let fired = ManagedUnfairLock<Bool>(initialState: false)
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                executor.enqueue(makeJob(priority: .medium) {
                    fired.withLockUnchecked { $0 = true }
                    executor.stop()
                }, after: .milliseconds(30), clock: .suspending)
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(fired.withLockUnchecked { $0 })
    }

    /// The wall-clock domain works.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *) @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    func wallClockTimerFires() {
        let fired = ManagedUnfairLock<Bool>(initialState: false)
        onThread {
            let executor = StackBoundRunLoopExecutor.current()
            CFRunLoopPerformBlock(CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                executor.enqueue(makeJob(priority: .medium) {
                    fired.withLockUnchecked { $0 = true }
                    executor.stop()
                }, after: .milliseconds(30), clock: .walltime)
            }
            CFRunLoopWakeUp(CFRunLoopGetCurrent())
            try! executor.run()
        }
        #expect(fired.withLockUnchecked { $0 })
    }
}

#endif // canImport(Darwin)
