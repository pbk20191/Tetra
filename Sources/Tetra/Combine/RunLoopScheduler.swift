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
    
    private let source:CFRunLoopSource
    
    nonisolated
    public let runLoop:CFRunLoop
    @preconcurrency
    private final class Holder<T> {
        var value:T?
    }

    private init(runLoop:CFRunLoop, source:CFRunLoopSource) {
        self.runLoop = runLoop
        self.source = source
    }

    deinit {
        CFRunLoopSourceInvalidate(source)
        CFRunLoopWakeUp(runLoop)
    }
    
    public init(async:Void = ()) async {
        var nullContext = CFRunLoopSourceContext()
        nullContext.version = 0
        let source = CFRunLoopSourceCreate(nil, 0, &nullContext).unsafelyUnwrapped
        let nsRunLoop: RunLoop = await withUnsafeContinuation{ continuation in
            let thread = Thread{
                continuation.resume(returning: .current)
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
                while CFRunLoopSourceIsValid(source), RunLoop.current.run(mode: .default, before: .distantFuture) { }
            }
            thread.qualityOfService = .background
            thread.start()
        }
        self.runLoop = nsRunLoop.getCFRunLoop()
        self.source = source
    }
    
    /**
     Create Scheduler in sync
     
     Pull a thread from GCD and run the CFRunLoop of that Thread. Thread will return back to GCD, when RunLoop stops and Scheduler is
     deinitialized. This initializer blocks the current thread until the Scheduler is ready.
     */
    public init(sync: Void = ()) {
        let holder = Holder<RunLoop>()
        let semaphore = DispatchSemaphore(value: 0)
        var nullContext = CFRunLoopSourceContext()
        nullContext.version = 0
        let source = CFRunLoopSourceCreate(nil, 0, &nullContext).unsafelyUnwrapped
        let job:@Sendable () -> () = { [weak holder, weak semaphore] in
            holder.unsafelyUnwrapped.value = RunLoop.current
            semaphore.unsafelyUnwrapped.signal()
            if Thread.isMainThread {
                return
            }
            holder = nil
            semaphore = nil
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
            while CFRunLoopSourceIsValid(source), RunLoop.current.run(mode: .default, before: .distantFuture) { }
        }
        let parentLevel = Thread.current.qualityOfService
        let qos:DispatchQoS.QoSClass
        switch parentLevel {
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
                let thread = Thread(block: job)
                thread.qualityOfService = parentLevel
                thread.start()
            } else {
                job()
            }
        }
        semaphore.wait()
        let runLoop = holder.value.unsafelyUnwrapped
        self.runLoop = runLoop.getCFRunLoop()
        self.source = source
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
        if CFRunLoopIsWaiting(runLoop) {
            CFRunLoopWakeUp(runLoop)
        }
    }
    
    nonisolated
    public var now: SchedulerTimeType { .init(Date()) }
    
    nonisolated
    public var minimumTolerance: SchedulerTimeType.Stride { 0.0 }
    
}
