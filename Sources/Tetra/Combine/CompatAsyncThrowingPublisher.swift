//
//  CompatAsyncThrowingPublisher.swift
//  
//
//  Created by pbk on 2022/12/16.
//

import Foundation
import Combine

public struct CompatAsyncThrowingPublisher<P:Publisher>: AsyncSequence {

    public typealias AsyncIterator = Iterator
    public typealias Element = P.Output
    
    public var publisher:P
    
    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(source: publisher)
    }
    
    public struct Iterator: AsyncTypedIteratorProtocol {
        
        public typealias Element = P.Output
        
        private let inner = AsyncThrowingSubscriber<P>()
        private let reference:AnyCancellable
        
        public func next() async throws -> P.Output? {
            try await withTaskCancellationHandler(operation: inner.next) {
                reference.cancel()
            }
        }
        
        internal init(source: P) {
            self.reference = AnyCancellable(inner)
            source.subscribe(inner)
        }
        
    }
    
    public init(publisher: P) {
        self.publisher = publisher
    }

}




private final class AsyncThrowingSubscriber<P:Publisher> : Subscriber, Cancellable {
    
    typealias Input = P.Output
    typealias Failure = P.Failure
    
    private let lock:some UnfairStateLock<SubscribedState> = createUncheckedStateLock(uncheckedState: SubscribedState())

    private struct SubscribedState {
        var status = SubscriptionStatus.awaitingSubscription
        var pending:[UnsafeContinuation<Input?,Error>] = []
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
    
    func receive(completion: Subscribers.Completion<Failure>) {
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
            $0.status = .subscribed(subscription)
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
        
    func next() async throws -> Input? {
        return try await withUnsafeThrowingContinuation { continuation in
            let subscriptionState = lock.withLock {
                switch $0.status {
                case .awaitingSubscription:
                    $0.pendingDemand += 1
                case .subscribed(_):
                    $0.pending.append(continuation)
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

