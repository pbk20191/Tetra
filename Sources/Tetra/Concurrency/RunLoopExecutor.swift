//
//  RunLoopExecutor.swift
//
//
//  Created by 박병관 on 8/20/23.
//

import Foundation


internal struct RunLoopRunner: ~Copyable, @unchecked Sendable {
    
    internal let thread:Thread
    private let source:CFRunLoopSource
    
    fileprivate init(qos:QualityOfService = .default) {
        var context = CFRunLoopSourceContext()
        context.version = 0
        self.source = CFRunLoopSourceCreate(nil, 0, &context)
        self.thread = Thread{ [source] in
            guard RunLoop.current.currentMode == nil else { return }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.defaultMode)
            defer { CFRunLoopSourceInvalidate(source) }
            while CFRunLoopContainsSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.defaultMode),
                RunLoop.current.run(mode: .default, before: .distantFuture) {
                
            }
        }
        thread.name = "RunLoopSerialExecutor"
        thread.qualityOfService = qos
        thread.threadPriority = 0.0
        thread.start()
    }
    
    deinit {
        let source = source
        submit {
            CFRunLoopSourceInvalidate(source)
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
    }
    
    internal func submit(_ block: @Sendable @escaping () -> Void) {
        let job = Timer(timeInterval: 0, repeats: false) { _ in
            block()
        }
        job.perform(
            #selector(job.fire),
            on: thread,
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.common.rawValue]
        )
    }
    
    
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class RunLoopExecutor: SerialExecutor {

    internal let runner:RunLoopRunner
    
    public init(qos: QualityOfService = .default) {
        runner = .init(qos: qos)
    }
    
    public func enqueue(_ job: consuming ExecutorJob) {
        let ref = UnownedJob(job)
        let executor = self.asUnownedSerialExecutor()
        runner.submit {
            ref.runSynchronously(on: executor)
        }
    }

    
    public func isSameExclusiveExecutionContext(other: RunLoopExecutor) -> Bool {
        return runner.thread == other.runner.thread
    }
    

}

@available(macOS, deprecated: 14.0, renamed: "RunLoopExecutor")
@available(iOS, deprecated: 17.0, renamed: "RunLoopExecutor", message: "LegacyRunLoopExecutor is deprecated by MoveOnly Types use RunLoopExecutor instead")
@available(watchOS, deprecated: 10.0, renamed: "RunLoopExecutor", message: "LegacyRunLoopExecutor is deprecated by MoveOnly Types use RunLoopExecutor instead")
@available(tvOS, deprecated: 17.0, renamed: "RunLoopExecutor", message: "LegacyRunLoopExecutor is deprecated by MoveOnly Types use RunLoopExecutor instead")
public final class LegacyRunLoopExecutor: SerialExecutor {

    internal let runner:RunLoopRunner
    
    public init(qos:QualityOfService = .default) {
        runner = .init(qos: qos)
    }
    
    public func enqueue(_ job: UnownedJob) {
        let executor = UnownedSerialExecutor(ordinary: self)
        runner.submit {
            job.runSynchronously(on: executor)
        }
    }
    
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public func isSameExclusiveExecutionContext(other: LegacyRunLoopExecutor) -> Bool {
        return runner.thread == other.runner.thread
    }
    
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        return .init(ordinary: self)
    }

}


public func newRunLoopExecutor(qos: QualityOfService) -> some SerialExecutor {
    if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
        return RunLoopExecutor(qos: qos)
    } else {
        return LegacyRunLoopExecutor(qos: qos)
    }
}
