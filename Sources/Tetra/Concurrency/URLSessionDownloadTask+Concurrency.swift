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
internal func performDownload(on session:URLSession, from url: URL) async throws -> (URL,URLResponse) {
    let stateLock: some UnfairStateLock<(URLSessionDownloadTask?, Bool)> = createCheckedStateLock(checkedState: (nil, false))
    return try await withTaskCancellationHandler {
        try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.downloadTask(with: url) { location, response, error in
                do {
                    guard let location, let response else {
                        throw (error ?? URLError(.unknown, userInfo: [
                            NSURLErrorFailingURLErrorKey: url,
                            NSURLErrorFailingURLStringErrorKey: url.absoluteString,
                            NSLocalizedDescriptionKey: NSLocalizedString("Err-998", bundle: .init(for: URLSession.self), comment: "unknown error")
                        ].compactMapValues{
                            guard let value = $0 as Any? else { return nil }
                            return value
                        }))
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
            sessionTask.resume()
            let isCancelled = stateLock.withLock{
                let oldValue = $0.1
                if (!oldValue) {
                    $0 = (sessionTask, false)
                }
                return oldValue
            }

            if isCancelled {
                sessionTask.cancel()
            }
        }
    } onCancel: {
        stateLock.withLock{
            let oldValue = $0
            $0 = (nil, true)
            return oldValue.0
        }?.cancel()
    }
}


@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
internal func performDownload(on session:URLSession, for request: URLRequest) async throws -> (URL, URLResponse) {
    let stateLock: some UnfairStateLock<(URLSessionDownloadTask?, Bool)> = createCheckedStateLock(checkedState: (nil, false))
    return try await withTaskCancellationHandler {
        try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.downloadTask(with: request) { location, response, error in
                do {
                    guard let location, let response else {
                        throw (error ?? URLError(.unknown, userInfo: [
                            NSURLErrorFailingURLErrorKey: request.url as Any,
                            NSURLErrorFailingURLStringErrorKey: request.url?.absoluteString as Any,
                            NSLocalizedDescriptionKey: NSLocalizedString("Err-998", bundle: .init(for: URLSession.self), comment: "unknown error")
                        ].compactMapValues{
                            guard let value = $0 as Any? else { return nil }
                            return value
                        }))
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
            sessionTask.resume()

            let isCancelled = stateLock.withLock{
                let oldValue = $0
                if (!oldValue.1) {
                    $0 = (sessionTask, false)
                }
                return oldValue.1
            }

            if isCancelled {
                sessionTask.cancel()
            }
        }
    } onCancel: {
        stateLock.withLock{
            let oldValue = $0
            $0 = (nil, true)
            return oldValue.0
        }?.cancel()
    }
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
internal func performDownload(on session:URLSession, resumeFrom data:Data) async throws -> (URL, URLResponse) {
    let stateLock: some UnfairStateLock<(URLSessionDownloadTask?, Bool)> = createCheckedStateLock(checkedState: (nil, false))
    return try await withTaskCancellationHandler {
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
            sessionTask.resume()
            let isCancelled = stateLock.withLock{
                let oldValue = $0
                if (!oldValue.1) {
                    $0 = (sessionTask, false)
                }
                return oldValue.1
            }

            if isCancelled {
                sessionTask.cancel()
            }
        }
    } onCancel: {
        stateLock.withLock{
            let oldValue = $0
            $0 = (nil, true)
            return oldValue.0
        }?.cancel()
    }
}
