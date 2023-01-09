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
 
 - important: Memory leaks found in instrument from this class are not acually leaked and they will be released as soon as `RunLoopScheduler`'s `Thread` terminate.
 
 */
public final class RunLoopScheduler: Scheduler, @unchecked Sendable, Hashable {
    
    public static func == (lhs: RunLoopScheduler, rhs: RunLoopScheduler) -> Bool {
        lhs.cfRunLoop == rhs.cfRunLoop && lhs.source == rhs.source
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(cfRunLoop)
        hasher.combine(source)
    }
    

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
        
        let emptySource = CFRunLoopSourceCreate(nil, 0, &nullContext).unsafelyUnwrapped
        let runLoop = await withUnsafeContinuation{ continuation in
            let runner = RunLoopRunner(emptySource) {
                continuation.resume(returning: $0)
            }
            let workerThread = Thread(target: runner, selector: #selector(runner.main), object: nil)
            workerThread.qualityOfService = config.qos
            workerThread.start()
        }
        self.cfRunLoop = runLoop
        self.source = emptySource
        self.config = config
    }
    
    /**
     Create Scheduler in sync
     
     Create new Thread and run the CFRunLoop of that Thread. This initializer blocks the current thread until the Scheduler is ready.
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
        let runner = RunLoopRunner(emptySource) {
            reference.initialize(to: $0)
            condition.withLock {
                condition.signal()
            }
        }
        let workerThread = Thread(target: runner, selector: #selector(runner.main), object: nil)
        workerThread.qualityOfService = config.qos
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
        CFRunLoopAddTimer(cfRunLoop, cfTimer, .commonModes)
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
        CFRunLoopAddTimer(cfRunLoop, timer as CFRunLoopTimer, .commonModes)
    }
    
    @inlinable
    nonisolated
    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        if config.keepAliveUntilFinish {
            CFRunLoopPerformBlock(cfRunLoop, CFRunLoopMode.commonModes.rawValue) {
                action()
                /// retain self until submitted task is finished
                self.doNothing()
            }
        } else {
            CFRunLoopPerformBlock(cfRunLoop, CFRunLoopMode.commonModes.rawValue, action)
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
            CFRunLoopPerformBlock(cfRunLoop, CFRunLoopMode.commonModes.rawValue) {
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
    
    private struct RunnerParameter {
        let source:CFRunLoopSource
        let completion:(CFRunLoop) -> ()
    }
    
    private final class RunLoopRunner {
        
        private var parameter:RunnerParameter?
        
        @objc
        func main() {
            let emptySource:CFRunLoopSource
            if let parameter {
                emptySource = parameter.source
                parameter.completion(CFRunLoopGetCurrent())
                self.parameter = nil
            } else {
                return
            }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), emptySource, .defaultMode)
            Thread.setThreadPriority(0)
            let cfObserver = CFRunLoopObserverCreateWithHandler(.none, CFRunLoopActivity.exit.rawValue, true, 0) {[weak emptySource] _, _ in
                guard let source = emptySource, CFRunLoopSourceIsValid(source) else {
                    let cfLoop = CFRunLoopGetCurrent().unsafelyUnwrapped
                    DispatchQueue.global().asyncAfter(deadline: .now().advanced(by: .milliseconds(10))) {
                        CFRunLoopStop(cfLoop)
                    }
                    return
                }
                
            }.unsafelyUnwrapped
            CFRunLoopAddObserver(CFRunLoopGetCurrent(), cfObserver, .commonModes)
            while
                CFRunLoopSourceIsValid(emptySource),
                RunLoop.current.run(mode: .default, before: .distantFuture)
            {  }
            CFRunLoopObserverInvalidate(cfObserver)
        }
        
        init(_ source:CFRunLoopSource, completionHandler: @escaping (CFRunLoop) -> ()) {
            self.parameter = .init(source: source, completion: completionHandler)
        }
        
    }
    
}


public extension RunLoopScheduler {
    
    struct Configuration: Hashable, Sendable {
        
        public var qos:QualityOfService = .default
        /** whether to keep the scheduler alive until submitted tasks are finished */
        public var keepAliveUntilFinish = true
        
        @inlinable
        public init(qos: QualityOfService = .default, keepAliveUntilFinish: Bool = true) {
            self.qos = qos
            self.keepAliveUntilFinish = keepAliveUntilFinish
        }
    }
    
}
