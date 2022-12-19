//
//  CompatAsyncPublisher.swift
//  
//
//  Created by pbk on 2022/12/16.
//

import Foundation
import Combine

public struct CompatAsyncPublisher<P:Publisher>: AsyncTypedSequence where P.Failure == Never {

    public typealias AsyncIterator = Iterator
    public typealias Element = P.Output
    
    public var publisher:P
    
    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(source: publisher)
    }
    
    public struct Iterator: AsyncTypedIteratorProtocol, NonthrowingAsyncIteratorProtocol {
        
        public typealias Element = P.Output
        
        private let inner = AsyncSubscriber<P>()
        private let reference:AnyCancellable
        
        public func next() async -> P.Output? {
            await withTaskCancellationHandler(operation: inner.next) {
                reference.cancel()
            }
        }
        
        internal init(source: P) {
            self.reference = AnyCancellable(inner)
            source.subscribe(inner)
        }
        
    }
        
}

private final class AsyncSubscriber<P:Publisher> : Subscriber, Cancellable where P.Failure == Never {
    
    typealias Input = P.Output
    typealias Failure = Never
    
    private let lock = ManagedUnfairLock(uncheckedState: SubscribedState())
    
    private struct SubscribedState {
        var status = SubscriptionStatus.awaitingSubscription
        var pending:[UnsafeContinuation<Input?,Never>] = []
        var pendingDemand = Subscribers.Demand.none
    }
    
    fileprivate init() {
        
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        lock.withLock {
            let output = $0.pending
            $0.pending = []
            return output
        }.forEach{ $0.resume(returning: input) }
        return .none
    }
    
    func receive(completion: Subscribers.Completion<Never>) {
        lock.withLock {
            let captured = $0.pending
            $0.pending = []
            return captured
        }.forEach{
            switch completion {
            case .finished:
                $0.resume(returning: nil)
            case .failure(let failure):
                $0.resume(throwing: failure)
            }
        }
    }
    
    func receive(subscription: Subscription) {
        let pendingDemand = lock.withLock {
            guard case .awaitingSubscription = $0.status else { return nil as Subscribers.Demand? }
            let demand = $0.pendingDemand
            $0.pendingDemand = .none
            return demand as Subscribers.Demand?
        }
        if let pendingDemand {
            if pendingDemand > .none {
                subscription.request(pendingDemand)
            }
        } else {
            subscription.cancel()
        }
    }
    
    
    func cancel() {
        let (continuations, resource) = lock.withLock {
            let captured = ($0.pending, $0.status)
            $0.pending = []
            $0.status = .terminal
            return (captured)
        }
        continuations.forEach{ $0.resume(returning: nil) }
        switch resource {
        case .subscribed(let cancellable):
            cancellable.cancel()
        default:
            break
        }
    }

    
    func next() async -> Input? {
        await withUnsafeContinuation { continuation in
            let subscriptionState = lock.withLock {
                switch $0.status {
                case .subscribed(_):
                    $0.pending.append(continuation)
                    
                case .awaitingSubscription:
                    $0.pendingDemand += 1
                case .terminal:
                    break
                }
                return $0.status
            }
            switch subscriptionState {
            case .awaitingSubscription:
                break
            case .subscribed(let subscription):
                subscription.request(.max(1))
            case .terminal:
                continuation.resume(returning: nil)
            }
         }
    }
    
}
