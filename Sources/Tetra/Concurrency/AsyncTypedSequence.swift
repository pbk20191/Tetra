//
//  AsyncTypedSequence.swift
//  
//
//  Created by pbk on 2022/09/26.
//

import Combine
import _Concurrency

public protocol AsyncTypedSequence<Element>: AsyncSequence where AsyncIterator: AsyncTypedIteratorProtocol {}

public protocol AsyncTypedIteratorProtocol<Element>:AsyncIteratorProtocol {}

internal protocol NonthrowingAsyncIteratorProtocol<Element>: AsyncTypedIteratorProtocol {
    
    mutating func next() async -> Element?
    
}

public struct AnyAsyncTypeSequence<Element>: AsyncTypedSequence {
    
    private let builder:@Sendable () -> AsyncIterator
    
    public typealias AsyncIterator = Iterator
    
    internal init<T:AsyncTypedSequence>(base:T) where T.Element == Element {
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

public struct WrappedAsyncSequence<Element>:AsyncTypedSequence {
    
    public func makeAsyncIterator() -> Iterator {
        builder()
    }
    
    public typealias AsyncIterator = Iterator
    private let builder: @Sendable () -> AsyncIterator
    
    internal init<T:AsyncTypedSequence>(base:T) where T.Element == Element, T.AsyncIterator: NonthrowingAsyncIteratorProtocol {
        builder = { [base] in
            Iterator(base: base.makeAsyncIterator())
        }
    }
    
    public struct Iterator: AsyncTypedIteratorProtocol {
        
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
extension AsyncThrowingPublisher: AsyncTypedSequence {}

@available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *)
extension AsyncThrowingPublisher.Iterator: AsyncTypedIteratorProtocol {}

@available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *)
extension AsyncPublisher: AsyncTypedSequence {}

@available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *)
extension AsyncPublisher.Iterator: AsyncTypedIteratorProtocol {}

@available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *)
extension AsyncPublisher.Iterator: NonthrowingAsyncIteratorProtocol{}
