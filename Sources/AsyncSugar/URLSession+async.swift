//
//  File.swift
//  
//
//  Created by pbk on 2022/05/24.
//

import Foundation
import AsyncAlgorithms

//@available(iOS, introduced: 13.0, obsoleted: 15.0)
//@available(tvOS, introduced: 13.0, obsoleted: 15.0)
//@available(macCatalyst, introduced: 13.0, obsoleted: 15.0)
//@available(macOS, introduced: 10.15, obsoleted: 12.0)
//@available(watchOS, introduced: 6.0, obsoleted: 8.0)
public extension URLSession {
//    /// Start a data task with a URL using async/await.
//    /// - parameter url: The URL to send a request to.
//    /// - returns: A tuple containing the binary `Data` that was downloaded,
//    ///   as well as a `URLResponse` representing the server's response.
//    /// - throws: Any error encountered while performing the data task.
//    @available(iOS, deprecated: 15, message: "Use `data(from:delegate:)` instead", renamed: "data(from:)")
//    @available(tvOS, deprecated: 15, message: "Use `data(from:delegate:)` instead", renamed: "data(from:)")
//    @available(macCatalyst, deprecated: 15, message: "Use `data(from:delegate:)` instead", renamed: "data(from:)")
//    @available(macOS, deprecated: 12, message: "Use `data(from:delegate:)` instead", renamed: "data(from:)")
//    @available(watchOS, deprecated: 8, message: "Use `data(from:delegate:)` instead", renamed: "data(from:)")
//    nonisolated
//    func data(in url: URL) async throws -> (Data, URLResponse) {
//        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
//            return try await data(from: url)
//        } else {
//            return try await data(with: URLRequest(url: url))
//        }
//    }
//
//    /// Start a data task with a `URLRequest` using async/await.
//    /// - parameter request: The `URLRequest` that the data task should perform.
//    /// - returns: A tuple containing the binary `Data` that was downloaded,
//    ///   as well as a `URLResponse` representing the server's response.
//    /// - throws: Any error encountered while performing the data task.
//    @available(iOS, deprecated: 15, message: "Use `data(for:delegate:)` instead", renamed: "data(for:)")
//    @available(tvOS, deprecated: 15, message: "Use `data(for:delegate:)` instead", renamed: "data(for:)")
//    @available(macCatalyst, deprecated: 15, message: "Use `data(for:delegate:)` instead", renamed: "data(for:)")
//    @available(macOS, deprecated: 12, message: "Use `data(for:delegate:)` instead", renamed: "data(for:)")
//    @available(watchOS, deprecated: 8, message: "Use `data(for:delegate:)` instead", renamed: "data(for:)")
//    nonisolated
//    func data(with request: URLRequest) async throws -> (Data, URLResponse) {
//        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
//            return try await data(for: request)
//        } else {
//            let stream = AsyncThrowingStream((Data, URLResponse).self) { continuation in
//                let task = dataTask(with: request) { data, response, error in
//                    guard let data, let response else {
//                        return continuation.finish(throwing: error)
//                    }
//                    continuation.yield((data, response))
//                    continuation.finish()
//                }
//                continuation.onTermination = { @Sendable _ in task.cancel() }
//                task.resume()
//            }
////            CocoaError.error(.)
//            if let item = try await stream.first(where: { _ in true }) {
//                return item
//            } else {
//                let info = ([
//                    NSURLErrorFailingURLErrorKey: request.url,
//                    NSURLErrorFailingURLStringErrorKey: request.url?.absoluteString,
//                    NSLocalizedDescriptionKey: "Completion failure"
//                ] as [String:Any?]).compactMapValues{ $0 }
//                throw URLError(.badServerResponse, userInfo: info)
//            }
//        }
//    }
    
