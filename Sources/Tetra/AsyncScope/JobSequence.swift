//
//  JobSequence.swift
//  
//
//  Created by pbk on 2022/12/31.
//

import Foundation

@usableFromInline
struct JobSequence: Sendable, AsyncSequence {

    @usableFromInline
    func makeAsyncIterator() -> AsyncIterator {
        stream.makeAsyncIterator()
    }
    
    @usableFromInline
    typealias Element = @Sendable () async -> ()
    @usableFromInline
    typealias AsyncIterator = AsyncStream<Element>.AsyncIterator

    
    private let stream:AsyncStream<Element>
    private let continuation:AsyncStream<Element>.Continuation
    
    init() {
        let (source, ref) = AsyncStream<Element>.makeStream()
        stream = source
        continuation = ref
    }
    
    func append(job: __owned @escaping Element) -> Bool {
        if case .enqueued = continuation.yield(job) {
            return true
        } else {
            return false
        }
    }
    
    func finish() {
        continuation.finish()
    }
    
}
