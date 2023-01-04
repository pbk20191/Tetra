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
        AsyncIterator(base: self)
    }
    
    @usableFromInline
    typealias Element = Subscribers.Demand
    @usableFromInline
    typealias AsyncIterator = Iterator
    
    private let lock: some UnfairStateLock<DemandState> = createCheckedStateLock(checkedState: DemandState())
    
    @usableFromInline
    struct Iterator: AsyncIteratorProtocol, Sendable {
        
        let base:DemandAsyncBuffer
        
        @usableFromInline
        func next() async -> Element? {
            await withTaskCancellationHandler {
                return await withUnsafeContinuation { continuation in
                    let snapShot = base.lock.withLock {
                        let oldValue = $0
                        Swift.precondition(oldValue.pending == nil)
                        if !$0.isClosed {
                            if $0.demand == nil {
                                $0.pending = continuation
                            } else {
                                $0.demand = nil
                            }
                        }
                        return oldValue
                    }
                    if snapShot.isClosed {
                        continuation.resume(returning: nil)
                    } else if let demand = snapShot.demand {
                        continuation.resume(returning: demand)
                    }
                }
            } onCancel: {
                base.close()
            }
        }
        
    }
    
    func close() {
        lock.withLock {
            let oldValue = $0.pending
            $0.pending = nil
            $0.isClosed = true
            $0.demand = nil
            return oldValue
        }?.resume(returning: nil)
    }
    
    struct DemandState {
        
        var demand:Subscribers.Demand? = nil
        var pending:UnsafeContinuation<Element?,Never>? = nil
        var isClosed = false
        
    }
    
    func append(element: __owned Element) {
        let snapShot = lock.withLock { state in
            let oldValue = state
            if oldValue.pending != nil {
                state.pending = nil
            } else if !state.isClosed {
                let oldDemand = state.demand ?? .none
                state.demand = oldDemand + element
            }
            return oldValue
        }
        snapShot.pending?.resume(returning: element)
    }
    

    

}
