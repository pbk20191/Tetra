//
//  Combine+Concurrency.swift
//  
//
//  Created by pbk on 2022/09/06.
//

import Foundation
import Combine

public extension Publisher {
    
    @available(iOS, deprecated: 15.0, renamed: "values")
    @available(macCatalyst, deprecated: 15.0, renamed: "values")
    @available(tvOS, deprecated: 15.0, renamed: "values")
    @available(macOS, deprecated: 12.0, renamed: "values")
    @available(watchOS, deprecated: 8.0, renamed: "values")
    var asyncStream: AsyncThrowingStream<Output,Error> {
        if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 15.0, *) {
            var iterator = values.makeAsyncIterator()
            return AsyncThrowingStream<Output,Error> {
                try Task.checkCancellation()
                return try await iterator.next()
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
            var iterator = values.makeAsyncIterator()
            return AsyncStream<Output> {
                guard !Task.isCancelled else { return nil }
                return await iterator.next()
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
