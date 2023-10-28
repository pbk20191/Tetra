//
//  DispatchSerialExecutor.swift
//
//
//  Created by 박병관 on 10/14/23.
//

import Foundation
import Dispatch

final class DispatchQueueExeuctor: SerialExecutor {
    
    let queue:DispatchQueue
    
    init(rootQueue: DispatchQueue) {
        #if canImport(Darwin)
        // DispatchSerialQueue and DispatchWorkloop conforms to SerialExecutor in runtime so lets use runtime check
        if (rootQueue is any SerialExecutor || rootQueue is DispatchSerialQueue || rootQueue is DispatchWorkloop) {
            self.queue = rootQueue
        } else {
            // retarget the queue for safety if not main queue
            if rootQueue !== DispatchQueue.main {
                let serialQueue = DispatchQueue(label: rootQueue.label, target: rootQueue)
                self.queue = serialQueue
            } else {
                self.queue = rootQueue
            }
        }
        #else
        // retarget the queue for safety if not main queue
        if rootQueue !== DispatchQueue.main {
            let serialQueue = DispatchQueue(label: rootQueue.label, target: rootQueue)
            self.queue = serialQueue
        } else {
            self.queue = rootQueue
        }
        #endif
    }
    
    init(
        label: String,
        qos: DispatchQoS = .unspecified,
        attributes: DispatchQueue.Attributes = [],
        autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit,
        target:DispatchQueue? = nil
    ) {
        precondition(!attributes.contains(.initiallyInactive), "dispatch queue can not be inactive")
        precondition(!attributes.contains(.concurrent), "dispatch queue can not be concurrent")
        let queue = DispatchQueue(label: label, qos: qos, attributes: attributes, autoreleaseFrequency: autoreleaseFrequency, target: target)
        self.queue = queue
    }
  
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        if let executor = queue as? any SerialExecutor {
            return executor.asUnownedSerialExecutor()
        }
        if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
            return .init(complexEquality: self)
        } else {
            return .init(ordinary: self)
        }
    }
    
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    func enqueue(_ job: UnownedJob) {
        if let executor = queue as? any SerialExecutor {
            if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
                executor.enqueue(ExecutorJob(job))
                return
            }
            return executor.enqueue(job)
        }
        queue.async {
            job.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }
#else
    func enqueue(_ job: consuming ExecutorJob) {
        if let executor = queue as? any SerialExecutor {
            return executor.enqueue(job)
        }
        let unownedJob = UnownedJob(job)
        queue.async {
            unownedJob.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }
#endif

    func isSameExclusiveExecutionContext(other: DispatchQueueExeuctor) -> Bool {
        guard let lhs = queue as? any SerialExecutor,
              let rhs = queue as? any SerialExecutor,
              let result = lhs.evaluteContext(rhs)
        else {
            return queue === other.queue
        }
        return result
    }
    
}



extension SerialExecutor {
    
    @usableFromInline
    internal func evaluteContext(_ other: any SerialExecutor) -> Bool? {
        guard let other = other as? Self else {
            return nil
        }
        if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
            return isSameExclusiveExecutionContext(other: other)
        } else {
            return nil
        }
    }
}
