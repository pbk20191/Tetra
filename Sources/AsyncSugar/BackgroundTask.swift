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
    static func performBackground<T:Sendable>(resultType: T.Type = T.self, body: @escaping @Sendable () async throws -> T) async throws -> T {
        let isExtension:Bool
        if #available(iOSApplicationExtension 8.2, macCatalystApplicationExtension 13.1, tvOSApplicationExtension 9.0, *) {
            if #available(iOS 8.2, macCatalyst 13.1, tvOS 9.0, *) {
                isExtension = false
            } else {
                isExtension = true
            }
        } else {
            isExtension = false
        }
        if isExtension {
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
            return try await UIApplication.shared.backgroundTask(operation: body)
        }
    }
}


#endif


#if canImport(UIKit)

public extension UIApplication {
        
    func stateRestoration(operation: @Sendable () async -> Void) async {
        extendStateRestoration()
        await operation()
        completeStateRestoration()
    }
    
    func backgroundTask<T:Sendable>(resultType:T.Type = T.self, operation: @escaping @Sendable () async throws -> T) async rethrows -> T{
        let set = NSMutableSet()
        let task = Task{
            let id = await MainActor.run(resultType: UIBackgroundTaskIdentifier.self) {
                var taskId = UIBackgroundTaskIdentifier.invalid
                let id = beginBackgroundTask(withName: #function){ [unowned self] in
                    set.compactMap{ $0 as? Task<T,Error> }.forEach{ $0.cancel() }
                    endBackgroundTask(taskId)
                }
                taskId = id
                return id
            }
            guard id != .invalid else {
                withUnsafeCurrentTask{ $0?.cancel() }
                return try await operation()
            }
            do {
                let value = try await operation()
                endBackgroundTask(id)
                return value
            } catch {
                endBackgroundTask(id)
                throw error
            }
        }
        set.add(task)
        return try await withTaskCancellationHandler {
            task.cancel()
        } operation: {
            try await task.value
        }
    }
    
}
#endif
