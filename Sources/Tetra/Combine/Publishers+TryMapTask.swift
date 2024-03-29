//
//  Publishers+TryMapTask.swift
//  
//
//  Created by pbk on 2023/01/04.
//

import Foundation
import Combine
import _Concurrency

extension Publishers {

    /**
     
        underlying task will receive task cancellation signal if the subscription is cancelled
     
     */
    public struct TryMapTask<Upstream:Publisher, Output:Sendable>: Publisher where Upstream.Output:Sendable {

        public typealias Output = Output
        public typealias Failure = Error

        public let upstream:Upstream
        public var transform:@Sendable (Upstream.Output) async throws -> Output

        public init(upstream: Upstream, transform: @escaping @Sendable (Upstream.Output) async throws -> Output) {
            self.upstream = upstream
            self.transform = transform
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            subscriber
                .receive(
                    subscription: Inner(
                        upstream: upstream, subscriber: subscriber, transform: transform
                    )
                )
        }

    }

}


extension Publishers.TryMapTask: Sendable where Upstream: Sendable {}

extension Publishers.TryMapTask {
    
    private final class Inner<S:Subscriber>:Subscription, CustomStringConvertible, CustomPlaygroundDisplayConvertible where S.Input == Output, S.Failure == Failure {
        
        var description: String { "TryMapTask" }
        
        var playgroundDescription: Any { description }
        
        private let task:Task<Void,Never>
        private let demander:DemandAsyncBuffer
        
        fileprivate init(upstream:Upstream, subscriber:S, transform: @escaping @Sendable (Upstream.Output) async throws -> Output) {
            let buffer = DemandAsyncBuffer()
            let lock = createUncheckedStateLock(uncheckedState: S?.some(subscriber))
            demander = buffer
            task = Task {
                let subscriptionLock = createCheckedStateLock(checkedState: SubscriptionContinuation.waiting)
                let stream = AsyncThrowingStream<Upstream.Output,Failure> { continuation in
                    continuation.onTermination = {
                        if case .cancelled = $0 {
                            buffer.close()
                        }
                    }
                    upstream
                        .subscribe(
                            AnySubscriber(
                                receiveSubscription: subscriptionLock.received,
                                receiveValue: {
                                    continuation.yield($0)
                                    return .none
                                },
                                receiveCompletion: {
                                    switch $0 {
                                    case .finished:
                                        continuation.finish(throwing: .none)
                                    case .failure(let error):
                                        continuation.finish(throwing: error)
                                    }
                                }
                            )
                        )
                }
                guard let subscription = await subscriptionLock.consumeSubscription()
                else { return }
                await withTaskCancellationHandler {
                    var iterator = stream.makeAsyncIterator()
                    do {
                    completionLabel:
                        for await demand in buffer {
                            var pending = demand
                            while pending > .none {
                                pending -= 1
                                subscription.request(.max(1))
                                if let upstreamValue = try await iterator.next() {
                                    let value = try await transform(upstreamValue)
                                    if let currentSubscriber = lock.withLockUnchecked({ $0 }) {
                                        pending += currentSubscriber.receive(value)
                                    } else {
                                        break completionLabel
                                    }
                                } else {
                                    break completionLabel
                                }
                            }
                        }
                        if !Task.isCancelled {
                            lock.withLockUnchecked{
                                let oldValue = $0
                                $0 = nil
                                return oldValue
                            }?.receive(completion: .finished)
                        }
                    } catch {
                        lock.withLockUnchecked{
                            let oldValue = $0
                            $0 = nil
                            return oldValue
                        }?.receive(completion: .failure(error))
                    }
                } onCancel: {
                    subscription.cancel()
                    lock.withLock{ $0 = nil }
                }
                buffer.close()
            }
        }
        
        func cancel() {
            task.cancel()
        }
        
        func request(_ demand: Subscribers.Demand) {
            demander.append(element: demand)
        }
        
        deinit {
            task.cancel()
        }

    }
    
}
