//
//  SubscriptionContinuation.swift
//  
//
//  Created by pbk on 2023/01/29.
//

import Foundation
import Combine

@usableFromInline
internal enum SubscriptionContinuation {
    
    case waiting
    case cached(Subscription)
    case suspending(UnsafeContinuation<Subscription?,Never>)
    case finished
    
}

internal extension UnfairStateLock where State == SubscriptionContinuation {
    
    @usableFromInline
    func received(_ subscription:Subscription) {
        let snapShot = withLock{
            let oldValue = $0
            switch oldValue {
            case .waiting:
                $0 = .cached(subscription)
            case .cached(_):
                $0 = .cached(subscription)
            case .suspending(_):
                break
            case .finished:
                break
            }
            return oldValue
        }
        switch snapShot {
        case .waiting:
            break
        case .cached(let oldValue):
            assertionFailure("received subscption more than once")
            oldValue.cancel()
        case .suspending(let continuation):
            continuation.resume(returning: subscription)
        case .finished:
            subscription.cancel()
        }
    }
    
    @usableFromInline
    func consumeSubscription() async -> Subscription? {
        await withTaskCancellationHandler {
            await withUnsafeContinuation{ continuation in
                let snapShot = withLock{
                    let oldValue = $0
                    switch oldValue {
                    case .waiting:
                        $0 = .suspending(continuation)
                    case .cached(_):
                        $0 = .finished
                    case .suspending(_):
                        $0 = .suspending(continuation)
                    case .finished:
                        break
                    }
                    return oldValue
                }
                switch snapShot {
                    
                case .waiting:
                    break
                case .cached(let subscription):
                    continuation.resume(returning: subscription)
                case .suspending(let oldValue):
                    assertionFailure("received continuation more than once")
                    oldValue.resume(returning: nil)
                case .finished:
                    continuation.resume(returning: nil)
                }
            }
        } onCancel: {
            let snapShot = withLock{
                let oldValue = $0
                $0 = .finished
                return oldValue
            }
            switch snapShot {
                
            case .waiting:
                break
            case .cached(let cancellable):
                cancellable.cancel()
            case .suspending(let continuation):
                continuation.resume(returning: nil)
            case .finished:
                break
            }
        }
    }
    
}
