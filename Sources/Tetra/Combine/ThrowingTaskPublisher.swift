//
//  ThrowingTaskPublisher.swift
//  
//
//  Created by pbk on 2022/12/26.
//

import Foundation
import Combine

struct ThrowingTaskPublisher<Output>: Publisher {
    
    typealias Failure = Error
    
    let producer:@Sendable () async throws -> Output
    
    func receive<S>(subscriber: S) where S : Subscriber, Error == S.Failure, Output == S.Input {
        subscriber.receive(
            subscription: Inner(
                subscriber: subscriber,
                producer: producer
            )
        )
    }
    

    private final class Inner<S:Subscriber>: Subscription where S.Input == Output, S.Failure == Error {
        
        let producer:@Sendable () async throws -> Output
        private let lock = createUncheckedStateLock(uncheckedState: State())
        
        init(subscriber:S, producer: @Sendable @escaping () async throws -> Output) {
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
                do {
                    let value = try await producer()
                    let s = lock.withLock { state in
                        let subscriber = state.subscriber
                        state.subscriber = nil
                        return subscriber
                    }
                    let _ = s?.receive(value)
                    s?.receive(completion: .finished)
                } catch {
                    lock.withLock{ state in
                        let subscriber = state.subscriber
                        state.subscriber = nil
                        return subscriber
                    }?.receive(completion: .failure(error))
                }
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
