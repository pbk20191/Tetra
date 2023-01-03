//
//  SingleThrowingTaskPublisher.swift
//  
//
//  Created by pbk on 2022/12/26.
//

import Foundation
import Combine

/// A publisher that emits an task result to each subscriber just once, and then finishes.
struct SingleThrowingTaskPublisher<Output>: Publisher {
    
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
        
        private let task: Task<Void,Never>
        private let buffer = DemandAsyncBuffer()
        
        init(subscriber:S, producer: @Sendable @escaping () async throws -> Output) {

            let lock = createUncheckedStateLock(uncheckedState: Optional<S>.some(subscriber))
            let sequence = buffer
            
            task = Task {
                await withTaskCancellationHandler {
                    if await sequence.first(where: { $0 > .none }) != nil {
                        let result:Result<Output,Error>
                        do {
                            result = .success(try await producer())
                        } catch {
                            result = .failure(error)
                        }
                        let snapShot = lock.withLockUnchecked{
                            let oldValue = $0
                            $0 = nil
                            return oldValue
                        }
                        switch result {
                        case .success(let success):
                            let _ = snapShot?.receive(success)
                            snapShot?.receive(completion: .finished)
                        case .failure(let failure):
                            snapShot?.receive(completion: .failure(failure))
                        }
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
