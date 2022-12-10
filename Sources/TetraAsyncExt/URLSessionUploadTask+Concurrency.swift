//
//  URLSessionUploadTask+Concurrency.swift
//  
//
//  Created by pbk on 2022/12/08.
//

import Foundation
import Dispatch
import _Concurrency

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
internal func perfomUpload(on session:URLSession, with request:URLRequest, fromFile fileURL:URL) async throws -> (Data, URLResponse) {
    let sema = DispatchSemaphore(value: 0)
    let reference = UnsafeReference<URLSessionUploadTask>()
    let underlyingTask = Task {
        return try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.uploadTask(with: request, fromFile: fileURL) { data, response, error in
                do {
                    guard let data, let response else {
                        throw (error ?? URLError(.badServerResponse, userInfo: [
                            NSURLErrorFailingURLErrorKey: request.url as Any,
                            NSURLErrorFailingURLStringErrorKey: request.url?.absoluteString as Any,
                            NSLocalizedDescriptionKey: "\(URLError.Code.badServerResponse)"
                        ]))
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
        reference.value = nil
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

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
internal func perfomUpload(on session: URLSession, with request:URLRequest, from bodyData:Data) async throws -> (Data, URLResponse) {
    let sema = DispatchSemaphore(value: 0)
    let reference = UnsafeReference<URLSessionUploadTask>()
    let underlyingTask = Task {
        return try await withUnsafeThrowingContinuation { continuation in
            let sessionTask = session.uploadTask(with: request, from: bodyData) { data, response, error in
                do {
                    guard let data, let response else {
                        throw (error ?? URLError(.badServerResponse, userInfo: [
                            NSURLErrorFailingURLErrorKey: request.url as Any,
                            NSURLErrorFailingURLStringErrorKey: request.url?.absoluteString as Any,
                            NSLocalizedDescriptionKey: "\(URLError.Code.badServerResponse)"
                        ]))
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
        reference.value = nil
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

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
public extension URLSession {
    
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
    @inlinable
    func upload(with request:URLRequest, fromFile fileURL:URL) async throws -> (Data, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await upload(for: request, fromFile: fileURL)
        } else {
            return try await perfomUpload(on: self, with: request, fromFile: fileURL)
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
    @inlinable
    func upload(with request:URLRequest, from bodyData:Data) async throws -> (Data, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await upload(for: request, from: bodyData)
        } else {
            return try await perfomUpload(on: self, with: request, from: bodyData)
        }
    }
    
}
