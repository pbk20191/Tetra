//
//  Publishers+MapTask.swift
//  
//
//  Created by pbk on 2023/01/04.
//

import Foundation
import Combine

extension Publishers {
    /**
     
        underlying task will receive task cancellation signal if the subscription is cancelled
     
     */
    public struct MapTask<Upstream:Publisher, Output:Sendable>: Publisher where Upstream.Output:Sendable {

        public typealias Output = Output
        public typealias Failure = Upstream.Failure

        public let upstream:Upstream
        public var transform:@Sendable (Upstream.Output) async -> Output

        public init(upstream: Upstream, transform: @escaping @Sendable (Upstream.Output) async -> Output) {
            self.upstream = upstream
            self.transform = transform
        }

        public func receive<S>(subscriber: S) where S : Subscriber, Upstream.Failure == S.Failure, Output == S.Input {
            subscriber
                .receive(
                    subscription: Inner(
                        upstream: upstream, subscriber: subscriber, transform: transform
                    )
                )
        }
        
    }
    
}

extension Publishers.MapTask: Sendable where Upstream: Sendable {}

extension Publishers.MapTask {
    
    
    
    private final class Inner<S:Subscriber>:Subscription, CustomStringConvertible, CustomPlaygroundDisplayConvertible where S.Input == Output, S.Failure == Failure {
        
        var description: String { "MapTask" }
        
        var playgroundDescription: Any { description }
        
        private let task:Task<Void,Never>
        private let demander:DemandAsyncBuffer
        
        fileprivate init(upstream:Upstream, subscriber:S, transform: @escaping @Sendable (Upstream.Output) async -> Output) {
            let buffer = DemandAsyncBuffer()
            let lock = createUncheckedStateLock(uncheckedState: S?.some(subscriber))
            demander = buffer
            task = Task {
                let subscriptionPtr = UnsafeMutablePointer<Subscription>.allocate(capacity: 1)
                let subscriptionSemaphore = DispatchSemaphore(value: 0)
                let stream = AsyncStream<Result<Upstream.Output,Failure>>{ continuation in
                    upstream.subscribe(
                        AnySubscriber(
                            receiveSubscription: {
                                subscriptionPtr.initialize(to: $0)
                                subscriptionSemaphore.signal()
                            },
                            receiveValue: {
                                continuation.yield(.success($0))
                                return .none
                            },
                            receiveCompletion: {
                                switch $0 {
                                case .finished:
                                    break
                                case .failure(let error):
                                    continuation.yield(.failure(error))
                                }
                                continuation.finish()
                            }
                        )
                    )
                    continuation.onTermination = {
                        if case .cancelled = $0 {
                            buffer.close()
                        }
                    }
                }
                let subscription = await withUnsafeContinuation{
                    subscriptionSemaphore.wait()
                    $0.resume(returning: subscriptionPtr.move())
                    subscriptionPtr.deallocate()
                }
                await withTaskCancellationHandler {
                    var iterator = stream.makeAsyncIterator()
                completionLabel:
                    for await demand in buffer {
                        var pending = demand
                        while pending > .none {
                            pending -= 1
                            subscription.request(.max(1))
                            if let result = await iterator.next() {
                                switch result {
                                case .success(let value):
                                    let transformedValue = await transform(value)
                                    if let currentSubscriber = lock.withLockUnchecked({ $0 }) {
                                        pending += currentSubscriber.receive(transformedValue)
                                    } else {
                                        break completionLabel
                                    }
                                case .failure(let failure):
                                    lock.withLockUnchecked{
                                        let oldValue = $0
                                        $0 = nil
                                        return oldValue
                                    }?.receive(completion: .failure(failure))
                                    break completionLabel
                                }
                            } else {
                                break completionLabel
                            }
                        }
                    }
                    lock.withLockUnchecked{
                        let oldValue = $0
                        $0 = nil
                        return oldValue
                    }?.receive(completion: .finished)
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
        
        deinit { task.cancel() }

    }
    
}
