//
//  Concurrency+Cancellation.swift
//  
//
//  Created by pbk on 2022/09/16.
//

import Foundation
import Combine
import _Concurrency

public extension Task where Success == Never, Failure == Never {
    
    /// Launch  operation and suspend the current Task, current Task is resumed immediately when operation is cancelled.
    /// - Parameter operation: task to launch
    /// - Throws: CancellationError if task is cancelled, otherwise propagates underlying Error
    /// - Returns: operation result
    ///
    /// Event though launched task does not support cancellation. this function will resume the suspension point while launched task is still running
    @inlinable
    static func withThrowingCancellation<T:Sendable>(operation: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: .max)
                }
                throw _Concurrency.CancellationError()
            }
            while let value = try await group.next() {
                return value
            }
            group.cancelAll()
            throw _Concurrency.CancellationError()
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
    static func withTimeOut<T:Sendable,S:Scheduler>(scheduler:S, timeout: S.SchedulerTimeType.Stride, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            let deadLine = scheduler.now.advanced(by: timeout)
            group.addTask(operation: operation)
            group.addTask {
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: .max)
                }
                throw _Concurrency.CancellationError()
            }
            group.addTask {
                try checkCancellation()
                await withUnsafeContinuation{
                    scheduler.schedule(after: deadLine, $0.resume)
                }
                throw _Concurrency.CancellationError()
            }
            while let value = try await group.next() {
                return value
            }
            group.cancelAll()
            throw _Concurrency.CancellationError()
        }
    }

    /// Launch  operation and suspend the current Task, current Task is resumed immediately when operation is cancelled.
    /// - Parameters:
    ///   - timeout: Timeout interval from now
    ///   - operation: task to launch
    /// - Throws: CancellationError if task is cancelled or reached the timeout, otherwise propagates underlying Error
    /// - Returns: operation result
    @inlinable @available(iOS 16.0, tvOS 16.0, macOS 13.0, watchOS 9.0, *)
    static func withTimeOut<T:Sendable, C>(clock:C, timeout: C.Duration, operation: @escaping @Sendable () async throws -> T) async throws -> T where C:Clock {
        try await withThrowingTaskGroup(of: T.self) { group in
            let deadLine = clock.now.advanced(by: timeout)
            group.addTask(operation: operation)
            group.addTask {
                try await sleep(until: deadLine, clock: clock)
                throw _Concurrency.CancellationError()
            }
            while let value = try await group.next() {
                return value
            }
            group.cancelAll()
            throw _Concurrency.CancellationError()
        }
    }

    @inlinable
    @inline(__always)
    static func withIsolation<Target:Actor,T:Sendable>(_ target:Target, operation: (isolated Target) throws -> T) async rethrows -> T {
        return try await operation(target)
    }
}
