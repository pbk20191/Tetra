//
//  URLSession+asyc.swift
//  
//
//  Created by pbk on 2022/05/24.
//

import Foundation

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
    func download(for url: URL) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(from: url)
        } else {
            let sema = DispatchSemaphore(value: 0)
            let reference = UnsafeReference<URLSessionDownloadTask>()
            let underlyingTask = Task {
                let marker:DownloadURLMarker = try await withCheckedThrowingContinuation { continuation in
                    let sessionTask = self.downloadTask(with: url) { url, response, error in
                        do {
                            guard let url, let response else {
                                throw (error ?? URLError(.badServerResponse))
                            }
                            let marker = DownloadURLMarker(
                                target: url,
                                temporal: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp", isDirectory: false),
                                response: response
                            )
                            try FileManager.default.moveItem(at: marker.target, to: marker.temporal)
                            continuation.resume(returning: marker)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    reference.value = sessionTask
                    sema.signal()
                }
                try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                return (marker.target, marker.response)
            }
            let downloadTask = await withUnsafeContinuation { continuation in
                sema.wait()
                continuation.resume(returning: reference.value.unsafelyUnwrapped)
            }
            downloadTask.resume()
            if Task.isCancelled {
                downloadTask.cancel()
            }
            return try await withTaskCancellationHandler {
                try await underlyingTask.value
            } onCancel: {
                downloadTask.cancel()
            }
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
    func download(from request: URLRequest) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(for: request)
        } else {
            let sema = DispatchSemaphore(value: 0)
            let reference = UnsafeReference<URLSessionDownloadTask>()
            let underlyingTask = Task {
                let marker:DownloadURLMarker = try await withCheckedThrowingContinuation { continuation in
                    let sessionTask = self.downloadTask(with: request) { url, response, error in
                        do {
                            guard let url, let response else {
                                throw (error ?? URLError(.badServerResponse))
                            }
                            let marker = DownloadURLMarker(
                                target: url,
                                temporal: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp", isDirectory: false),
                                response: response
                            )
                            try FileManager.default.moveItem(at: marker.target, to: marker.temporal)
                            continuation.resume(returning: marker)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    reference.value = sessionTask
                    sema.signal()
                }
                try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                return (marker.target, marker.response)
            }
            let downloadTask = await withUnsafeContinuation { continuation in
                sema.wait()
                continuation.resume(returning: reference.value.unsafelyUnwrapped)
            }
            downloadTask.resume()
            if Task.isCancelled {
                downloadTask.cancel()
            }
            return try await withTaskCancellationHandler {
                try await underlyingTask.value
            } onCancel: {
                downloadTask.cancel()
            }
        }
    }
    
    @available(iOS, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(tvOS, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(macCatalyst, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(macOS, deprecated: 12, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(watchOS, deprecated: 8, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    func download(resumeWith data: Data) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(resumeFrom: data, delegate: nil)
        } else {
            let sema = DispatchSemaphore(value: 0)
            let reference = UnsafeReference<URLSessionDownloadTask>()
            let underlyingTask = Task {
                let marker:DownloadURLMarker = try await withCheckedThrowingContinuation { continuation in
                    let sessionTask = self.downloadTask(withResumeData: data) { url, response, error in
                        do {
                            guard let url, let response else {
                                throw (error ?? URLError(.badServerResponse))
                            }
                            let marker = DownloadURLMarker(
                                target: url,
                                temporal: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp", isDirectory: false),
                                response: response
                            )
                            try FileManager.default.moveItem(at: marker.target, to: marker.temporal)
                            continuation.resume(returning: marker)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    reference.value = sessionTask
                    sema.signal()
                }
                try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                return (marker.target, marker.response)
            }
            let downloadTask = await withUnsafeContinuation { continuation in
                sema.wait()
                continuation.resume(returning: reference.value.unsafelyUnwrapped)
            }
            downloadTask.resume()
            if Task.isCancelled {
                downloadTask.cancel()
            }
            return try await withTaskCancellationHandler {
                try await underlyingTask.value
            } onCancel: {
                downloadTask.cancel()
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

struct DownloadURLMarker: Sendable, Hashable {
    let target:URL
    let temporal:URL
    let response:URLResponse
}

final class UnsafeReference<T:Sendable & URLSessionTask> {
    var value:T?
}
