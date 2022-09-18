//
//  File.swift
//  
//
//  Created by pbk on 2022/09/16.
//

import Foundation
import Combine

public extension AsyncStream {
    var publisher:AnyPublisher<Element,Never> {
        Just(self).flatMap(maxPublishers: .max(1)) { source in
            let subject = PassthroughSubject<Element,Never>()
            let task = Task {
                await withTaskCancellationHandler {
                    print("asyncStream cancelled")
                } operation: {
                    for await i in source {
                        subject.send(i)
                    }
                    subject.send(completion: .finished)
                }

            }
            return subject.handleEvents(receiveCancel: task.cancel)
        }.eraseToAnyPublisher()
    }
}

public extension AsyncSequence {
    var publisher:AnyPublisher<Element,Error> {
        if #available(iOS 14.0, tvOS 14.0, macCatalyst 14.0, watchOS 7.0, macOS 11.0, *) {
            return Just(self).flatMap(maxPublishers: .max(1)) { source in
                let subject = PassthroughSubject<Element,Error>()
                let task = Task {
                    await withTaskCancellationHandler {
                        print("asyncSequence cancelled")
                    } operation: {
                        do {
                            for try await i in source {
                                subject.send(i)
                            }
                            subject.send(completion: .finished)
                        } catch {
                            subject.send(completion: .failure(error))
                        }
                    }
                }
                return subject.handleEvents(receiveCancel: task.cancel)
            }.eraseToAnyPublisher()
        } else {
            return Just(self).setFailureType(to: Error.self).flatMap(maxPublishers: .max(1)) { source in
                let subject = PassthroughSubject<Element,Error>()
                let task = Task {
                    await withTaskCancellationHandler {
                        print("asyncSequence cancelled")
                    } operation: {
                        do {
                            for try await i in source {
                                subject.send(i)
                            }
                            subject.send(completion: .finished)
                        } catch {
                            subject.send(completion: .failure(error))
                        }
                    }

                }
                    
                return subject.handleEvents(receiveCancel: task.cancel)
            }.eraseToAnyPublisher()
        }

    }
}


fileprivate final class RefBox<T> {
    var value:T?

}


public struct CompatAsyncThrowingPublisher<P:Publisher>: AsyncSequence where P.Failure:Error {

    public typealias AsyncIterator = Iterator
    public typealias Element = P.Output
    
    public var publisher:P
    
    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(source: publisher)
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        
        public typealias Element = P.Output
        let source:P
        private var base:AsyncThrowingStream<Element,Error>.Iterator? = nil
        private let box = RefBox<Subscription>()
        
        mutating public func next() async throws -> P.Output? {
            if base == nil {
                base = setup()
            }
            if Task.isCancelled {
                box.value?.cancel()
            } else {
                box.value?.request(.max(1))
            }
            return try await base?.next()
        }
        
        fileprivate init(source: P) {
            self.source = source

        }
        
        private func setup() -> AsyncThrowingStream<Element,Error>.Iterator {
            let sema = DispatchSemaphore(value: 0)
            
            let iterator = AsyncThrowingStream<Element,Error>{ continuation in
                let subscriber = AnySubscriber<Element,Error> { [box] subscription in
                    box.value = subscription
                    sema.signal()
                } receiveValue: { value in
                    continuation.yield(value)
                    return .none
                } receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        continuation.finish()
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { [box] event in
                    if case .cancelled = event {
                        box.value?.cancel()
                    }
                }

                DispatchQueue.global().async { [source] in
                    source.mapError{ $0 }.receive(subscriber: subscriber)
                }
            }.makeAsyncIterator()
            sema.wait()
            return iterator
        }
        
    }
    

 
}



public struct CompatAsyncPublisher<P:Publisher>: AsyncSequence where P.Failure == Never {

    public typealias AsyncIterator = Iterator
    public typealias Element = P.Output
    
    public var publisher:P
    
    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(source: publisher)
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        
        public typealias StoredType = Subscription & AnyObject
        public typealias Element = P.Output
        
        let source:P
        private var base:AsyncStream<Element>.Iterator? = nil
        private let box = RefBox<Subscription>()
        
        public mutating func next() async -> P.Output? {
            if base == nil {
                base = setup()
            }
            if Task.isCancelled {
                box.value?.cancel()
            } else {
                box.value?.request(.max(1))
            }
            return await base?.next()
        }
        
        fileprivate init(source: P) {
            self.source = source
        }
        
        private func setup() -> AsyncStream<Element>.Iterator {
            let sema = DispatchSemaphore(value: 0)

            let iterator = AsyncStream<Element>{ continuation in
                let subscriber = AnySubscriber<Element,Never> { [box] subscription in
                    box.value = subscription
                    sema.signal()
                } receiveValue: { value in
                    continuation.yield(value)
                    return .none
                } receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        continuation.finish()
                    }
                }
                continuation.onTermination = { [box] event in
                    if case .cancelled = event {
                        box.value?.cancel()
                    }
                }

                DispatchQueue.global().async { [source] in
                    source.receive(subscriber: subscriber)
                }
            }.makeAsyncIterator()
            sema.wait()
            return iterator
        }
        
    }
    
}
