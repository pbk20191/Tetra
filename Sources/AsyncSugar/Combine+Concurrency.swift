//
//  Combine+Concurrency.swift
//  
//
//  Created by pbk on 2022/09/06.
//

import Foundation
import Combine

public extension Publisher {
    
    func mapTask<T:Sendable>(maxTaskCount:Subscribers.Demand = .max(1), transform: @escaping @Sendable (Output) async -> T) -> AnyPublisher<T,Never> where Failure == Never, Output:Sendable {
        map{ output in
            Task {
                await withTaskCancellationHandler {
                    Swift.print("\(#function) taskCancel")
                } operation: {
                    await transform(output)
                }
            }
        }
        .flatMap(maxPublishers: maxTaskCount){ task in
            Future<T,Never> { promise in
                Task { await promise(task.result) }
            }
            .handleEvents(receiveCompletion: { _ in task.cancel() }, receiveCancel: task.cancel)
        }
        .eraseToAnyPublisher()
    }
    
    func tryMapTask<T:Sendable>(maxTaskCount:Subscribers.Demand = .max(1), transform: @escaping @Sendable (Output) async throws -> T) -> AnyPublisher<T,Error> where Output:Sendable {
        mapError{ $0 }
            .map{ output in
                Task {
                    try await withTaskCancellationHandler {
                        Swift.print("\(#function) taskCancel")
                    } operation: {
                        try await transform(output)
                    }
                }
            }
            .flatMap(maxPublishers: maxTaskCount){ task in
                Future<T,Error> { promise in
                    Task { await promise(task.result) }
                }
                .handleEvents(receiveCompletion: { _ in task.cancel() }, receiveCancel: task.cancel)
            }
            .eraseToAnyPublisher()
    }
    
    @available(iOS, deprecated: 15.0, renamed: "values")
    @available(macCatalyst, deprecated: 15.0, renamed: "values")
    @available(tvOS, deprecated: 15.0, renamed: "values")
    @available(macOS, deprecated: 12.0, renamed: "values")
    @available(watchOS, deprecated: 8.0, renamed: "values")
    var sequence:WrappedThrowingAsyncSequence<Output> {
        if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
            return WrappedThrowingAsyncSequence(base: values)
        } else {
            return WrappedThrowingAsyncSequence(base: CompatAsyncThrowingPublisher(publisher: self))
        }
    }
    
}


public extension Publisher where Failure == Never {
    
    @available(iOS, deprecated: 15.0, renamed: "values")
    @available(macCatalyst, deprecated: 15.0, renamed: "values")
    @available(tvOS, deprecated: 15.0, renamed: "values")
    @available(macOS, deprecated: 12.0, renamed: "values")
    @available(watchOS, deprecated: 8.0, renamed: "values")
    var sequence:WrappedAsyncSequence<Output> {
        if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
            return WrappedAsyncSequence(base: values)
        } else {
            return WrappedAsyncSequence(base: CompatAsyncPublisher(publisher: self))
        }
    }
    
}

public struct WrappedThrowingAsyncSequence<Element>:AsyncSequence {
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: (source.makeAsyncIterator() as any AsyncIteratorProtocol))
    }
    
    
    public typealias AsyncIterator = Iterator
    private let source:any AsyncSequence
    
    public init<T:AsyncSequence>(base:T) where T.Element == Element {
        source = base
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        private var iterator:any AsyncIteratorProtocol
        
        mutating public func next() async throws -> Element? {
            let value = try await iterator.next()
            switch (value) {
            case .none:
                return nil
            case let e as Element:
                return e
            default:
                let msg = "Expected \(Element.self) but found \(Swift.type(of: value.unsafelyUnwrapped)) instead"
                print(msg)
                assertionFailure(msg)
                return nil
            }
        }
        
        fileprivate init(base:some AsyncIteratorProtocol) {
            iterator = base
        }
    }
}

