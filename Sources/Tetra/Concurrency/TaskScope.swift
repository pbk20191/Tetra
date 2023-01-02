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
 
 ex) `TaskLocal`, `TaskPriority`, `Actor`
 
 - important: retaining `self` inside long running task without explicit cancellation will prevent underlying Task being automatically cancelled.
```
 let scope = TaskScope()
 scope.launch {
    // Long running Task
    scope... // scope and underlying Task won't be cancelled automatically.
 }
 
 ```
 */
public struct TaskScope: Sendable, Hashable {
        
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
    fileprivate let buffer:JobSequence
    private let cancellable:TaskCancellable?
    
    private final class TaskCancellable: Sendable {
        
        private let task:Task<Void,Never>
        
        init(task: Task<Void, Never>) {
            self.task = task
        }
        
        deinit {
            task.cancel()
        }
        
    }
    
    /// Create Managed TaskScope which cancel its Task automatically
    /// - Parameters:
    ///   - detached: To create detached TaskScope pass non-nil Void
    ///   - priority: TaskScope's TaskPriority
    public init(detached: Void? = nil, priority: TaskPriority? = nil) {
        let source = Self(unsafe: (), detached: detached, priority: priority)
        self.buffer = source.buffer
        task = source.task
        cancellable = TaskCancellable(task: task)
    }
    
    @usableFromInline
    internal init(unsafe:Void, detached: Void? = nil, priority: TaskPriority? = nil) {
        let sequence = JobSequence()
        let creator:(TaskPriority?, @escaping @Sendable () async -> Void) -> Task<Void,Never> = {
            if detached == nil {
                return Task(priority: $0, operation: $1)
            } else {
                return Task.detached(priority: $0, operation: $1)
            }
        }
        task = creator(priority) {
            await withThrowingTaskGroup(of: Void.self) { group in
                for operation in sequence.popBuffered() {
                    group.addTask(operation: operation)
                    async let _ = try? await group.next()
                }
                for await operation in sequence {
                    group.addTask(operation: operation)
                    async let _ = try? await group.next()
                }
                for operation in sequence.popBuffered() {
                    group.addTask(operation: operation)
                    async let _ = try? await group.next()
                }
            }
        }
        buffer = sequence
        cancellable = nil
    }
    
    /**
     submit the operation to this `TaskScope`. operation will be executed on the next possible opportunity unless it's cancelled.
     Task created by the given job inherit TaskScope's context. .
     - Parameter operation: async job to submit
     - Returns: if operation is submitted successfully
     */
    @discardableResult
    public func launch(operation: __owned @escaping @Sendable () async -> Void) -> Bool {
        buffer.append(job: operation)
    }
    
}
