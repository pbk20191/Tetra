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
    func makeAsyncIterator() -> Iterator {
        .init(base: self)
    }
    
    @usableFromInline
    typealias Element = @Sendable () async throws -> ()
    @usableFromInline
    typealias AsyncIterator = Iterator
    
    private struct JobState: Sendable {
        var queue:[Element] = []
        var pending:UnsafeContinuation<Element?,Never>? = nil
        var isClosed = false
    }
    
    private let lock = createCheckedStateLock(checkedState: JobState())
    
    @usableFromInline
    struct Iterator: AsyncIteratorProtocol, Sendable {
        
        let base:JobSequence
        
        @usableFromInline
        func next() async -> Element? {
            await withTaskCancellationHandler {
                return await withUnsafeContinuation { continuation in
                    let snapShot = base.lock.withLock {
                        let oldValue = $0
                        precondition(oldValue.pending == nil)
                        if !$0.isClosed {
                            if $0.queue.isEmpty {
                                $0.pending = continuation
                            } else {
                                $0.queue.removeFirst()
                            }
                        }
                        return oldValue
                    }
                    if snapShot.isClosed {
                        continuation.resume(returning: nil)
                    } else if let first = snapShot.queue.first {
                        continuation.resume(returning: first)
                    }
                    
                }
            } onCancel: {
                base.lock.withLock {
                    let oldValue = $0.pending
                    $0.pending = nil
                    $0.isClosed = true
                    return oldValue
                }?.resume(returning: nil)
            }
            
        }
        
    }
    
    func append(job: __owned @escaping Element) -> Bool {
        let snapShot = lock.withLock { state in
            let oldValue = state
            if oldValue.pending != nil {
                state.pending = nil
            } else if !state.isClosed {
                state.queue.append(job)
            }
            return oldValue
        }
        snapShot.pending?.resume(returning: job)
        return !snapShot.isClosed
    }
    

    
    func popBuffered() -> [Element] {
        lock.withLock {
            let captured = $0.queue
            $0.queue.removeAll()
            return captured
        }
    }
    
}
