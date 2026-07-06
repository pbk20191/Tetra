import Darwin
import Dispatch
import Foundation
@testable import TetraRunLoopConcurrency
@_spi(ExperimentalScheduling) @_spi(ConcurrencyExecutors) @_spi(ExperimentalCustomExecutors) import _Concurrency

@available(macOS 9999, *)
func makeJob(priority: TaskPriority = .medium, _ body: @escaping () -> Void) -> ExecutorJob {
    _swift_createJobForTestingOnly(priority: priority, body)
}

func onThread(_ body: @escaping @Sendable () -> Void) {
    let done = DispatchSemaphore(value: 0)
    let t = Thread { body(); done.signal() }; t.stackSize = 1 << 22; t.start(); done.wait()
}
