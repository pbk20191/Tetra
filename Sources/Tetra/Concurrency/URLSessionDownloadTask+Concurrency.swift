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
                            NSLocalizedDescriptionKey: NSLocalizedString("Err-998", bundle: .init(for: URLSession.self), comment: "unknown error")
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
                            NSLocalizedDescriptionKey: NSLocalizedString("Err-998", bundle: .init(for: URLSession.self), comment: "unknown error")
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
                            NSLocalizedDescriptionKey: NSLocalizedString("Err-998", bundle: .init(for: URLSession.self), comment: "unknown error")
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
