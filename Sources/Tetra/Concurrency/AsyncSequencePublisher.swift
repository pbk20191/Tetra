//
//  AsyncSequencePublisher.swift
//  
//
//  Created by pbk on 2022/09/16.
//

import Foundation
import Combine

public extension AsyncSequence {
    
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
                    lock.withLock{
                        $0 = nil
                    }
                    buffer.append(element: .none)
                }

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
            let semaphore = DispatchSemaphore(value: 1)
            let reference = UnsafeMutablePointer<Base.AsyncIterator>.allocate(capacity: 1)
            defer { reference.deallocate() }
            reference.initialize(to: base.makeAsyncIterator())
            defer { reference.deinitialize(count: 1) }

            try? await withThrowingTaskGroup(of: Void.self) { group in
                for await demand in demandBuffer {
                    group.addTask {
                        try await received(demand, lock: lock, semaphore: semaphore, reference: reference)
                    }
                    do {
                        async let _ = try await group.next()
                    } catch let error as FinishError {
                        throw error
                    } catch {
                        lock.withLockUnchecked{
                            let oldValue = $0
                            $0 = nil
                            return oldValue
                        }?.receive(completion: .failure(error))
                        throw error
                    }
                }
            }
        }
        
        @usableFromInline
        static internal func received(
            _ demand:Subscribers.Demand,
            lock: some UnfairStateLock<Optional<S>>,
            semaphore:DispatchSemaphore,
            reference:UnsafeMutablePointer<Base.AsyncIterator>
        ) async throws {
            var pending = demand
            while pending > .none {
                if let value = try await iterate(reference: reference, semaphore: semaphore) {
                    pending -= 1
                    let subscriber = lock.withLockUnchecked{ $0 }
                    if let subscriber {
                        pending += subscriber.receive(value)
                    }
                } else {
                    lock.withLockUnchecked{
                        let oldValue = $0
                        $0 = nil
                        return oldValue
                    }?.receive(completion: .finished)
                    throw FinishError()
                }
            }
        }
        
    }
    

    
    @usableFromInline
    static internal func iterate(
        reference:UnsafeMutablePointer<Base.AsyncIterator>, semaphore:DispatchSemaphore
    ) async rethrows -> Base.Element? {
        await withUnsafeContinuation{
            semaphore.wait()
            $0.resume()
        }
        defer { semaphore.signal() }
        return try await reference.pointee.next()
    }

    private struct FinishError: Error, Sendable, Hashable {}

}
