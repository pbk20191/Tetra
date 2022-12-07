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
    nonisolated
    func download(for url: URL) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(from: url)
        } else {
            let marker = try await downloadFrom(url: url)
            try await withUnsafeThrowingContinuation { continuation in
                do {
                    print(marker.target, FileManager.default.fileExists(atPath: marker.target.path))
                    try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            return (marker.target, marker.response)
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
            let marker = try await downloadFor(request: request)
            try await withUnsafeThrowingContinuation { continuation in
                do {
                    try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            return (marker.target, marker.response)
        }
    }
    
    /// Convenience method to resume download, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter resumeData: Resume data from an incomplete download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(iOS, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(tvOS, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(macCatalyst, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(macOS, deprecated: 12, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(watchOS, deprecated: 8, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    func download(resumeWith data: Data) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(resumeFrom: data, delegate: nil)
        } else {
            let marker = try await downloadResume(data: data)
            try await withUnsafeThrowingContinuation { continuation in
                do {
                    try FileManager.default.moveItem(at: marker.temporal, to: marker.target)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            return (marker.target, marker.response)
        }
    }
    
    /// Convenience method to upload data using an URLRequest, creates and resumes an URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter fileURL: File to upload.
    /// - Returns: Data and response.
    @available(iOS, deprecated: 15, message: "Use `upload(for:fromFile:delegate:)` instead", renamed: "upload(for:fromFile:)")
    @available(tvOS, deprecated: 15, message: "Use `upload(for:fromFile:delegate:)` instead", renamed: "upload(for:fromFile:)")
    @available(macCatalyst, deprecated: 15, message: "Use `upload(for:fromFile:delegate:)` instead", renamed: "upload(for:fromFile:)")
    @available(macOS, deprecated: 12, message: "Use `upload(for:fromFile:delegate:)` instead", renamed: "upload(for:fromFile:)")
    @available(watchOS, deprecated: 8, message: "Use `upload(for:fromFile:delegate:)` instead", renamed: "upload(for:fromFile:)")
    func upload(with request:URLRequest, fromFile fileURL:URL) async throws -> (Data, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await upload(for: request, fromFile: fileURL)
        } else {
            let sema = DispatchSemaphore(value: 0)
            let reference = UnsafeReference<URLSessionUploadTask>()
            let underlyingTask = Task {
                return try await withCheckedThrowingContinuation { continuation in
                    let sessionTask = self.uploadTask(with: request, fromFile: fileURL) { data, response, error in
                        do {
                            guard let data, let response else {
                                throw (error ?? URLError(.badServerResponse))
                            }
                            continuation.resume(returning: (data, response))
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    reference.value = sessionTask
                    sema.signal()
                }
            }
            let uploadTask = await withUnsafeContinuation { continuation in
                sema.wait()
                continuation.resume(returning: reference.value.unsafelyUnwrapped)
            }
            uploadTask.resume()
            if Task.isCancelled {
                uploadTask.cancel()
            }
            return try await withTaskCancellationHandler {
                try await underlyingTask.value
            } onCancel: {
                uploadTask.cancel()
            }
        }
    }
    
    /// Convenience method to upload data using an URLRequest, creates and resumes an URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter bodyData: Data to upload.
    /// - Returns: Data and response
    @available(iOS, deprecated: 15, message: "Use `upload(for:from:delegate:)` instead", renamed: "upload(for:from:)")
    @available(tvOS, deprecated: 15, message: "Use `upload(for:from:delegate:)` instead", renamed: "upload(for:from:)")
    @available(macCatalyst, deprecated: 15, message: "Use `upload(for:from:delegate:)` instead", renamed: "upload(for:from:)")
    @available(macOS, deprecated: 12, message: "Use `upload(for:from:delegate:)` instead", renamed: "upload(for:from:)")
    @available(watchOS, deprecated: 8, message: "Use `upload(for:from:delegate:)` instead", renamed: "upload(for:from:)")
    func upload(with request:URLRequest, from bodyData:Data) async throws -> (Data, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await upload(for: request, from: bodyData)
        } else {
            let sema = DispatchSemaphore(value: 0)
            let reference = UnsafeReference<URLSessionUploadTask>()
            let underlyingTask = Task {
                return try await withCheckedThrowingContinuation { continuation in
                    let sessionTask = self.uploadTask(with: request, from: bodyData) { data, response, error in
                        do {
                            guard let data, let response else {
                                throw (error ?? URLError(.badServerResponse))
                            }
                            continuation.resume(returning: (data, response))
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    reference.value = sessionTask
                    sema.signal()
                }
            }
            let uploadTask = await withUnsafeContinuation { continuation in
                sema.wait()
                continuation.resume(returning: reference.value.unsafelyUnwrapped)
            }
            uploadTask.resume()
            if Task.isCancelled {
                uploadTask.cancel()
            }
            return try await withTaskCancellationHandler {
                try await underlyingTask.value
            } onCancel: {
                uploadTask.cancel()
            }
        }
    }
    
    @nonobjc
    @usableFromInline
    internal func downloadFor(request: URLRequest) async throws -> (temporal:URL, target:URL, response:URLResponse) {
        let sema = DispatchSemaphore(value: 0)
        let reference = UnsafeReference<URLSessionDownloadTask>()
        let underlyingTask = Task {
            try await withCheckedThrowingContinuation { continuation in
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
            let marker = try await underlyingTask.value
            return (marker.temporal, marker.target, marker.response)
        } onCancel: {
            downloadTask.cancel()
        }
    }
    
    @nonobjc
    @usableFromInline
    internal func downloadFrom(url:URL) async throws -> (temporal:URL, target:URL, response:URLResponse) {
        let sema = DispatchSemaphore(value: 0)
        let reference = UnsafeReference<URLSessionDownloadTask>()
        let underlyingTask = Task {
            try await withCheckedThrowingContinuation { continuation in
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
            let marker = try await underlyingTask.value
            return (marker.temporal, marker.target, marker.response)
        } onCancel: {
            downloadTask.cancel()
        }

    }
    
    @nonobjc
    @usableFromInline
    internal func downloadResume(data: Data) async throws -> (temporal:URL, target:URL, response:URLResponse) {
        let sema = DispatchSemaphore(value: 0)
        let reference = UnsafeReference<URLSessionDownloadTask>()
        let underlyingTask = Task {
            try await withCheckedThrowingContinuation { continuation in
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
            let marker = try await underlyingTask.value
            return (marker.temporal, marker.target, marker.response)
        } onCancel: {
            downloadTask.cancel()
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
