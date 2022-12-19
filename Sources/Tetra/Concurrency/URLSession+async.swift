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

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
public extension URLSession {
    
    /// Convenience method to download using an URL, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter url: The URL for which to download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(iOS, deprecated: 15, message: "Use `download(from:delegate:)` instead", renamed: "download(from:delegate:)")
    @available(tvOS, deprecated: 15, message: "Use `download(from:delegate:)` instead", renamed: "download(from:delegate:)")
    @available(macCatalyst, deprecated: 15, message: "Use `download(from:delegate:)` instead", renamed: "download(from:delegate:)")
    @available(macOS, deprecated: 12, message: "Use `download(from:delegate:)` instead", renamed: "download(from:delegate:)")
    @available(watchOS, deprecated: 8, message: "Use `download(from:delegate:)` instead", renamed: "download(from:delegate:)")
    @inlinable
    func download(from url: URL) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(from: url, delegate: nil)
        } else {
            return try await perfomDownload(on: self, from: url)
        }
    }
    

    
    /// Convenience method to download using an URLRequest, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(iOS, deprecated: 15, message: "Use `download(for:delegate:)` instead", renamed: "download(for:delegate:)")
    @available(tvOS, deprecated: 15, message: "Use `download(for:delegate:)` instead", renamed: "download(for:delegate:)")
    @available(macCatalyst, deprecated: 15, message: "Use `download(for:delegate:)` instead", renamed: "download(for:)")
    @available(macOS, deprecated: 12, message: "Use `download(for:delegate:)` instead", renamed: "download(for:delegate:)")
    @available(watchOS, deprecated: 8, message: "Use `download(for:delegate:)` instead", renamed: "download(for:delegate:)")
    @inlinable
    func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(for: request, delegate: nil)
        } else {
            return try await perfomDownload(on: self, for: request)
        }
    }
    
    /// Convenience method to resume download, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter resumeData: Resume data from an incomplete download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(iOS, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:delegate:)")
    @available(tvOS, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:delegate:)")
    @available(macCatalyst, deprecated: 15, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:)")
    @available(macOS, deprecated: 12, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:delegate:)")
    @available(watchOS, deprecated: 8, message: "Use `download(resumeFrom:delegate:)` instead", renamed: "download(resumeFrom:delegate:)")
    @inlinable
    func download(resumeFrom data: Data) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            return try await download(resumeFrom: data, delegate: nil)
        } else {
            return try await perfomDownload(on: self, resumeFrom: data)
        }
    }
    
}


