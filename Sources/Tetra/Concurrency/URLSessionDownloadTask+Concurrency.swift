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

@usableFromInline
internal func download_transformer(
    creator:(
        @escaping @Sendable (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTask
) async throws -> (URL, URLResponse) {
    try await urltask_transformer(
        transform: {
            let newURL = randomDownloadFileURL()
            do {
                if FileManager.default.fileExists(atPath: newURL.path) {
                    let _ = try FileManager.default.replaceItemAt(newURL, withItemAt: $0)
                } else {
                    try FileManager.default.moveItem(at: $0, to: newURL)
                }
                return .success(newURL)
            } catch {
                return .failure(error)
            }
        },
        creator: creator
    )
}

@usableFromInline
internal func urltask_transformer<T:URLSessionTask, Value, R>(
    transform: @Sendable (Value) -> Result<R,Error>,
    creator:(
        @escaping @Sendable (Value?, URLResponse?, Error?) -> Void
    ) -> T
) async throws -> (R,URLResponse) {
    let stateLock = createCheckedStateLock(checkedState: URLSessionTaskAsyncState<T>.waiting)
    
    return try await withTaskCancellationHandler {
        try await withoutActuallyEscaping(transform) { escapingTransform in
            try await withUnsafeThrowingContinuation { continuation in
                let sessionTask = creator() { data, response, error in
                    do {
                        guard let data, let response else {
                            throw error ?? URLError(.unknown, userInfo: [
                                NSLocalizedDescriptionKey: NSLocalizedString("Err-998", bundle: .init(for: URLSession.self), comment: "unknown error")
                            ])
                        }
                        let value = try escapingTransform(data).get()
                        continuation.resume(returning: (value, response))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                sessionTask.resume()

                let snapShot = stateLock.withLock{
                    let oldValue = $0
                    switch oldValue {
                    case .cancelled:
                        break
                    case .task:
                        assertionFailure("unexpected state")
                        fallthrough
                    case .waiting:
                        $0 = .task(sessionTask)
                    }
                    return oldValue
                    
                }
                switch snapShot {
                case .waiting:
                    break
                case .task(let uRLSessionDownloadTask):
                    uRLSessionDownloadTask.cancel()
                case .cancelled:
                    sessionTask.cancel()
                }
            }
        }
    } onCancel: {
        stateLock.withLock{
            $0.take()
        }?.cancel()
    }
    
}

private
enum URLSessionTaskAsyncState<Task:URLSessionTask>: Sendable {
    
    case waiting
    case task(Task)
    case cancelled
    
    mutating func take() -> Task? {
        if case let .task(uRLSessionDownloadTask) = self {
            self = .cancelled
            return uRLSessionDownloadTask
        } else {
            self = .cancelled
            return nil
        }
    }
    
}


