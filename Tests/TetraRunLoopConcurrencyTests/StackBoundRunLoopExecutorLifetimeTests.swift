//
//  StackBoundRunLoopExecutorLifetimeTests.swift
//  TetraRunLoopConcurrencyTests
//
//  Task C lifetime verification: after `run()`/`runUntil()` returns, the
//  stack-bound `KQScheduler` engine (and, transitively, its `SlicedJobQueue`,
//  CFFileDescriptor, and run-loop observer) must deallocate promptly — the run
//  loop carries no extra retain on the engine.
//
//  Observed by capturing the freshly mounted engine through the DEBUG-only
//  `_debugOnMountEngine` hook into a `weak` box, then asserting the box is nil
//  after `run()` returns.
//
//  The hook is a PROCESS-GLOBAL, so while it is installed, engines mounted by
//  *other* (parallel) test suites' `current()` calls fire it too. We therefore
//  guard the capture on the test's own worker thread (`expectedThread`): only the
//  engine mounted on this test's thread is recorded, so a concurrently-running
//  suite can never contaminate `box.engine`. `.serialized` keeps this suite's own
//  two tests from overlapping on the shared hook.
//

#if canImport(Darwin) && DEBUG
import Testing
import Foundation
import CoreFoundation
import Dispatch
import Darwin
@testable import TetraRunLoopConcurrency
import CriticalSection

@Suite(.serialized)
struct StackBoundRunLoopExecutorLifetimeTests {

    /// Holds a weak reference to the engine mounted on `expectedThread`, so the test
    /// thread can inspect it after the worker thread's `run()` returns. Test-only;
    /// `expectedThread` is written once (on the worker, before mount) and read by the
    /// hook on the mounting thread — a benign test-only cross-thread read of a
    /// pointer-sized value.
    final class WeakEngineBox: @unchecked Sendable {
        weak var engine: KQScheduler?
        var expectedThread: pthread_t?
    }

    /// After a mounted engine's `run()` returns, its `KQScheduler` deallocates:
    /// the run loop held no extra retain, so the weak reference reads nil.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *)
    func engineDeallocatesAfterRunReturns() {
        let box = WeakEngineBox()
        StackBoundRunLoopExecutor._debugOnMountEngine = { eng in
            if let t = box.expectedThread, pthread_equal(eng.thread, t) != 0 { box.engine = eng }
        }
        defer { StackBoundRunLoopExecutor._debugOnMountEngine = nil }

        onThread {
            box.expectedThread = pthread_self()
            let executor = StackBoundRunLoopExecutor.current()
            executor.enqueue(makeJob(priority: .medium) { executor.stop() })
            try! executor.run()
        }

        // `run()` returned on the worker thread: the frame's strong `engine` local
        // dropped and the CFFileDescriptor was invalidated, dropping its context
        // retain. Nothing else holds the engine, so it must be gone.
        #expect(box.engine == nil)
    }

    /// The facade can be re-mounted and re-run on a fresh thread cleanly, and that
    /// second engine also deallocates — proving no live engine leaked from the first.
    @Test(.timeLimit(.minutes(1))) @available(macOS 9999, *)
    func reMountAndReRunDeallocatesEachEngine() {
        for _ in 0..<2 {
            let box = WeakEngineBox()
            let ran = ManagedUnfairLock<Bool>(initialState: false)
            StackBoundRunLoopExecutor._debugOnMountEngine = { eng in
                if let t = box.expectedThread, pthread_equal(eng.thread, t) != 0 { box.engine = eng }
            }
            onThread {
                box.expectedThread = pthread_self()
                let executor = StackBoundRunLoopExecutor.current()
                executor.enqueue(makeJob(priority: .medium) {
                    ran.withLockUnchecked { $0 = true }
                    executor.stop()
                })
                try! executor.run()
            }
            StackBoundRunLoopExecutor._debugOnMountEngine = nil
            #expect(ran.withLockUnchecked { $0 })
            #expect(box.engine == nil)
        }
    }
}

#endif // canImport(Darwin) && DEBUG
