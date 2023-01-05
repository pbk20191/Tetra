//
//  StandaloneTaskScope.swift
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
 let scope = StandaloneTaskScope()
 scope.launch {
    // Long running Task
    scope... // scope and underlying Task won't be cancelled automatically.
 }
 

 ```
 
 - important: StandaloneTaskScope is intended to be use for at most 20 child task with BackDeployed Concurreny stdlib ( < iOS 15 )
 otherwise StadaloneTaskScope rarely crash with EXC_BAD_ACCESS
 */
public struct StandaloneTaskScope: TaskScopeProtocol {
        
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
    
    private let buffer:JobSequence
    
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
        let source = Self(unmanaged: (), detached: detached, priority: priority)
        self.buffer = source.buffer
        task = source.task
        cancellable = TaskCancellable(task: task)
    }
    
    @usableFromInline
    internal init(unmanaged:Void, detached: Void? = nil, priority: TaskPriority? = nil) {
        let sequence = JobSequence()
        let creator:(TaskPriority?, @escaping @Sendable () async -> Void) -> Task<Void,Never> = {
            if detached == nil {
                return Task(priority: $0, operation: $1)
            } else {
                return Task.detached(priority: $0, operation: $1)
            }
        }
        task = creator(priority) {
          // TODO: use withDiscardingTaskGroup
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask(priority: .background) {
                    let _ = await waitCancellation()
                }
                await withTaskCancellationHandler {
                    if #available(iOS 15, macOS 12, watchOS 8.0, tvOS 15.0, macCatalyst 15.0, *) {
                        let pointer = UnsafeMutablePointer<ThrowingTaskGroup<Void,Error>>
                            .allocate(capacity: 1)
                        defer { pointer.deallocate() }
                        pointer.initialize(to: group)
                        defer { pointer.deinitialize(count: 1) }
                        async let enqueingTask: () = await {
                            for await operation in sequence {
                                pointer.pointee.addTask(operation: operation)
                                await Task.yield()
                            }
                        }()
                        while let _ = try? await group.next() {}
                        await enqueingTask
                    } else {
                        var jobIterator = sequence.makeAsyncIterator()
                        for _ in 0..<20 {
                            guard let job = await jobIterator.next() else {
                                break
                            }
                            group.addTask(operation: job)
                            
                        }
                        
                        while !Task.isCancelled {
                            _ = try? await group.next()
                            print("move")
                            guard let job = await jobIterator.next() else { break }
                            group.addTask(operation: job)
                        }
                    }
                } onCancel: {
                    sequence.finish()
                }
            }
            
        }
        
        buffer = sequence
        cancellable = nil
    }
    
    public func launch(operation: __owned @escaping Job) -> Bool {
        buffer.append(job: operation)
    }
    
}

