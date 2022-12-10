//
//  URLSession+asyc.swift
//
//
//  Created by pbk on 2022/05/24.
//
import Foundation


@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
public extension URLSessionWebSocketTask {
    
    func sendPing() async throws {
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

}



