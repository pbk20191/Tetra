//
//  AsyncTypedSequence.swift
//  
//
//  Created by pbk on 2022/09/26.
//

import Combine
import _Concurrency

@usableFromInline
internal protocol AsyncTypedIteratorProtocol<Element>:AsyncIteratorProtocol {}

@usableFromInline
internal protocol NonthrowingAsyncIteratorProtocol<Element>: AsyncIteratorProtocol {
    
    mutating func next() async -> Element?
    
}

public struct AnyAsyncTypeSequence<Element>: AsyncSequence {
    
    private let builder:@Sendable () -> AsyncIterator
    
    public typealias AsyncIterator = Iterator
    
    internal init<T:AsyncSequence>(base:T) where T.Element == Element, T.AsyncIterator : AsyncTypedIteratorProtocol {
        builder = { [base] in Iterator(base: base.makeAsyncIterator()) }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        builder()
    }
    
    public struct Iterator: AsyncTypedIteratorProtocol {
        
        public mutating func next() async throws -> Element? {
            try await base.next()
        }
        
        private var base:any AsyncTypedIteratorProtocol<Element>
        
        internal init<T:AsyncTypedIteratorProtocol>(base: T) where T.Element == Element {
            self.base = base
        }
        
    }
}

public struct WrappedAsyncSequence<Element>:AsyncSequence {
    
    public func makeAsyncIterator() -> Iterator {
        builder()
    }
    
    public typealias AsyncIterator = Iterator
    private let builder: @Sendable () -> AsyncIterator
    
    internal init<T:AsyncSequence>(base:T) where T.Element == Element, T.AsyncIterator: NonthrowingAsyncIteratorProtocol {
        builder = { [base] in
            Iterator(base: base.makeAsyncIterator())
        }
    }
    
    public struct Iterator: AsyncIteratorProtocol {
        
        private var iterator:any NonthrowingAsyncIteratorProtocol<Element>
        
        mutating public func next() async -> Element? {
            await iterator.next()
        }
        
        internal init<T:NonthrowingAsyncIteratorProtocol>(base:T) where T.Element == Element {
            iterator = base
        }
    }
}


@available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *)
extension AsyncThrowingPublisher.Iterator: AsyncTypedIteratorProtocol {}

@available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *)
extension AsyncPublisher.Iterator: NonthrowingAsyncIteratorProtocol{}
