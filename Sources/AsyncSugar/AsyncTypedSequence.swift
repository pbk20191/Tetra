//
//  AsyncTypedSequence.swift
//  
//
//  Created by pbk on 2022/09/26.
//

import Foundation

public protocol AsyncTypedSequence<Element>: AsyncSequence where AsyncIterator: AsyncTypedIteratorProtocol {}

public protocol AsyncTypedIteratorProtocol<Element>:AsyncIteratorProtocol {}


public struct AnyAsyncTypeSequence<Element>:AsyncSequence, AsyncTypedSequence {
    
    private let builder:@Sendable () -> AsyncIterator
    
    internal init<T:AsyncTypedSequence>(source:T) where T.Element == Element {
        builder = { AnyAsyncIterator(iterator: source.makeAsyncIterator()) }
    }
    
    public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
        builder()
    }
}

public struct AnyAsyncIterator<Element>: AsyncIteratorProtocol, AsyncTypedIteratorProtocol {
    
    public mutating func next() async throws -> Element? {
        try await iterator.next()
    }
    
    private var iterator:any AsyncTypedIteratorProtocol<Element>
    
    internal init<T:AsyncTypedIteratorProtocol<Element>>(iterator: T) where T.Element == Element {
        self.iterator = iterator
    }
    
}
