//
//  RunLoopOperation.swift
//  
//
//  Created by pbk on 2022/12/10.
//

import Foundation
import Dispatch
import os
import Combine

internal final class RunLoopOperation: Operation, @unchecked Sendable {
    
    private var block:(() -> ())?
    let mode:RunLoop.Mode
    let indefinitely:Bool
    /**
     Initialize the RunLoopOperation
     
     Grab the `RunLoop` using `RunLoop.current` inside the block and add input to the RunLoop.
     
     - Parameter block: block where you can access the RunLoop that operation will run.
     */
    public init(mode:RunLoop.Mode = .default, indefinitely:Bool = false, block: @escaping () -> Void) {
        self.mode = mode
        self.block = block
        self.indefinitely = indefinitely
    }
    
    // run the initial Block and run the RunLoop until cancelled or RunLoop have no inputs to run.
    public override func main() {
        block?()
        block = nil
        // iOS, macOS, tvOS, watchOS: main RunLoop is already running, and we are in main thread.
        if (RunLoop.main === RunLoop.current) {
            return
        }
        
        while (!isCancelled && !isFinished) {
            let date = Date().addingTimeInterval(.leastNonzeroMagnitude)
            if !RunLoop.current.run(mode: mode, before: date) && !indefinitely {
                break
            }
        }
    }
    
}

internal extension Operation {
    
    
    static func runLoop(
        mode:RunLoop.Mode = .default, indefinitely:Bool = false, block: @escaping () -> Void
    ) async {
        if Task.isCancelled {
            return
        }
        let op = RunLoopOperation(mode: mode, indefinitely: indefinitely, block: block)
        DispatchQueue.global().async { op.start() }
        await withTaskCancellationHandler {
            await withUnsafeContinuation { continuation in
                op.waitUntilFinished()
                continuation.resume()
            }
        } onCancel: {
            op.cancel()
        }
    }
    
}

internal final class RunLoopScheduler: Scheduler, @unchecked Sendable {
    
    public func schedule(after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) -> Cancellable {
        runLoop.schedule(after: date, interval: interval, tolerance: tolerance, options: options, action)
    }
    
    
    public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {
        runLoop.schedule(after: date, tolerance: tolerance, options: options, action)
    }
    
    
    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        runLoop.schedule(options: options, action)
    }
    
    public var now: SchedulerTimeType { runLoop.now }
    
    public var minimumTolerance: SchedulerTimeType.Stride { runLoop.minimumTolerance }
    
    
    public typealias SchedulerTimeType = RunLoop.SchedulerTimeType
    
    public typealias SchedulerOptions = RunLoop.SchedulerOptions
    
    
    private let task:Task<Void,Never>
    private let runLoop:RunLoop
    
    @preconcurrency
    private final class Holder<T> {
        var value:T?
    }
    
    private init(task:Task<Void,Never>, runLoop:RunLoop) {
        self.task = task
        self.runLoop = runLoop
    }
    
    public static func creatWithBlocking() -> Self {
        let start = DispatchTime.now()
        let holder = Holder<RunLoop>()
        let sema = DispatchSemaphore(value: 0)
        let task = Task.detached(priority: .high) {
            await Operation.runLoop(indefinitely: true) {
                holder.value = RunLoop.current
                sema.signal()
            }
        }
        sema.wait()
        let runLoop = holder.value.unsafelyUnwrapped
        let end = DispatchTime.now()
        print(DispatchTimeInterval.nanoseconds(Int(end.uptimeNanoseconds - start.uptimeNanoseconds)))
        return Self.init(task: task, runLoop: runLoop)
    }
    
    public static func create() async -> Self {
        let holder = Holder<RunLoop>()
        let sema = DispatchSemaphore(value: 0)
        let task = Task {
            await Operation.runLoop(indefinitely: true) {
                holder.value = RunLoop.current
                sema.signal()
            }
        }
        let runLoop = await withUnsafeContinuation { continuation in
            sema.wait()
            continuation.resume(returning: holder.value.unsafelyUnwrapped)
        }
        return Self.init(task: task, runLoop: runLoop)
    }

    deinit {
        task.cancel()
    }
    
}
