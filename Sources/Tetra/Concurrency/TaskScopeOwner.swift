//
//  TaskScopeOwner.swift
//  
//
//  Created by pbk on 2023/01/02.
//

import Foundation

public final class TaskScopeOwner: Sendable, Hashable {
    
    public static func == (lhs: TaskScopeOwner, rhs: TaskScopeOwner) -> Bool {
        lhs.scope == rhs.scope
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(scope)
    }
    
    public let scope:TaskScope
    
    /// Create TaskScopeOwner which cancel its TaskScope automatically
    /// - Parameters:
    ///   - detached: To create detached TaskScope pass non-nil Void
    ///   - priority: TaskScope's TaskPriority
    public init(detached: Void? = nil, priority: TaskPriority? = nil) {
        scope = TaskScope(unsafe: (), detached: detached, priority: priority)
    }
    
    deinit {
        scope.cancel()
    }
 
    @inlinable
    @Sendable
    public nonisolated func cancel() {
        scope.cancel()
    }
    
    @inlinable
    public var isCancelled: Bool {
        @Sendable get { scope.isCancelled }
    }
    
    /**
     submit the operation to this `TaskScopeOwner`. operation will be executed on the next possible opportunity unless it's cancelled.
     Task created by the given job inherit TaskScopeOwner's context. .
     - Parameter operation: async job to submit
     - Returns: if operation is submitted successfully
     */
    @discardableResult
    public func launch(operation: @escaping @Sendable () async -> Void) -> Bool {
        scope.launch(operation: operation)
    }
    
}

