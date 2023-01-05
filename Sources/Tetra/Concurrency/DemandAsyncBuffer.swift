//
//  DemandAsyncBuffer.swift
//  
//
//  Created by pbk on 2023/01/03.
//

import Foundation
import Combine
import _Concurrency

@usableFromInline
struct DemandAsyncBuffer: AsyncSequence, Sendable {
    
    @usableFromInline
    func makeAsyncIterator() -> AsyncIterator {
        stream.makeAsyncIterator()
    }
    
    @usableFromInline
    typealias Element = Subscribers.Demand
    @usableFromInline
    typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
    
    private let stream:AsyncStream<Element>
    private let continuation: AsyncStream<Element>.Continuation
    
    init() {
        var reference:AsyncStream<Element>.Continuation? = nil
        let semaphore = DispatchSemaphore(value: 0)
        stream = .init{
            reference = $0
            semaphore.signal()
        }
        semaphore.wait()
        continuation = reference.unsafelyUnwrapped
    }
    
    func append(element: __owned Element) {
        continuation.yield(element)
    }
    
    func close() {
        continuation.finish()
    }
    
}
