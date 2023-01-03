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
                SingleTaskPublisher<Output>{ await transform(input) }
                    .setFailureType(to: Failure.self)
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
                SingleThrowingTaskPublisher{ try await transform(input) }
            }
            .subscribe(subscriber)
            
        }

    }

}

extension Publishers.MapTask: Sendable where Upstream: Sendable {}
extension Publishers.TryMapTask: Sendable where Upstream: Sendable {}
