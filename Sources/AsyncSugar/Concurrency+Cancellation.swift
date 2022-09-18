//
//  Concurrency+Cancellation.swift
//  
//
//  Created by pbk on 2022/09/16.
//

import Foundation
import Combine


/// Launch  operation and suspend the current Task, current Task is resumed immediately when operation is cancelled.
/// - Parameter operation: task to launch
/// - Throws: CancellationError if task is cancelled, otherwise propagates underlying Error
/// - Returns: operation result
///
/// Event though launched task does not support cancellation. this function will resume the suspension point while launched task is still running
@inlinable
func withThrowingCancellation<T:Sendable>(operation: @Sendable @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask(operation: operation)
        group.addTask {
            try await Task.sleep(nanoseconds: .max)
            throw CancellationError()
        }
        while let value = try await group.next() {
            return value
        }
        group.cancelAll()
        throw CancellationError()
    }
}

/**
    When task is cancelled this function return with nil
 */
@inlinable
func withReturningCancellation<T>(operation: @Sendable @escaping () async -> T) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask(operation: operation)
        group.addTask{
            try? await Task.sleep(nanoseconds: .max)
            return nil
        }
        while let value = await group.next() {
            return value
        }
        group.cancelAll()
        return nil
    }
}



/// Launch  operation and suspend the current Task, current Task is resumed immediately when operation is cancelled.
/// - Parameters:
///   - timeout: Timeout interval from now
///   - operation: task to launch
/// - Throws: CancellationError if task is cancelled or reached the timeout, otherwise propagates underlying Error
/// - Returns: operation result
///
/// Event though launched task does not support cancellation. this function will resume the suspension point while launched task is still running
@inlinable
func withTimeOut<T:Sendable,S:Scheduler>(scheduler:S, timeout: S.SchedulerTimeType.Stride, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        let deadLine = scheduler.now.advanced(by: timeout)
        group.addTask(operation: operation)
        group.addTask {
            try await Task.sleep(nanoseconds: .max)
            throw CancellationError()
        }
        group.addTask {
            try Task.checkCancellation()
            await withUnsafeContinuation{
                scheduler.schedule(after: deadLine, $0.resume)
            }
            throw CancellationError()
        }
        while let value = try await group.next() {
            return value
        }
        group.cancelAll()
        throw CancellationError()
    }
}

/// Launch  operation and suspend the current Task, current Task is resumed immediately when operation is cancelled.
/// - Parameters:
///   - timeout: Timeout interval from now
///   - operation: task to launch
/// - Throws: CancellationError if task is cancelled or reached the timeout, otherwise propagates underlying Error
/// - Returns: operation result
@inlinable @available(iOS 16.0, tvOS 16.0, *)
func withTimeOut<T:Sendable, C>(clock:C, timeout: C.Duration, operation: @escaping @Sendable () async throws -> T) async throws -> T where C:Clock {
    try await withThrowingTaskGroup(of: T.self) { group in
        let deadLine = clock.now.advanced(by: timeout)
        group.addTask(operation: operation)
        group.addTask {
            try await Task.sleep(until: deadLine, clock: clock)
            throw CancellationError()
        }
        while let value = try await group.next() {
            return value
        }
        group.cancelAll()
        throw CancellationError()
    }
}
