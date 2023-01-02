//
//  TaskScopeProtocol.swift
//  
//
//  Created by pbk on 2023/01/02.
//

import Foundation

public protocol TaskScopeProtocol: Sendable, Hashable {
    
    typealias Job = @Sendable () async -> Void
    
    /**
     submit the Job to this `TaskScope`. Job will be executed on the next possible opportunity unless it's cancelled.
     Task created by the given job inherit TaskScope's context. .
     - Parameter operation: async job to submit
     - Returns: if operation is submitted successfully
     */
    
    func launch(operation: @escaping Job) -> Bool
    
    func cancel()
    
    var isCancelled:Bool { get }
    
}