public struct WrappedAsyncSequence<Element>:AsyncSequence {
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: (source.makeAsyncIterator() as any AsyncIteratorProtocol))
    }
    
    
    public typealias AsyncIterator = Iterator
    private let source:any AsyncSequence
    
    fileprivate init<T:AsyncSequence>(base:T) where T.Element == Element {
        source = base
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        private var iterator:any AsyncIteratorProtocol
        
        mutating public func next() async -> Element? {
            let value = try? await iterator.next()
            switch (value) {
            case .none:
                return nil
            case let e as Element:
                return e
            default:
                let msg = "Expected \(Element.self) but found \(Swift.type(of: value.unsafelyUnwrapped)) instead"
                print(msg)
                assertionFailure(msg)
                return nil
            }
        }
        
        fileprivate init(base:some AsyncIteratorProtocol) {
            iterator = base
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
        
        public typealias Element = P.Output
        
        let source:P
        private var subscriber:AsyncSubscriber?
        
        public mutating func next() async -> P.Output? {
            if Task.isCancelled {
                subscriber = nil
                return nil
            } else if let subscriber {
                return await subscriber.awaitNext()
            } else {
                let a = AsyncSubscriber()
                source.receive(subscriber: a)
                subscriber = a
                return await a.awaitNext()
            }
        }
        
        fileprivate init(source: P) {
            self.source = source
        }
        
    }
    
    final class AsyncSubscriber: Subscriber {
        
        typealias Input = Element
        
        typealias Failure = Never
        
        private var token:AnyCancellable?
        private var subscription:Subscription?
        private let store = ContinuationStore()
        func receive(_ input: Element) -> Subscribers.Demand {
            store.mutate { list in
                list.forEach { $0.resume(returning: input) }
                list = []
            }
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Never>) {
            store.mutate {
                $0.forEach { continuation in continuation.resume(returning: nil) }
                $0 = []
                subscription = nil
            }
            token = nil
        }
        

        func awaitNext() async -> Element? {
            return await withTaskCancellationHandler {
                self.dispose()
            } operation: {
                let cancelled = Task.isCancelled
               return await withUnsafeContinuation { continuation in
                   if let subscription, !cancelled {
                       store.mutate {
                           $0.append(continuation)
                       }
                       subscription.request(.max(1))

                   } else {
                       continuation.resume(returning: nil)
                   }

                }
            }
        }
        
        
        func receive(subscription: Subscription) {
            self.subscription = subscription

            token = AnyCancellable(subscription)
        }
        
        
        private func dispose() {
            token = nil
            subscription = nil
            store.mutate { list in
                list.forEach{ $0.resume(returning: nil) }
                list = []
            }
        }
        
        fileprivate init() {}
    }

    final class ContinuationStore {
        private let lock = NSLock()
        var list:[UnsafeContinuation<Element?,Never>] = []
        func mutate(operation: (inout [UnsafeContinuation<Element?,Never>]) -> Void) {
            lock.lock()
            operation(&list)
            lock.unlock()
        }
        fileprivate init() {}
    }

    
}

public struct CompatAsyncThrowingPublisher<P:Publisher>: AsyncSequence {

    public typealias AsyncIterator = Iterator
    public typealias Element = P.Output
    
    public var publisher:P
    
    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(source: publisher)
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        
        public typealias Element = P.Output
        
        let source:P
        private var subscriber:AsyncThrowingSubscriber?
        
        public mutating func next() async throws -> P.Output? {
            if Task.isCancelled {
                subscriber = nil
                return nil
            } else if let subscriber {
                return try await subscriber.awaitNext()
            } else {
                let a = AsyncThrowingSubscriber()
                source.receive(subscriber: a)
                subscriber = a
                return try await a.awaitNext()
            }
        }
        
        fileprivate init(source: P) {
            self.source = source
        }
        
    }
    
    final class AsyncThrowingSubscriber: Subscriber{
        
        typealias Input = Element
        
        typealias Failure = P.Failure
        
        private var token:AnyCancellable?
        private var subscription:Subscription?
        private let store = ContinuationThrowingStore()
        func receive(_ input: Element) -> Subscribers.Demand {
            store.mutate { list in
                list.forEach { $0.resume(returning: input) }
                list = []
            }
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            store.mutate {
                switch completion {
                case .finished:
                    $0.forEach { continuation in continuation.resume(returning: nil) }
                case .failure(let failure):
                    $0.forEach { continuation in continuation.resume(throwing: failure) }
                }
                $0 = []
                subscription = nil
            }
        }
        

        func awaitNext() async throws -> Element? {
            return try await withTaskCancellationHandler {
                self.dispose()
            } operation: {
                let cancelled = Task.isCancelled
               return try await withUnsafeThrowingContinuation { continuation in
                   if let subscription, !cancelled {
                       store.mutate {
                           $0.append(continuation)
                       }
                       subscription.request(.max(1))

                   } else {
                       continuation.resume(returning: nil)
                   }

                }
            }
        }
        
        
        func receive(subscription: Subscription) {
            self.subscription = subscription
            token = AnyCancellable(subscription)
        }
        
        
        private func dispose() {
            token = nil
            subscription = nil
            store.mutate { list in
                list.forEach{ $0.resume(returning: nil) }
                list = []
            }
        }
        
        fileprivate init() {}
    }

    final class ContinuationThrowingStore {
        private let lock = NSLock()
        private var list:[UnsafeContinuation<Element?,Error>] = []
        internal func mutate(operation: (inout [UnsafeContinuation<Element?,Error>]) -> Void) {
            lock.lock()
            operation(&list)
            lock.unlock()
        }
        
        fileprivate init() {}
    }

    
}

