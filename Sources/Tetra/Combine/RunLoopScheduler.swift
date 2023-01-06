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
    
    
    private init(runLoop:CFRunLoop, source:CFRunLoopSource) {
        self.cfRunLoop = runLoop
        self.source = source
        self.config = .init()
    }

    deinit {
        CFRunLoopSourceInvalidate(source)
    }
    
    public init(async: Void = (), config: Configuration = .init()) async {
        var nullContext = CFRunLoopSourceContext()
        nullContext.version = 0
        nullContext.cancel = { _, runLoop, _ in
            guard let runLoop else { return }
            CFRunLoopStop(runLoop)
        }
        let threadQos = config.threadQos
        let priority = config.threadPriority
        let emptySource = CFRunLoopSourceCreate(nil, 0, &nullContext).unsafelyUnwrapped
        let runLoop = await withUnsafeContinuation{ continuation in
            let workerThread = Thread {
                continuation.resume(returning: RunLoop.current.getCFRunLoop())
                Thread.setThreadPriority(priority)
                CFRunLoopAddSource(CFRunLoopGetCurrent(), emptySource, .defaultMode)
                while
                    CFRunLoopSourceIsValid(emptySource),
                    RunLoop.current.run(mode: .default, before: .distantFuture)
                { }
            }
            workerThread.threadPriority = priority
            workerThread.qualityOfService = threadQos
            workerThread.start()
        }
        self.cfRunLoop = runLoop
        self.source = emptySource
        self.config = config
    }
    
    /**
     Create Scheduler in sync
     
     Create new Thread and run the CFRunLoop of that Thread., when RunLoop stops and Scheduler is
     deinitialized. This initializer blocks the current thread until the Scheduler is ready.
     */
    public init(sync: Void = (), config: Configuration = .init()) {
        let reference = UnsafeMutablePointer<CFRunLoop>.allocate(capacity: 1)
        defer { reference.deallocate() }
        var nullContext = CFRunLoopSourceContext()
        nullContext.cancel = { _, runLoop, _ in
            guard let runLoop else { return }
            CFRunLoopStop(runLoop)
        }
        nullContext.version = 0
        let emptySource = CFRunLoopSourceCreate(nil, 0, &nullContext).unsafelyUnwrapped
        let condition = NSCondition()
        
        /** weak or unowned reference is needed, cause strong reference will be retained unitl runLoop ends.
         */
        let priority = config.threadPriority
        let workerThread = Thread { [weak condition] in
            condition.unsafelyUnwrapped.withLock {
                reference.initialize(to: RunLoop.current.getCFRunLoop())
                condition.unsafelyUnwrapped.signal()
            }

            /** without explicit nil assignment iOS 16.2 instrument tells me `condition`  is leaked even with weak/unowned reference.
             */
            condition = nil
            Thread.setThreadPriority(priority)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), emptySource, .defaultMode)
            while
                CFRunLoopSourceIsValid(emptySource),
                RunLoop.current.run(mode: .default, before: .distantFuture)
            { }
        }
        workerThread.qualityOfService = config.threadQos
        let runLoop = condition.withLock {
            workerThread.start()
            condition.wait()
            return reference.move()
        }
        self.cfRunLoop = runLoop
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
                /// retain self until submitted task is finished
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
                /// retain self until submitted task is finished
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
                /// retain self until submitted task is finished
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
        public init(qos: DispatchQoS =  .init(qosClass: .default, relativePriority: -15), keepAliveUntilFinish: Bool = true) {
            self.qos = qos
            self.keepAliveUntilFinish = keepAliveUntilFinish
        }
    }
    
}

extension RunLoopScheduler.Configuration: Hashable, @unchecked Sendable {
    
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(qos.qosClass)
        hasher.combine(qos.relativePriority)
        hasher.combine(keepAliveUntilFinish)
    }
    
    internal var threadQos:QualityOfService {
        switch self.qos.qosClass {
        
        case .background:
            return .background
        case .utility:
            return .utility
        case .default:
            return .default
        case .userInitiated:
            return .userInitiated
        case .userInteractive:
            return .userInteractive
        case .unspecified:
            return .default
        @unknown default:
            return Thread.current.qualityOfService
        }
    }
    
    internal var threadPriority:Double {
        precondition((-15...0).contains(qos.relativePriority), "relativePriority should be in -15...0")
        return Double((15 + qos.relativePriority) / 30)
    }
    
}
