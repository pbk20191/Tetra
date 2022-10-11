//
//  File.swift
//  
//
//  Created by pbk on 2022/05/24.
//

import Foundation
import AsyncAlgorithms
import Atomics


public extension URLSession {
    
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
            let taskSetup = { () -> (Task<DownloadURLMarker,Error>,URLSessionDownloadTask) in
                @preconcurrency
                let store = NSMutableArray()
                let lock = DispatchSemaphore(value: 0)
                let task2 = Task {
                    let marker:DownloadURLMarker = try await withCheckedThrowingContinuation { continuation in
                        let urlTask = self.downloadTask(with: request) { url, response, error in
                            guard let url, let response else {
                                return continuation.resume(throwing: error ?? URLError(.badServerResponse))
                            }
                            do {
                                let marker = DownloadURLMarker(
                                    target: url,
                                    temporal: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp", isDirectory: false),
                                    response: response
                                )
                                try FileManager.default.moveItem(at: marker.target, to: marker.temporal)
                                continuation.resume(returning: marker)
                            } catch{
                                continuation.resume(throwing: error)
                            }
                        }
                        store.add(urlTask)
                        lock.signal()
                    }
                    return marker
                }
                lock.wait()
                let urlTask = store.firstObject.unsafelyUnwrapped as! URLSessionDownloadTask
                return (task2, urlTask)
            }
            let (job, sessionTask) = taskSetup()
            if Task.isCancelled {
                sessionTask.cancel()
            }
            sessionTask.resume()
            return try await withTaskCancellationHandler {
                sessionTask.cancel()
                job.cancel()
            } operation: {
                let marker = try await job.value
                try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                return (marker.target, marker.response)
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
            return try await download(resumeFrom: data, delegate: nil)
        } else {
            let taskSetup = { () -> (Task<DownloadURLMarker,Error>,URLSessionDownloadTask) in
                @preconcurrency
                let store = NSMutableArray()
                let lock = DispatchSemaphore(value: 0)
                let task2 = Task {
                    let marker:DownloadURLMarker = try await withCheckedThrowingContinuation { continuation in
                        let urlTask = self.downloadTask(withResumeData: data) { url, response, error in
                            guard let url, let response else {
                                return continuation.resume(throwing: error ?? URLError(.badServerResponse))
                            }
                            do {
                                let marker = DownloadURLMarker(
                                    target: url,
                                    temporal: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp", isDirectory: false),
                                    response: response
                                )
                                try FileManager.default.moveItem(at: marker.target, to: marker.temporal)
                                continuation.resume(returning: marker)
                            } catch{
                                continuation.resume(throwing: error)
                            }
                        }
                        store.add(urlTask)
                        lock.signal()
                    }
                    return marker
                }
                lock.wait()
                let urlTask = store.firstObject.unsafelyUnwrapped as! URLSessionDownloadTask
                return (task2, urlTask)
            }
            let (job, sessionTask) = taskSetup()
            if Task.isCancelled {
                sessionTask.cancel()
            }
            sessionTask.resume()
            return try await withTaskCancellationHandler {
                sessionTask.cancel()
                job.cancel()
            } operation: {
                let marker = try await job.value
                try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                return (marker.target, marker.response)
            }
        }
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



