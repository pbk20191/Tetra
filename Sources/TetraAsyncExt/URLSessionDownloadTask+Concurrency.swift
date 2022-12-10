//
//  URLSessionDownloadTask+Concurrency.swift
//  
//
//  Created by pbk on 2022/12/08.
//

import Foundation
import Dispatch
import _Concurrency

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
internal func perfomDownload(on session:URLSession, from url: URL) async throws -> DownloadURLMarker {
    let sema = DispatchSemaphore(value: 0)
    let reference = UnsafeReference<URLSessionDownloadTask>()
    let underlyingTask = Task {
        try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.downloadTask(with: url) { downloadURL, response, error in
                do {
                    guard let downloadURL, let response else {
                        throw (error ?? URLError(.badServerResponse, userInfo: [
                            NSURLErrorFailingURLErrorKey: url,
                            NSURLErrorFailingURLStringErrorKey: url.absoluteString,
                            NSLocalizedDescriptionKey: "\(URLError.Code.badServerResponse)"
                        ]))
                    }
                    let marker = DownloadURLMarker(
                        target: downloadURL,
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
        try await underlyingTask.value
    } onCancel: {
        downloadTask.cancel()
    }
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
internal func perfomDownload(on session:URLSession, for request: URLRequest) async throws -> DownloadURLMarker {
    let sema = DispatchSemaphore(value: 0)
    let reference = UnsafeReference<URLSessionDownloadTask>()
    let underlyingTask = Task {
        try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.downloadTask(with: request) { downloadURL, response, error in
                do {
                    guard let downloadURL, let response else {
                        throw (error ?? URLError(.badServerResponse, userInfo: [
                            NSURLErrorFailingURLErrorKey: request.url as Any,
                            NSURLErrorFailingURLStringErrorKey: request.url?.absoluteString as Any,
                            NSLocalizedDescriptionKey: "\(URLError.Code.badServerResponse)"
                        ]))
                    }
                    let marker = DownloadURLMarker(
                        target: downloadURL,
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
        try await underlyingTask.value
    } onCancel: {
        downloadTask.cancel()
    }
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
internal func perfomDownload(on session:URLSession, resumeFrom data:Data) async throws -> DownloadURLMarker {
    let sema = DispatchSemaphore(value: 0)
    let reference = UnsafeReference<URLSessionDownloadTask>()
    let underlyingTask = Task {
        try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.downloadTask(withResumeData: data) { url, response, error in
                do {
                    guard let url, let response else {
                        throw (error ?? URLError(.badServerResponse, userInfo: [
                            NSLocalizedDescriptionKey: "\(URLError.Code.badServerResponse)"
                        ]))
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
       try await underlyingTask.value
    } onCancel: {
        downloadTask.cancel()
    }
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
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
    @inlinable
    func download(for url: URL) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(from: url)
        } else {
            let marker = try await perfomDownload(on: self, from: url)
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
    

    
    /// Convenience method to download using an URLRequest, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(iOS, deprecated: 15, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @available(tvOS, deprecated: 15, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @available(macCatalyst, deprecated: 15, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @available(macOS, deprecated: 12, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @available(watchOS, deprecated: 8, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @inlinable
    func download(from request: URLRequest) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(for: request)
        } else {
            
            let marker = try await perfomDownload(on: self, for: request)
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
    @inlinable
    func download(resumeWith data: Data) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(resumeFrom: data, delegate: nil)
        } else {
            let marker = try await perfomDownload(on: self, resumeFrom: data)
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
    
}

