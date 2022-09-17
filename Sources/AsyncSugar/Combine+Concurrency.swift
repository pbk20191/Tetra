//
//  Combine+Concurrency.swift
//  
//
//  Created by pbk on 2022/09/06.
//

import Foundation
import Combine

public extension Publisher {
    
    func mapTask<T:Sendable>(maxTaskCount:Subscribers.Demand = .max(1), transform: @escaping @Sendable (Output) async -> T) -> AnyPublisher<T,Never> where Failure == Never, Output:Sendable {
        map{ output in
            Task {
                await withTaskCancellationHandler {
                    Swift.print("\(#function) taskCancel")
                } operation: {
                    await transform(output)
                }
            }
            
        }
        .flatMap(maxPublishers: maxTaskCount){ task in
            Future<T,Never> { promise in
                Task { await promise(task.result) }
            }
            .handleEvents(receiveCancel: task.cancel)
        }
        .eraseToAnyPublisher()
    }
    
    func tryMapTask<T:Sendable>(maxTaskCount:Subscribers.Demand = .max(1), transform: @escaping @Sendable (Output) async throws -> T) -> AnyPublisher<T,Error> where Output:Sendable {
        mapError{ $0 }
            .map{ output in
                Task {
                    try await withTaskCancellationHandler {
                        Swift.print("\(#function) taskCancel")
                    } operation: {
                        try await transform(output)
                    }
                }
            }
            .flatMap(maxPublishers: maxTaskCount){ task in
                Future<T,Error> { promise in
                    Task { await promise(task.result) }
                }
                .handleEvents(receiveCancel: task.cancel)
            }
            .eraseToAnyPublisher()
    }
    
    
    @available(iOS, deprecated: 15.0, renamed: "values")
    @available(macCatalyst, deprecated: 15.0, renamed: "values")
    @available(tvOS, deprecated: 15.0, renamed: "values")
    @available(macOS, deprecated: 12.0, renamed: "values")
    @available(watchOS, deprecated: 8.0, renamed: "values")
    var asyncStream: AsyncThrowingStream<Output,Error> {
        if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 15.0, *) {
            return AsyncThrowingStream<Output,Error>{[source = values] continuation in
                let task = Task {
                    do {
                        for try await i in source {
                            continuation.yield(i)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { @Sendable _ in task.cancel() }
            }
        } else {
            return AsyncThrowingStream<Output, Error> { continuation in
                var cancellable: AnyCancellable?
                let onTermination = { cancellable?.cancel() }

                continuation.onTermination = { @Sendable _ in
                    onTermination()
                }

                cancellable = sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            continuation.finish()
                        case .failure(let error):
                            continuation.finish(throwing: error)
                        }
                    }, receiveValue: { value in
                        continuation.yield(value)
                    }
                )
            }

        }
    }
}


public extension Publisher where Failure == Never {
    
    @available(iOS, deprecated: 15.0, renamed: "values")
    @available(macCatalyst, deprecated: 15.0, renamed: "values")
    @available(tvOS, deprecated: 15.0, renamed: "values")
    @available(macOS, deprecated: 12.0, renamed: "values")
    @available(watchOS, deprecated: 8.0, renamed: "values")
    var asyncStream:AsyncStream<Output> {
        if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *) {
           return AsyncStream(Output.self) { [source = values] continutation in
                let task = Task {
                    for await i in source {
                        continutation.yield(i)
                    }
                    continutation.finish()
                }
                continutation.onTermination = { @Sendable _ in task.cancel() }
            }
        } else {
            return AsyncStream<Output> { continuation in
                var cancellable: AnyCancellable?
                let onTermination = { cancellable?.cancel() }
                continuation.onTermination = { @Sendable _ in
                    onTermination()
                }
                cancellable = sink(
                    receiveCompletion: { _ in
                        continuation.finish()
                    }, receiveValue: { value in
                        continuation.yield(value)
                    }
                )
            }
        }
    }
}
