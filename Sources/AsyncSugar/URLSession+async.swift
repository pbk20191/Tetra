//
//  URLSession+asyc.swift
//
//
//  Created by pbk on 2022/05/24.
//
import Foundation


@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
public extension URLSessionWebSocketTask {
    
    nonisolated
    func sendPingAndWait() async throws {
        return try await withUnsafeThrowingContinuation{ continuation in
            sendPing { error in
                if let error {
                    continuation.resume(with: .failure(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    nonisolated
    func ping() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.sendPingAndWait()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: .max)
            }
            for try await _ in group {
                return
            }
            throw CancellationError()
        }
    }
    
}



