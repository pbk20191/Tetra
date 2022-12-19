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
    func mapTask<T:Sendable>(transform: @escaping @Sendable (Output) async -> T) -> Publishers.MapTask<Self,T> where Output:Sendable {
        Publishers.MapTask(upstream: self, transform: transform)
    }
    
    @inlinable
    func tryMapTask<T:Sendable>(transform: @escaping @Sendable (Output) async throws -> T) -> Publishers.TryMapTask<Self,T> where Output:Sendable {
        Publishers.TryMapTask(upstream: self, transform: transform)
    }
    
    @available(iOS, deprecated: 15.0, renamed: "values")
    @available(macCatalyst, deprecated: 15.0, renamed: "values")
    @available(tvOS, deprecated: 15.0, renamed: "values")
    @available(macOS, deprecated: 12.0, renamed: "values")
    @available(watchOS, deprecated: 8.0, renamed: "values")
    var sequence:AnyAsyncTypeSequence<Output> {
        if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
            return AnyAsyncTypeSequence(base: values)
        } else {
            return AnyAsyncTypeSequence(base: CompatAsyncThrowingPublisher(publisher: self))
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


extension Publishers {

    /**
     
        underlying task will receive task cancellation signal if the subscription is cancelled
     
     */
    public struct MapTask<Upstream:Publisher, Output:Sendable>: Publisher where Upstream.Output:Sendable {

        public typealias Output = Output
        public typealias Failure = Upstream.Failure

        public let upstream:Upstream
        public let transform:@Sendable (Upstream.Output) async -> Output

        public init(upstream: Upstream, transform: @escaping @Sendable (Upstream.Output) async -> Output) {
            self.upstream = upstream
            self.transform = transform
        }

        public func receive<S>(subscriber: S) where S : Subscriber, Upstream.Failure == S.Failure, Output == S.Input {
            upstream.flatMap(maxPublishers: .max(1)) { input in
                let task = Task { await transform(input) }
                return Future<Output,Failure>{ promise in
                    Task { await promise(.success(task.value)) }
                }.handleEvents(receiveCancel: task.cancel)
            }
            .subscribe(subscriber)
            
        }
        
    }
    
    /**
     
        underlying task will receive task cancellation signal if the subscription is cancelled
     
     */
    public struct TryMapTask<Upstream:Publisher, Output:Sendable>: Publisher where Upstream.Output:Sendable {

        public typealias Output = Output
        public typealias Failure = Error

        public let upstream:Upstream
        public let transform:@Sendable (Upstream.Output) async throws -> Output

        public init(upstream: Upstream, transform: @escaping @Sendable (Upstream.Output) async throws -> Output) {
            self.upstream = upstream
            self.transform = transform
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            upstream.mapError{ $0 as any Error }.flatMap(maxPublishers: .max(1)) { input in
                let task = Task { try await transform(input) }
                return Future<Output,Error> { promise in
                    Task.detached { await promise(task.result) }
                }
                .handleEvents(receiveCancel: task.cancel)
            }
            .subscribe(subscriber)
            
        }

    }

}
extension Publishers.MapTask: Sendable where Upstream: Sendable {}
extension Publishers.TryMapTask: Sendable where Upstream: Sendable {}


extension Combine.Future where Failure == Never {
    
    @available(iOS, deprecated: 15.0, renamed: "value")
    @available(iOS, deprecated: 15.0, renamed: "value")
    @available(iOS, deprecated: 15.0, renamed: "value")
    @available(watchOS, deprecated: 8, renamed: "value")
    @available(macOS, deprecated: 12.0, renamed: "value")
    final var compatValue: Output {
        get async {
            if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
                return await value
            } else {
                return await withCheckedContinuation{ continuation in
                    self.subscribe(AnySubscriber(
                        receiveSubscription: {
                            $0.request(.max(1))
                        },
                        receiveValue: {
                            continuation.resume(returning: $0)
                            return .none
                        },
                        receiveCompletion: { completion in
                            if case let .failure(failure) = completion {
                                continuation.resume(throwing: failure)
                            }
                        }
                    ))
                }
            }
        }
    }
    
}


