//
//  URLSessionDownloadTask+Concurrency.swift
//  
//
//  Created by pbk on 2022/12/08.
//

import Foundation
import Dispatch
import _Concurrency

@usableFromInline
internal func randomDownloadFileURL() -> URL {
    let samples = "012345689ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    let random = samples.shuffled().prefix(6).map(String.init).joined()
    return FileManager.default.temporaryDirectory
        .appendingPathComponent("CFNetworkDownload_" + random, isDirectory: false)
        .appendingPathExtension("tmp")
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
internal func perfomDownload(on session:URLSession, from url: URL) async throws -> (URL,URLResponse) {
    let sema = DispatchSemaphore(value: 0)
    let reference = UnsafeReference<URLSessionDownloadTask>()
    let underlyingTask = Task {
        try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.downloadTask(with: url) { location, response, error in
                do {
                    guard let location, let response else {
                        throw (error ?? URLError(.unknown, userInfo: [
                            NSURLErrorFailingURLErrorKey: url,
                            NSURLErrorFailingURLStringErrorKey: url.absoluteString,
                            NSLocalizedDescriptionKey: "\(URLError.Code.unknown)"
                        ]))
                    }
                    
                    let newURL = randomDownloadFileURL()
                    if FileManager.default.fileExists(atPath: newURL.path) {
                        let _ = try FileManager.default.replaceItemAt(newURL, withItemAt: location)
                    } else {
                        try FileManager.default.moveItem(at: location, to: newURL)
                    }
                    continuation.resume(returning: (newURL, response))
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
        reference.value = nil
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
internal func perfomDownload(on session:URLSession, for request: URLRequest) async throws -> (URL, URLResponse) {
    let sema = DispatchSemaphore(value: 0)
    let reference = UnsafeReference<URLSessionDownloadTask>()
    let underlyingTask = Task {
        try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.downloadTask(with: request) { location, response, error in
                do {
                    guard let location, let response else {
                        throw (error ?? URLError(.unknown, userInfo: [
                            NSURLErrorFailingURLErrorKey: request.url as Any,
                            NSURLErrorFailingURLStringErrorKey: request.url?.absoluteString as Any,
                            NSLocalizedDescriptionKey: "\(URLError.Code.unknown)"
                        ]))
                    }
                    let newURL = randomDownloadFileURL()
                    if FileManager.default.fileExists(atPath: newURL.path) {
                        let _ = try FileManager.default.replaceItemAt(newURL, withItemAt: location)
                    } else {
                        try FileManager.default.moveItem(at: location, to: newURL)
                    }
                    continuation.resume(returning: (newURL, response))
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
        reference.value = nil
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
internal func perfomDownload(on session:URLSession, resumeFrom data:Data) async throws -> (URL, URLResponse) {
    let sema = DispatchSemaphore(value: 0)
    let reference = UnsafeReference<URLSessionDownloadTask>()
    let underlyingTask = Task {
        try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.downloadTask(withResumeData: data) { location, response, error in
                do {
                    guard let location, let response else {
                        throw (error ?? URLError(.unknown, userInfo: [
                            NSLocalizedDescriptionKey: "\(URLError.Code.unknown)"
                        ]))
                    }
                    let newURL = randomDownloadFileURL()
                    if FileManager.default.fileExists(atPath: newURL.path) {
                        let _ = try FileManager.default.replaceItemAt(newURL, withItemAt: location)
                    } else {
                        try FileManager.default.moveItem(at: location, to: newURL)
                    }
                    continuation.resume(returning: (newURL, response))
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
        reference.value = nil
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
            return try await perfomDownload(on: self, from: url)
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
            return try await perfomDownload(on: self, for: request)
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
            return try await perfomDownload(on: self, resumeFrom: data)
        }
    }
    
}

