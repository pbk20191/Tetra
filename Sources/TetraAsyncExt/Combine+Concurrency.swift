//
//  Combine+Concurrency.swift
//  
//
//  Created by pbk on 2022/09/06.
//

import Foundation
import Combine

public extension Publisher {
    
    @inlinable
    func mapTask<T:Sendable>(maxTaskCount:Subscribers.Demand = .max(1), transform: @escaping @Sendable (Output) async -> T) -> AnyPublisher<T,Never> where Failure == Never, Output:Sendable {
        flatMap(maxPublishers: maxTaskCount){ output in
            let task = Task { await transform(output) }
            return Future<T,Never> { promise in
                Task { await promise(task.result) }
            }
            .handleEvents(receiveCompletion: { _ in task.cancel() }, receiveCancel: task.cancel)
        }
        .eraseToAnyPublisher()
    }
    
    @inlinable
    func tryMapTask<T:Sendable>(maxTaskCount:Subscribers.Demand = .max(1), transform: @escaping @Sendable (Output) async throws -> T) -> AnyPublisher<T,Error> where Output:Sendable {
        mapError{ $0 }
            .flatMap(maxPublishers: maxTaskCount){ output in
                let task = Task { try await transform(output) }
                return Future<T,Error> { promise in
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
    var sequence:AnyAsyncTypeSequence<Output> {
        if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
            return AnyAsyncTypeSequence(source: WrappedAsyncThrowingPublisher(source: values))
        } else {
            return AnyAsyncTypeSequence(source: CompatAsyncThrowingPublisher(publisher: self))
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


@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct WrappedAsyncPublisher<P:Publisher>: AsyncSequence, AsyncTypedSequence where P.Failure == Never {

    typealias AsyncIterator = Iterator
    typealias Element = P.Output
    
    var source:AsyncPublisher<P>
    
    func makeAsyncIterator() -> Iterator {
        .init(iterator: source.makeAsyncIterator())
    }
    
    struct Iterator: AsyncIteratorProtocol, AsyncTypedIteratorProtocol {
        
        private var iterator:AsyncPublisher<P>.AsyncIterator
        
        mutating func next() async -> Element? {
            await iterator.next()
        }
        
        internal init(iterator: AsyncPublisher<P>.AsyncIterator) {
            self.iterator = iterator
        }
        
    }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct WrappedAsyncThrowingPublisher<P:Publisher>: AsyncTypedSequence {

    typealias AsyncIterator = Iterator
    typealias Element = P.Output

    var source:AsyncThrowingPublisher<P>
    
    func makeAsyncIterator() -> AsyncIterator {
        .init(iterator: source.makeAsyncIterator())
    }
    
    struct Iterator: AsyncIteratorProtocol, AsyncTypedIteratorProtocol {
        
        private var iterator:AsyncThrowingPublisher<P>.Iterator
        
        mutating func next() async throws -> Element? {
            try await iterator.next()
        }
        
        internal init(iterator: AsyncThrowingPublisher<P>.AsyncIterator) {
            self.iterator = iterator
        }
    }
    
}


public struct WrappedAsyncSequence<Element>:AsyncSequence {
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: (source.makeAsyncIterator() as any AsyncIteratorProtocol))
    }
    
    
    public typealias AsyncIterator = Iterator
    private let source:any AsyncSequence
    
    internal init<T:AsyncSequence>(base:T) where T.Element == Element {
        source = base
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        private var iterator:any AsyncIteratorProtocol
        
        mutating public func next() async -> Element? {
            do {
                let value = try await iterator.next()
                switch value {
                case .none:
                    return nil
                case .some(let wrapped as Element):
                    return wrapped
                case .some(let wrapped):
                    let msg = "Expected \(Element.self) but found \(Swift.type(of: wrapped)) instead"
                    print(msg)
                    assertionFailure(msg)
                    return nil
                }
            } catch {
                print(error)
                assertionFailure(error.localizedDescription)
                return nil
            }
        }
        
        internal init(base:some AsyncIteratorProtocol) {
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
    
    public struct Iterator: AsyncIteratorProtocol, AsyncTypedIteratorProtocol {
        
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
        
        internal init(source: P) {
            self.source = source
        }
        
    }
    
    final class AsyncSubscriber: Subscriber, CustomStringConvertible, CustomReflectable, CustomPlaygroundDisplayConvertible {
        var playgroundDescription: Any { description }
        
        var description: String { "AsyncSubscriber<\(Input.self)>"}
        
        var customMirror: Mirror {
            Mirror(self, children: [])
        }
        
        typealias Input = Element
        
        typealias Failure = Never
        
        private var subscription:Subscription?
        private let lock = NSLock()
        private var list:[UnsafeContinuation<Element?,Never>] = []
        
        func receive(_ input: Element) -> Subscribers.Demand {
            lock.withLock {
                let output = list
                list = []
                return output
            }.forEach{ $0.resume(returning: input) }
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Never>) {
            lock.withLock {
                let captured = list
                list = []
                subscription = nil
                return captured
            }.forEach{ $0.resume(returning: nil) }
        }
        

        func awaitNext() async -> Element? {
            return await withTaskCancellationHandler {
                let cancelled = Task.isCancelled
               return await withUnsafeContinuation { continuation in
                   let scription = lock.withLock {
                       if let subscription, !cancelled {
                           list.append(continuation)
                           return subscription as Subscription?
                       }
                       return nil
                   }
                   if let scription {
                       scription.request(.max(1))
                   } else {
                       continuation.resume(returning: nil)
                   }
                }
            } onCancel: {
                self.dispose()
            }
        }
        
        
        func receive(subscription: Subscription) {
            lock.withLock {
                self.subscription = subscription
            }
        }
        
        
        private func dispose() {
            let (continuations, resource) = lock.withLock {
                let captured = (list, subscription)
                list = []
                subscription = nil
                return (captured)
            }
            continuations.forEach{ $0.resume(returning: nil) }
            resource?.cancel()
        }
        
        internal init() {}
    }
    
}

public struct CompatAsyncThrowingPublisher<P:Publisher>: AsyncSequence, AsyncTypedSequence {

    public typealias AsyncIterator = Iterator
    public typealias Element = P.Output
    
    public var publisher:P
    
    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(source: publisher)
    }
    
    public struct Iterator: AsyncIteratorProtocol, AsyncTypedIteratorProtocol {
        
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
        
        internal init(source: P) {
            self.source = source
        }
        
    }
    
    final class AsyncThrowingSubscriber: Subscriber, CustomStringConvertible, CustomReflectable, CustomPlaygroundDisplayConvertible {
        
        typealias Input = Element
        
        typealias Failure = P.Failure
        
        private var subscription:Subscription?
        
        private let lock = NSLock()
        private var list:[UnsafeContinuation<Element?,Error>] = []
        
        
        func receive(_ input: Element) -> Subscribers.Demand {
            lock.withLock {
                let captured = list
                list = []
                return captured
            }.forEach{ $0.resume(returning: input) }
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            let (continuations, _) = lock.withLock {
                let captured = (list, subscription)
                list = []
                subscription = nil
                return captured
            }
            switch completion {
            case .finished:
                continuations.forEach{ $0.resume(returning: nil) }
            case .failure(let failure):
                continuations.forEach{ $0.resume(throwing: failure) }
            }
        }
        

        func awaitNext() async throws -> Element? {
            return try await withTaskCancellationHandler {
                let cancelled = Task.isCancelled
               return try await withUnsafeThrowingContinuation { continuation in
                   let provider = lock.withLock {
                       if let subscription, !cancelled {
                           list.append(continuation)
                           return subscription as Subscription?
                       } else {
                           return nil
                       }
                   }
                   if let provider {
                       provider.request(.max(1))
                   } else {
                       continuation.resume(returning: nil)
                   }
                }
            } onCancel: {
                self.dispose()
            }
        }
        
        
        func receive(subscription: Subscription) {
            lock.withLock {
                self.subscription = subscription
            }
        }
        
        
        private func dispose() {
            let (continuations, cancellable) = lock.withLock {
                let captured = (list, subscription)
                list = []
                subscription = nil
                return captured
            }
            continuations.forEach{ $0.resume(returning: nil) }
            cancellable?.cancel()
        }
        
        internal init() {}
        
        var playgroundDescription: Any { description }
        
        var description: String { "AsyncThrowingSubscriber<\(Input.self),\(Failure.self)>"}
        
        var customMirror: Mirror {
            Mirror(self, children: [])
        }
    }
    
}
