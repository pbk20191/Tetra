//
//  SingleTaskPublisher.swift
//  
//
//  Created by pbk on 2022/12/26.
//

import Foundation
import Combine


/// A publisher that emits an task result to each subscriber just once, and then finishes.
struct SingleTaskPublisher<Output>: Publisher {
    
    typealias Failure = Never
    
    let producer:@Sendable () async -> Output
    
    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Output == S.Input {
        subscriber.receive(
            subscription: Inner(
                subscriber: subscriber,
                producer: producer
            )
        )
    }
    

    private final class Inner<S:Subscriber>: Subscription, CustomStringConvertible, CustomPlaygroundDisplayConvertible where S.Input == Output, S.Failure == Never {
        var description: String { "SingleTask" }
        
        var playgroundDescription: Any { description }
        
        
        private let task: Task<Void,Never>
        private let buffer = DemandAsyncBuffer()
        
        init(subscriber:S, producer: @Sendable @escaping () async -> Output) {

            let lock = createUncheckedStateLock(uncheckedState: Optional<S>.some(subscriber))
            let sequence = buffer
            
            task = Task {
                await withTaskCancellationHandler {
                    if await sequence.first(where: { $0 > .none }) != nil {
                        let value = await producer()
                        let snapShot = lock.withLockUnchecked{
                            let oldValue = $0
                            $0 = nil
                            return oldValue
                        }
                        let _ = snapShot?.receive(value)
                        snapShot?.receive(completion: .finished)
                    }
                } onCancel: {
                    lock.withLock{ $0 = nil }
                }

            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            buffer.append(element: demand)
        }
        
        func cancel() {
            task.cancel()
        }
        
    }
    
}