    /// Convenience method to download using an URL, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter url: The URL for which to download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(iOS, deprecated: 15, message: "Use `download(from:delegate:)` instead", renamed: "download(from:)")
    @available(tvOS, deprecated: 15, message: "Use `download(from:delegate:)` instead", renamed: "download(from:)")
    @available(macCatalyst, deprecated: 15, message: "Use `download(from:delegate:)` instead", renamed: "download(from:)")
    @available(macOS, deprecated: 12, message: "Use `download(from:delegate:)` instead", renamed: "download(from:)")
    @available(watchOS, deprecated: 8, message: "Use `download(from:delegate:)` instead", renamed: "download(from:)")
    nonisolated
    func download(for url: URL) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(from: url, delegate: nil)
        } else {
            return try await download(from: .init(url: url))
        }
    }
    
    /// Convenience method to download using an URLRequest, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(iOS, deprecated: 15, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @available(tvOS, deprecated: 15, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @available(macCatalyst, deprecated: 15, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @available(macOS, deprecated: 12, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @available(watchOS, deprecated: 8, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    nonisolated
    func download(from request: URLRequest) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(for: request, delegate: nil)
        } else {
            let stream = AsyncThrowingStream(DownloadURLMarker.self) { continuation in
                let task = downloadTask(with: request) { url, response, error in
                    guard let url, let response else {
                        return continuation.finish(throwing: error)
                    }
                    do {
                        let marker = DownloadURLMarker(
                            target: url,
                            temporal: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp", isDirectory: false),
                            response: response
                        )
                        try FileManager.default.moveItem(at: marker.target, to: marker.temporal)
                        continuation.yield(marker)
                        continuation.finish()
                    } catch{
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { @Sendable _ in task.cancel() }
                task.resume()
            }.map { marker in
                try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                return (marker.target, marker.response)
            }
            if let item = try await stream.first(where: { _ in true }) {
                return item
            } else {
                let info = ([
                    NSURLErrorFailingURLErrorKey: request.url,
                    NSURLErrorFailingURLStringErrorKey: request.url?.absoluteString,
                    NSLocalizedDescriptionKey: "Completion failure"
                ] as [String:Any?]).compactMapValues{ $0 }
                throw URLError(.badServerResponse, userInfo: info)

            }
        }
    }
    
    @available(iOS, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(tvOS, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(macCatalyst, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(macOS, deprecated: 12, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(watchOS, deprecated: 8, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    nonisolated
    func download(resumeWith data: Data) async throws -> (URL,URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(resumeFrom: data)
        } else {
            let stream = AsyncThrowingStream(DownloadURLMarker.self) { continuation in
                let task = downloadTask(withResumeData: data) { url, response, error in
                    guard let url, let response else {
                        return continuation.finish(throwing: error)
                    }
                    do {
                        let marker = DownloadURLMarker(
                            target: url,
                            temporal: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp", isDirectory: false),
                            response: response
                        )
                        try FileManager.default.moveItem(at: marker.target, to: marker.temporal)
                        continuation.yield(marker)
                        continuation.finish()
                    } catch{
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { @Sendable _ in task.cancel() }
                task.resume()
            }.map { marker in
                try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                return (marker.target, marker.response)
            }
            if let item = try await stream.first(where: { _ in true }) {
                return item
            } else {
                let info = ([
                    NSLocalizedDescriptionKey: "Completion failure"
                ] as [String:Any?]).compactMapValues{ $0 }
                throw URLError(.badServerResponse, userInfo: info)

            }
        }
    }
    
    internal func asdsdfs(request:URLRequest) async throws {
        let streamTask = streamTask(withHostName: "localhost", port: 8080)
        let _:Void = try await withTaskCancellationHandler {
            streamTask.cancel()
        } operation: {
            let (data1, flag1) = try await streamTask.readData(ofMinLength: 0, maxLength: 100, timeout: 100)
            
        }

        let socketTask = webSocketTask(with: request)
        let message = try await socketTask.receive()


    }
}



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
        let stream = AsyncThrowingStream.init(Void.self) { continuation in
            continuation.onTermination = { @Sendable _ in
                continuation.finish(throwing: CancellationError())
            }
            sendPing { continuation.finish(throwing: $0) }
        }
        try await stream.first{ true }
        try Task.checkCancellation()
    }
}

fileprivate struct DownloadURLMarker: Sendable, Hashable {
    let target:URL
    let temporal:URL
    let response:URLResponse
}



