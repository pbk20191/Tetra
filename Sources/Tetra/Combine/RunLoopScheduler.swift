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
 
 this class runs RunLoop indefinitely in default Mode, until deinitialized.
 */
public final class RunLoopScheduler: Scheduler, @unchecked Sendable, Identifiable {

    public typealias SchedulerTimeType = RunLoop.SchedulerTimeType
    public typealias SchedulerOptions = Never
    
    private let source:CFRunLoopSource
    nonisolated
    public let cfRunLoop:CFRunLoop
    
    nonisolated
    public let config:Configuration
    
    @preconcurrency
    private final class Holder<T> {
        var value:T?
    }
    
    private init(runLoop:CFRunLoop, source:CFRunLoopSource) {
        self.cfRunLoop = runLoop
        self.source = source
        self.config = .init()
    }

    deinit {
        CFRunLoopSourceInvalidate(source)
        CFRunLoopWakeUp(cfRunLoop)
        if CFRunLoopGetMain() !== cfRunLoop {
            CFRunLoopStop(cfRunLoop)
        }
    }
    
    public init(async: Void = (), config: Configuration = .init()) async {
        var nullContext = CFRunLoopSourceContext()
        nullContext.version = 0
        let emptySource = CFRunLoopSourceCreate(nil, 0, &nullContext).unsafelyUnwrapped
        let nsRunLoop: RunLoop = await withUnsafeContinuation{ continuation in
            DispatchQueue.global().async(qos: config.qos, flags: [.detached]) {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), emptySource, .defaultMode)
                continuation.resume(returning: .current)
                if CFRunLoopGetMain() === CFRunLoopGetCurrent() {
                    CFRunLoopSourceInvalidate(emptySource)
                }
                while
                    CFRunLoopSourceIsValid(emptySource),
                    RunLoop.current.run(mode: .default, before: .distantFuture)
                { }
            }
        }
        self.cfRunLoop = nsRunLoop.getCFRunLoop()
        self.source = emptySource
        self.config = config
    }
    
    /**
     Create Scheduler in sync
     
     Pull a thread from GCD and run the CFRunLoop of that Thread. Thread will return back to GCD, when RunLoop stops and Scheduler is
     deinitialized. This initializer blocks the current thread until the Scheduler is ready.
     */
    public init(sync: Void = (), config: Configuration = .init()) {
        let holder = Holder<RunLoop>()
        var nullContext = CFRunLoopSourceContext()
        nullContext.version = 0
        let lock = NSConditionLock(condition: 0)
        let emptySource = CFRunLoopSourceCreate(nil, 0, &nullContext).unsafelyUnwrapped
        
        /** weak or unowned reference is needed, cause strong reference will be retained unitl runLoop ends.
         */
        let workItem = DispatchWorkItem(qos: config.qos, flags: [.detached]) { [weak holder, weak lock] in
            lock.unsafelyUnwrapped.lock(whenCondition: 0)
            holder.unsafelyUnwrapped.value = RunLoop.current
            lock.unsafelyUnwrapped.unlock(withCondition: 1)
            
            /** without explicit nil assignment iOS 16.2 instrument tells me `holder` and `lock`  is leaked even with weak/unowned reference.
             */
            lock = nil
            holder = nil
            CFRunLoopAddSource(CFRunLoopGetCurrent(), emptySource, .defaultMode)
            if CFRunLoopGetMain() === CFRunLoopGetCurrent() {
                CFRunLoopSourceInvalidate(emptySource)
            }
            while
                CFRunLoopSourceIsValid(emptySource),
                RunLoop.current.run(mode: .default, before: .distantFuture)
            { }
        }
        DispatchQueue.global().async(execute: workItem)
        lock.lock(whenCondition: 1)
        let runLoop = holder.value.unsafelyUnwrapped
        lock.unlock(withCondition: 0)
        self.cfRunLoop = runLoop.getCFRunLoop()
        self.source = emptySource
        self.config = config
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
        let timer:Timer
        if config.keepAliveUntilFinish {
            timer = .init(fire: date.date, interval: interval.timeInterval, repeats: true) { _ in
                action()
                /// retain self until task is submitted task is finished
                self.doNothing()
            }
        } else {
            timer = .init(fire: date.date, interval: interval.timeInterval, repeats: true) { _ in action() }
        }
        timer.tolerance = tolerance.timeInterval
        let cfTimer = timer as CFRunLoopTimer
        CFRunLoopAddTimer(cfRunLoop, cfTimer, .defaultMode)
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
        let timer:Timer
        if config.keepAliveUntilFinish {
            timer = .init(fire: date.date, interval: 0, repeats: false) { _ in
                action()
                /// retain self until task is submitted task is finished
                self.doNothing()
            }
        } else {
            timer = .init(fire: date.date, interval: 0, repeats: false) { _ in action() }
        }
        timer.tolerance = tolerance.timeInterval
        CFRunLoopAddTimer(cfRunLoop, timer as CFRunLoopTimer, .defaultMode)
    }
    
    @inlinable
    nonisolated
    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        if config.keepAliveUntilFinish {
            CFRunLoopPerformBlock(cfRunLoop, CFRunLoopMode.defaultMode.rawValue) {
                action()
                /// retain self until task is submitted task is finished
                self.doNothing()
            }
        } else {
            CFRunLoopPerformBlock(cfRunLoop, CFRunLoopMode.defaultMode.rawValue, action)
        }
        if CFRunLoopIsWaiting(cfRunLoop) {
            CFRunLoopWakeUp(cfRunLoop)
        }
    }
    
    nonisolated
    public var now: SchedulerTimeType { .init(Date()) }
    
    nonisolated
    public var minimumTolerance: SchedulerTimeType.Stride { 0.0 }
    
    public func scheduleTask<T>(_ block: @escaping () throws -> T) async rethrows -> T {
        let result:Result<T,Error> = await withUnsafeContinuation{ continuation in
            CFRunLoopPerformBlock(cfRunLoop, CFRunLoopMode.defaultMode.rawValue) {
                continuation.resume(returning: .init(catching: { try block() }))
            }
            if CFRunLoopIsWaiting(cfRunLoop) {
                CFRunLoopWakeUp(cfRunLoop)
            }
        }
        switch result {
        case .success(let success):
            return success
        case .failure:
            try result._rethrowOrFail()
        }
    }
    
    @usableFromInline
    @Sendable
    nonisolated
    internal func doNothing() { }
    
}


public extension RunLoopScheduler {
    
    struct Configuration {
        
        public var qos:DispatchQoS = .init(qosClass: .background, relativePriority: -15)
        /** whether to keep the scheduler alive until submitted tasks are finished */
        public var keepAliveUntilFinish = true
        
        @inlinable
        public init(qos: DispatchQoS =  .init(qosClass: .background, relativePriority: -15), keepAliveUntilFinish: Bool = true) {
            self.qos = qos
            self.keepAliveUntilFinish = keepAliveUntilFinish
        }
    }
    
}

extension RunLoopScheduler.Configuration: Hashable {
    
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(qos.qosClass)
        hasher.combine(qos.relativePriority)
        hasher.combine(keepAliveUntilFinish)
    }
    
    
}
