//
//  TaskPublisher.swift
//  
//
//  Created by pbk on 2022/12/26.
//

import Foundation
import Combine

struct TaskPublisher<Output>: Publisher {
    
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
    

    private final class Inner<S:Subscriber>: Subscription where S.Input == Output, S.Failure == Never {
        
        let producer:@Sendable () async -> Output
        private let lock = createUncheckedStateLock(uncheckedState: State())
        
        init(subscriber:S, producer: @Sendable @escaping () async -> Output) {
            self.producer = producer
            lock.withLock{ $0.subscriber = subscriber }
        }
        
        struct State {
            var subscriber:S? = nil
            var task:Task<Void,Never>? = nil
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > .none else { return }
            let newTask = Task{ [lock, producer] in
                let value = await producer()
                let s = lock.withLock { state in
                    let subscriber = state.subscriber
                    state.subscriber = nil
                    return subscriber
                }
                let _ = s?.receive(value)
                s?.receive(completion: .finished)
            }
            lock.withLock { state in
                let oldTask = state.task
                state.task = newTask
                return oldTask
            }?.cancel()
        }
        
        func cancel() {
            let task = lock.withLock { state in
                let capturedTask = state.task
                state.task = nil
                state.subscriber = nil
                return capturedTask
            }
            task?.cancel()
        }
    }
    
}
