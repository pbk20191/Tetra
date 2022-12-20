//
//  RunLoopScheduler.swift
//  
//
//  Created by pbk on 2022/12/10.
//

import Foundation
import Dispatch
import os
import Combine

/**
 RunLoopScheduler suitable for background runLoop
 
 this class runs RunLoop indefinitely in default Mode, until deinitialized
 
 */
public final class RunLoopScheduler: Scheduler, @unchecked Sendable {

    public typealias SchedulerTimeType = RunLoop.SchedulerTimeType
    public typealias SchedulerOptions = Never
    
    private let canellable:AnyCancellable
    
    nonisolated
    public let runLoop:CFRunLoop
    
    @preconcurrency
    private final class Holder<T> {
        var value:T?
    }

    private init(cancellable:AnyCancellable, runLoop: CFRunLoop) {
        self.runLoop = runLoop
        self.canellable = cancellable
    }

    public convenience init(async:Void = ()) async {
        let holder = Holder<RunLoop>()
        let semaphore = DispatchSemaphore(value: 0)
        let operation = BlockOperation()
        operation.addExecutionBlock { [unowned holder, unowned semaphore, unowned operation] in
            holder.value = RunLoop.current
            semaphore.signal()
            Thread.current.qualityOfService = .background
            while !operation.isCancelled {
                RunLoop.current.run(mode: .default, before: Date())
            }
        }
        let runLoop = await withUnsafeContinuation{ [unowned holder, unowned semaphore] in
            let thread = Thread{ operation.start() }
            thread.qualityOfService = Thread.current.qualityOfService
            thread.start()
            semaphore.wait()
            $0.resume(returning: holder.value.unsafelyUnwrapped)
        }
        holder.value = nil
        self.init(
            cancellable: AnyCancellable(operation.cancel),
            runLoop: runLoop.getCFRunLoop()
        )
    }
    
    /**
     Create Scheduler in sync
     
     Pull a thread from GCD and run the CFRunLoop of that Thread. Thread will return back to GCD, when RunLoop stops and Scheduler is
     deinitialized. This initializer blocks the current thread until the Scheduler is ready.
     */
    public convenience init(sync: Void = ()) {
        let holder = Holder<RunLoop>()
        let semaphore = DispatchSemaphore(value: 0)
        let operation = BlockOperation()
        operation.addExecutionBlock { [unowned holder, unowned semaphore, unowned operation] in
            holder.value = RunLoop.current
            semaphore.signal()
            while !operation.isCancelled {
                RunLoop.current.run(mode: .default, before: Date())
            }
        }
        let qos:DispatchQoS.QoSClass
        switch Thread.current.qualityOfService {
        case .userInteractive:
            qos = .userInteractive
        case .userInitiated:
            qos = .userInitiated
        case .utility:
            qos = .utility
        case .background:
            qos = .background
        case .default:
            qos = .default
        @unknown default:
            qos = .unspecified
        }
        DispatchQueue.global(qos: qos).async{
            assert(!Thread.isMainThread)
            if Thread.isMainThread {
                /// Reschedule to New Thread since we need none main thread
                Thread.detachNewThread{ operation.start() }
            } else {
                operation.start()
            }
        }
        
        semaphore.wait()
        let cfRunLoop = holder.value.unsafelyUnwrapped.getCFRunLoop()
        holder.value = nil
        self.init(
            cancellable: .init(operation.cancel),
            runLoop: cfRunLoop
        )
    }
    
    @inlinable
    nonisolated
    public func schedule(
        after date: SchedulerTimeType,
        interval: SchedulerTimeType.Stride,
        tolerance: SchedulerTimeType.Stride,
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        let timer = Timer(fire: date.date, interval: interval.timeInterval, repeats: true) { _ in
            action()
        }
        timer.tolerance = tolerance.timeInterval
        let cfTimer = timer as CFRunLoopTimer
        CFRunLoopAddTimer(runLoop, cfTimer, .defaultMode)
        return AnyCancellable{
            CFRunLoopTimerInvalidate(cfTimer)
        }
    }
    
    @inlinable
    nonisolated
    public func schedule(
        after date: SchedulerTimeType,
        tolerance: SchedulerTimeType.Stride,
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        let timer = Timer(fire: date.date, interval: 0, repeats: false) { _ in
            action()
        }
        timer.tolerance = tolerance.timeInterval
        CFRunLoopAddTimer(runLoop, timer as CFRunLoopTimer, .defaultMode)
    }
    
    @inlinable
    nonisolated
    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, action)
    }
    
    nonisolated
    public var now: SchedulerTimeType { .init(Date()) }
    
    nonisolated
    public var minimumTolerance: SchedulerTimeType.Stride { 0.0 }
    
}
