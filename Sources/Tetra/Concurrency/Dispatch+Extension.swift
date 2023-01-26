//
//  Dispatch+Extension.swift
//  
//
//  Created by pbk on 2023/01/26.
//

import Foundation
import Dispatch

public extension Task where Success == Never, Failure == Never {
    
    /**
     Suspends the current task until the given deadline within a tolerance.
     - Parameters:
        - Throws: `CancellationError` if task is cancelled
     */
    @inlinable
    static func sleep(until deadline:DispatchTime, tolerance:DispatchTimeInterval? = nil) async throws {
        try await dispatchTimerSleep(wait: deadline, leeway: tolerance)
    }
    
    /**
     Suspends the current task until the given deadline within a tolerance.
     - Parameters:
        - Throws: `CancellationError` if task is cancelled
     */
    @inlinable
    static func sleep(until wallDeadline:DispatchWallTime, tolerance:DispatchTimeInterval? = nil) async throws {
        try await Task.sleep(nanoseconds: 1000)
        try await dispatchTimerSleep(wait: wallDeadline, leeway: tolerance)
    }
    
}


@usableFromInline
internal func dispatchTimerSleep(wait deadline:DispatchTime, leeway:DispatchTimeInterval?) async throws {
    
    let lock = createCheckedStateLock(checkedState: DispatchSleepState.waiting)
    let source = DispatchSource.makeTimerSource(flags: [.strict])
    source.schedule(deadline: deadline, repeating: .never, leeway: leeway ?? .nanoseconds(0))
    source.setEventHandler{
        lock.withLock{
            $0.take()
        }?.resume()
    }
    source.setCancelHandler{
        lock.withLock{
            $0.take()
        }?.resume(throwing: CancellationError())
    }
    return try await withTaskCancellationHandler {
        return try await withUnsafeThrowingContinuation{ continuation in
            let snapShot = lock.withLock{
                let oldValue = $0
                switch oldValue {
                case .finished:
                    break
                case .waiting, .continuation:
                    $0 = .continuation(continuation)
                    
                }
                return oldValue
            }
            switch snapShot {
            case .continuation(let unsafeContinuation):
                assertionFailure("reached unexpected state")
                unsafeContinuation.resume(throwing: CancellationError())
            case .finished:
                continuation.resume(throwing: CancellationError())
            case .waiting:
                break
            }
            source.activate()
        }
    } onCancel: {
        lock.withLock{
            $0.take()
        }?.resume(throwing: CancellationError())
        source.cancel()
    }

}


@usableFromInline
internal func dispatchTimerSleep(wait wallDeadline:DispatchWallTime, leeway: DispatchTimeInterval?) async throws {
    let lock = createCheckedStateLock(checkedState: DispatchSleepState.waiting)
    let source = DispatchSource.makeTimerSource(flags: [.strict])
    source.schedule(wallDeadline: wallDeadline, repeating: .never, leeway: leeway ?? .nanoseconds(0))
    source.setEventHandler{
        lock.withLock{
            $0.take()
        }?.resume()
    }
    source.setCancelHandler{
        lock.withLock{
            $0.take()
        }?.resume(throwing: CancellationError())
    }
    return try await withTaskCancellationHandler {
        return try await withUnsafeThrowingContinuation{ continuation in
            let snapShot = lock.withLock{
                let oldValue = $0
                switch oldValue {
                case .finished:
                    break
                case .waiting, .continuation:
                    $0 = .continuation(continuation)
                    
                }
                return oldValue
            }
            switch snapShot {
            case .continuation(let unsafeContinuation):
                assertionFailure("reached unexpected state")
                unsafeContinuation.resume(throwing: CancellationError())
            case .finished:
                continuation.resume(throwing: CancellationError())
            case .waiting:
                break
            }
            source.activate()
        }
    } onCancel: {
        lock.withLock{
            $0.take()
        }?.resume(throwing: CancellationError())
        source.cancel()
    }
}



private
enum DispatchSleepState: Sendable {
    
    case waiting
    case continuation(UnsafeContinuation<Void,Error>)
    case finished
    
    mutating func take() -> UnsafeContinuation<Void,Error>? {
        switch self {
        case .waiting, .finished:
            self = .finished
            return nil
        case .continuation(let unsafeContinuation):
            self = .finished
            return unsafeContinuation
        }
    }
}
