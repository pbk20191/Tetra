//
//  AsyncSequencePublisher.swift
//  
//
//  Created by pbk on 2022/09/16.
//

import Foundation
import Combine

public extension AsyncSequence {
    
    @inlinable
    var asyncPublisher:AsyncSequencePublisher<Self> {
        .init(base: self)
    }
    
}

public struct AsyncSequencePublisher<Base:AsyncSequence>: Publisher {

    public typealias Output = Base.Element
    public typealias Failure = Error
    
    public var base:Base
    
    @inlinable
    public init(base: Base) {
        self.base = base
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Base.Element == S.Input {
        subscriber.receive(subscription: Inner(base: base, subscriber: subscriber))
    }
    
}

extension AsyncSequencePublisher: Sendable where Base: Sendable, Base.Element: Sendable {}

extension AsyncSequencePublisher {

    private final class Inner<S:Subscriber>: Subscription, CustomStringConvertible, CustomPlaygroundDisplayConvertible, Sendable where S.Input == Output, S.Failure == Failure {
        
        var description: String { "AsyncSequence" }
        
        var playgroundDescription: Any { description }
        
        private let task:Task<Void,Never>
        private let demandBuffer = DemandAsyncBuffer()
        
        internal init(base: Base, subscriber:S) {
            let lock = createUncheckedStateLock(uncheckedState: Optional<S>.some(subscriber))
            let buffer = demandBuffer
            self.task = Task {
                await withTaskCancellationHandler {
                    await Self.subscribe(lock: lock, demandBuffer: buffer, base: base)
                } onCancel: {
                    lock.withLock{ $0 = nil }
                }
                buffer.close()
            }
        }

        func request(_ demand: Subscribers.Demand) {
            demandBuffer.append(element: demand)
        }
        
        func cancel() {
            task.cancel()
        }
        
        deinit { task.cancel() }
        
        @usableFromInline
        static func subscribe(
            lock: some UnfairStateLock<Optional<S>>, demandBuffer: DemandAsyncBuffer, base:Base
        ) async {
            var iterator = base.makeAsyncIterator()
            do {
            completionLabel:
                for await demand in demandBuffer {
                    var pending = demand
                    while pending > .none {
                        if let value = try await iterator.next() {
                            pending -= 1
                            if let subscriber = lock.withLockUnchecked({ $0 }) {
                                pending += subscriber.receive(value)
                            } else {
                                break completionLabel
                            }
                        } else {
                            break completionLabel
                        }
                    }
                }
                if !Task.isCancelled {
                    lock.withLockUnchecked{
                        let oldValue = $0
                        $0 = nil
                        return oldValue
                    }?.receive(completion: .finished)
                }
            } catch {
                lock.withLockUnchecked{
                    let oldValue = $0
                    $0 = nil
                    return oldValue
                }?.receive(completion: .failure(error))
            }
        }
    }
    
}
