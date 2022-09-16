//
//  BackgroundTask.swift
//  
//
//  Created by pbk on 2022/06/14.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if !os(macOS) && !os(watchOS)

@available(macCatalystApplicationExtension 13.1, *)
public extension MainActor {
    static func performBackground<T:Sendable>(resultType: T.Type = T.self, body: @escaping @Sendable () async throws -> T) async rethrows -> T {
        if #available(iOSApplicationExtension 8.2, macCatalystApplicationExtension 13.1, tvOSApplicationExtension 9.0, *) {
            let task = Task(operation: body)
            ProcessInfo.processInfo.performExpiringActivity(withReason: "applicationExtensionExtraLife " + Date().description) { aboutToSuspend in
                if aboutToSuspend {
                    task.cancel()
                }
            }
            return try await withTaskCancellationHandler{
                task.cancel()
            } operation: {
                try await task.value
            }

        } else {
            return try await extraTask(body: body)
        }
    }
}

@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
@available(macCatalystApplicationExtension, unavailable)
extension MainActor {
    static func extraTask<T:Sendable>(resultType: T.Type = T.self, body: @escaping @Sendable () async throws -> T) async rethrows -> T {
        
        let underlyingTask = Task<T,Error>(operation: body)
        let task:Task<T,Error> = await run {
            let app = UIApplication.shared
            var taskReference:Task<T,Error>?
            let id = app.beginBackgroundTask() {
                taskReference?.cancel()
            }
            guard id != .invalid else {
                underlyingTask.cancel()
                return Task<T,Error>{ throw CancellationError() }
            }
            let cancelAction = {
                app.endBackgroundTask(id)
            }
            let task = Task<T,Error> {
                let value:T = try await withTaskCancellationHandler{
                    underlyingTask.cancel()
                    cancelAction()
                } operation: {
                    let result = await underlyingTask.result
                    if !Task.isCancelled {
                        app.endBackgroundTask(id)
                    }
                    return try result.get()
                }
                return value
            }
            taskReference = task
            return task
        }
        return try await withTaskCancellationHandler{
            task.cancel()
        } operation: {
            try await task.value
        }
    }
    
}
#endif
