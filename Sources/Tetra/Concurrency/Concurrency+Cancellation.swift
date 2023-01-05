//
//  Concurrency+Cancellation.swift
//  
//
//  Created by pbk on 2023/01/05.
//

import Foundation

@usableFromInline
internal func waitCancellation() async -> CancellationError {
    let lock = createCheckedStateLock(checkedState: UnsafeContinuation<Void,Never>?.none)
    if Task.isCancelled {
        return CancellationError()
    }
    await withTaskCancellationHandler {
        await withUnsafeContinuation{ continuation in
            if Task.isCancelled {
                continuation.resume()
            } else {
                lock.withLock{
                    $0 = continuation
                }
            }
        }
    } onCancel: {
        lock.withLock{
            let snapShot = $0
            $0 = nil
            return snapShot
        }?.resume()
    }
    return CancellationError()
}