extension Combine.Future {
    
    @available(iOS, deprecated: 15.0, renamed: "value")
    @available(iOS, deprecated: 15.0, renamed: "value")
    @available(iOS, deprecated: 15.0, renamed: "value")
    @available(watchOS, deprecated: 8, renamed: "value")
    @available(macOS, deprecated: 12.0, renamed: "value")
    final var compatValue: Output {
        get async throws {
            if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
                return try await value
            } else {
                return try await withCheckedThrowingContinuation{ continuation in
                    self.subscribe(AnySubscriber(
                        receiveSubscription: {
                            $0.request(.max(1))
                        },
                        receiveValue: {
                            continuation.resume(returning: $0)
                            return .none
                        },
                        receiveCompletion: {
                            if case let .failure(error) = $0 {
                                continuation.resume(throwing: error)
                            }
                        }
                    ))
                }
            }
        }
    }
    
}

//extension Publishers.MapTask {
//
//    private final class Inner<Downstream: Subscriber>
//        : Subscriber,
//          Subscription,
//          CustomStringConvertible,
//          CustomReflectable,
//          CustomPlaygroundDisplayConvertible
//    where Downstream.Input == Output, Downstream.Failure == Upstream.Failure, Output: Sendable, Downstream.Input : Sendable
//    {
//        // NOTE: This class has been audited for thread-safety
//        typealias Input = Upstream.Output
//
//        typealias Failure = Upstream.Failure
//
//        private let downstream: Downstream
//
//        private let mapTask: @Sendable (Input) async -> Output
//
//        private var status = SubscriptionStatus.awaitingSubscription
//        private var tasks:Set<Task<Void,Never>> = []
//        private let lock = NSLock()
//        private var closed = false
//
//        fileprivate init(downstream: Downstream,
//                         mapTask: @Sendable @escaping (Input) async -> Output) {
//            self.downstream = downstream
//            self.mapTask = mapTask
//        }
//
//
//        func receive(subscription: Subscription) {
//            let canPerfom = lock.withLock {
//                guard case .awaitingSubscription = status else {
//                    return false
//                }
//                status = .subscribed(subscription)
//                return true
//            }
//            guard canPerfom else {
//                subscription.cancel()
//                return
//            }
//            downstream.receive(subscription: self)
//        }
//
//        nonisolated
//        func receive(_ input: Input) -> Subscribers.Demand {
//            let newTask = Task {
//                let hash = withUnsafeCurrentTask { $0?.hashValue ?? 0}
//                Swift.print(DispatchTime.now(), hash, "start")
//                let value = await mapTask(input)
//                Swift.print(DispatchTime.now(), hash, "end")
//                guard !Task.isCancelled else { return }
//                let demand = downstream.receive(value)
//                let subscriptionState = lock.withLock { status }
//                if case let .subscribed(subscription) = subscriptionState, demand > .none {
//                    subscription.request(demand)
//                }
//            }
//            lock.withLock {
//                tasks.insert(newTask)
//                return
//            }
//            return .none
//        }
//
//        func receive(completion: Subscribers.Completion<Failure>) {
//            let canPerfom = lock.withLock {
//                guard case .subscribed = status, !closed else {
//                    return false
//                }
//                closed = true
//                return true
//            }
//            if canPerfom {
//                let task = Task {
//                    let taskSnapShot = lock.withLock{ tasks }
//                    await withTaskGroup(of: Void.self) { group in
//                        taskSnapShot.forEach{ task in
//                            group.addTask {
//                                await withTaskCancellationHandler {
//                                    await task.value
//                                } onCancel: {
//                                    task.cancel()
//                                }
//
//                            }
//                        }
//                        for await _ in group {}
//                    }
//                    guard !Task.isCancelled else { return }
//                    downstream.receive(completion: completion)
//                }
//                lock.withLock {
//                    tasks.insert(task)
//                    return
//                }
//            }
//        }
//
//        func request(_ demand: Subscribers.Demand) {
//            lock.withLock {
//                status.subscription
//            }?.request(demand)
//        }
//
//        func cancel() {
//            let (pendingTasks, subscription) = lock.withLock {
//                let copied = (tasks, status.subscription)
//                status = .terminal
//                tasks = []
//                return copied
//            }
//            subscription?.cancel()
//            pendingTasks.forEach{ $0.cancel() }
//        }
//
//        var description: String { return "MapTask" }
//
//        var customMirror: Mirror {
//            return Mirror(self, children: EmptyCollection(), displayStyle: .class)
//        }
//
//        var playgroundDescription: Any { return description }
//    }
//}
//
//
//extension Publishers.TryMapTask {
//
//    private final class Inner<Downstream: Subscriber>
//        : Subscriber,
//          Subscription,
//          CustomStringConvertible,
//          CustomReflectable,
//          CustomPlaygroundDisplayConvertible
//    where Downstream.Input == Output, Downstream.Failure == Error, Output: Sendable, Downstream.Input : Sendable
//    {
//        // NOTE: This class has been audited for thread-safety
//        typealias Input = Upstream.Output
//
//        typealias Failure = Upstream.Failure
//
//        private let downstream: Downstream
//
//        private let tryMapTask: @Sendable (Input) async throws -> Output
//
//        private var status = SubscriptionStatus.awaitingSubscription
//        private var tasks:Set<Task<Void,Never>> = []
//        private let lock = NSLock()
//
//        fileprivate init(downstream: Downstream,
//                         tryMapTask: @Sendable @escaping (Input) async throws -> Output) {
//            self.downstream = downstream
//            self.tryMapTask = tryMapTask
//        }
//
//
//        func receive(subscription: Subscription) {
//            let canPerfom = lock.withLock {
//                guard case .awaitingSubscription = status else {
//                    return false
//                }
//                status = .subscribed(subscription)
//                return true
//            }
//            guard canPerfom else {
//                subscription.cancel()
//                return
//            }
//            downstream.receive(subscription: self)
//        }
//
//        nonisolated
//        func receive(_ input: Input) -> Subscribers.Demand {
//            let newTask = Task {
//                do {
//                    let value = try await tryMapTask(input)
//                    guard !Task.isCancelled else { return }
//                    let subscriptionState = lock.withLock { status }
//
//                    if case let .subscribed(subscription) = subscriptionState {
//                        subscription.request(downstream.receive(value))
//                    }
//                } catch {
//                    lock.withLock {
//                        let state = status.subscription
//                        status = .terminal
//                        return state
//                    }?.cancel()
//                    downstream.receive(completion: .failure(error))
//                }
//            }
//            lock.withLock {
//                tasks.insert(newTask)
//                return
//            }
//            return .none
//        }
//
//        func receive(completion: Subscribers.Completion<Failure>) {
//            let canPerfom = lock.withLock {
//                guard case .subscribed = status else {
//                    return false
//                }
//                status = .terminal
//                return true
//            }
//            if canPerfom {
//                switch completion {
//                case .finished:
//                    downstream.receive(completion: .finished)
//                case .failure(let failure):
//                    downstream.receive(completion: .failure(failure))
//                }
//            }
//        }
//
//        func request(_ demand: Subscribers.Demand) {
//            lock.withLock {
//                status.subscription
//            }?.request(demand)
//        }
//
//        func cancel() {
//            let (pendingTasks, subscription) = lock.withLock {
//                let copied = (tasks, status.subscription)
//                status = .terminal
//                tasks = []
//                return copied
//            }
//            subscription?.cancel()
//            pendingTasks.forEach{ $0.cancel() }
//        }
//
//        var description: String { return "TryMapTask" }
//
//        var customMirror: Mirror {
//            return Mirror(self, children: EmptyCollection(), displayStyle: .class)
//        }
//
//        var playgroundDescription: Any { return description }
//    }
//
//}
