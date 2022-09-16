//
//  Concurrency+Cancellation.swift
//  
//
//  Created by pbk on 2022/09/16.
//

import Foundation

/// Launch  operation and suspend the current Task, current Task is resumed immediately when operation is cancelled.
/// - Parameter operation: task to launch
/// - Throws: CancellationError if task is cancelled, otherwise propagates underlying Error
/// - Returns: operation result
///
/// Event though launched task does not support cancellation. this function will resume the suspension point while launched task is still running
@inlinable
func withThrowingCancellation<T>(operation: @Sendable @escaping () async throws -> T) async throws -> T {
    let stream = AsyncThrowingStream<T,Error> { continuation in
        let task = Task<Void,Never> {
            let childTask = Task(operation: operation)
            await withTaskCancellationHandler {
                childTask.cancel()
                continuation.finish(throwing: CancellationError())
            } operation: {
                switch await childTask.result {
                case .failure(let error):
                    continuation.finish(throwing: error)
                case .success(let value):
                    continuation.yield(value)
                    continuation.finish()
                }
            }
        }
        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }
    }
    if let value = try await stream.first(where: { _ in true }) {
        return value
    } else {
        try Task.checkCancellation()
        assertionFailure("reached undefined endpoint")
        throw CancellationError()
    }
}

///**
//    When task is cancelled this function return with nil
//
// */
//@inlinable
//func withReturningCancellation<T>(operation: @Sendable @escaping () async -> T) async -> T? {
//    let stream = AsyncStream<T> { continuation in
//        let task = Task<Void,Never> {
//            let childTask = Task(operation: operation)
//            await withTaskCancellationHandler {
//                childTask.cancel()
//                continuation.finish()
//            } operation: {
//                await continuation.yield(childTask.value)
//                continuation.finish()
//            }
//        }
//        continuation.onTermination = { @Sendable _ in
//            task.cancel()
//        }
//    }
//    return await stream.first{ _ in true }
//}



/// Launch  operation and suspend the current Task, current Task is resumed immediately when operation is cancelled.
/// - Parameters:
///   - timeout: Timeout interval from now
///   - operation: task to launch
/// - Throws: CancellationError if task is cancelled or reached the timeout, otherwise propagates underlying Error
/// - Returns: operation result
///
/// Event though launched task does not support cancellation. this function will resume the suspension point while launched task is still running
@inlinable
func withTimeOut<T>(timeout: DispatchTimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    let childTask:Task<T,Error> = Task {
        try await withThrowingCancellation(operation: operation)
    }
    let timeoutTask = Task {
        do {
            switch timeout {
            case .seconds(let int):
                try await Task.sleep(nanoseconds: UInt64(int) * 1000 * 1000 * 1000)
            case .milliseconds(let int):
                try await Task.sleep(nanoseconds: UInt64(int) * 1000 * 1000)
            case .microseconds(let int):
                try await Task.sleep(nanoseconds: UInt64(int) * 1000)
            case .nanoseconds(let int):
                try await Task.sleep(nanoseconds: UInt64(int))
            case .never:
                return
            @unknown default:
                assertionFailure()
            }
        } catch {
            childTask.cancel()
        }
    }
    
    return try await withTaskCancellationHandler {
        timeoutTask.cancel()
        childTask.cancel()
    } operation: {
        try await childTask.value
    }

}

/// Launch  operation and suspend the current Task, current Task is resumed immediately when operation is cancelled.
/// - Parameters:
///   - timeout: Timeout interval from now
///   - operation: task to launch
/// - Throws: CancellationError if task is cancelled or reached the timeout, otherwise propagates underlying Error
/// - Returns: operation result
@inlinable @available(iOS 16.0, *)
func withTimeOut<T, C>(clock:C, timeout: C.Duration, operation: @escaping @Sendable () async throws -> T) async throws -> T where C:Clock {
    let childTask:Task<T,Error> = Task {
        try await withThrowingCancellation(operation: operation)
    }
    let deadline = clock.now.advanced(by: timeout)
    let timeoutTask = Task {
        do {
            try await Task.sleep(until: deadline, clock: clock)
        } catch {
            childTask.cancel()
        }
    }
    return try await withTaskCancellationHandler {
        timeoutTask.cancel()
        childTask.cancel()
    } operation: {
        try await childTask.value
    }

}
