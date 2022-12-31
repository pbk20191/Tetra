//
//  TaskScope.swift
//  
//
//  Created by pbk on 2022/12/28.
//

import Foundation
import os

/**
  Wrapper object which act like CoroutineScope in Coroutine.
 
 Unlike Task which inherit context of upper level task. task running inside `TaskScope` inherit   `TaskScope`'s context.
 
 ex) `TaskLocal`, `TaskPriority`
 
 `TaskScope` must be explictly cancelled or underlying Task leaks and runs forever.
    
 */
internal struct TaskScope: Sendable, Hashable {
    
    public typealias Operation = @Sendable () async -> ()
    
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(task)
    }
    
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.task == rhs.task
    }
    
    @inlinable
    @Sendable
    public nonisolated func cancel() {
        task.cancel()
    }
    
    @inlinable
    public var isCancelled: Bool {
        @Sendable get { task.isCancelled }
    }
    
    
    @usableFromInline
    let task:Task<Void,Never>
    
    private let state = JobSequence()
    
    @usableFromInline
    internal init(priority: TaskPriority? = nil) {
        let sequence = state
        task = Task(priority: priority) {
            for child in sequence.popBuffered() {
                async let _ = try? await child()
            }
            for await child in sequence {
                async let _ = try? await child()
            }
            for child in sequence.popBuffered() {
                async let _ = try? await child()
            }
        }
    }
    
    @usableFromInline
    internal init(detached: Void, priority: TaskPriority? = nil) {
        let sequence = state
        task = Task.detached(priority: priority) {
            for child in sequence.popBuffered() {
                async let _ = try? await child()
            }
            for await child in sequence {
                async let _ = try? await child()
            }
            for child in sequence.popBuffered() {
                async let _ = try? await child()
            }
        }
    }
    
    /**
     submit the job to this `TaskScope`. operation will be executed on the next possible opportunity unless it's cancelled.
     Task created by the given job inherit TaskScope's context. .
     - Parameter operation:
     - Returns: if job is submitted successfully
     */
    @discardableResult
    public func launch(_ operation: __owned @escaping Operation) -> Bool {
        state.append(job: operation)
    }
    
    internal func shutdown() async {
        task.cancel()
        await task.value
    }
    
}

