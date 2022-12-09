//
//  SchedulerTimePublisher.swift
//  
//
//  Created by pbk on 2022/12/09.
//

import Foundation
import Combine



public extension Combine.Scheduler {
    
    func publish(every: SchedulerTimeType.Stride, _ tolerance: SchedulerTimeType.Stride? = nil, _ options: SchedulerOptions? = nil) -> SchedulerTimePublisher<Self> {
        .init(self, interval: every, options, tolerance)
    }

}


public final class SchedulerTimePublisher<S:Scheduler>: ConnectablePublisher {
    
    public func connect() -> Cancellable {
        subscription.schedule()
        return subscription
    }
    
    public func receive<Sub>(subscriber: Sub) where Sub : Subscriber, Never == Sub.Failure, S.SchedulerTimeType == Sub.Input {

        subscription.addSubscriber(subscriber)
    }
    
    
    public typealias Output = S.SchedulerTimeType
    public typealias Failure = Never
    
    var scheduler:S {
        subscription.scheduler
    }
    
    var interval:S.SchedulerTimeType.Stride {
        subscription.interval
    }
    
    var options:S.SchedulerOptions? {
        subscription.options
    }
    
    var tolerance:S.SchedulerTimeType.Stride? {
        subscription.tolerance
    }
    
    private let subscription:SchedulerTimerSubscription<S>
    
    public init(_ scheduler: S, interval: S.SchedulerTimeType.Stride, _ options: S.SchedulerOptions? = nil, _ tolerance:S.SchedulerTimeType.Stride? = nil) {
        self.subscription = SchedulerTimerSubscription(scheduler: scheduler, interval: interval, options: options, tolerance: tolerance)
    }
}

internal final class SchedulerTimerSubscription<S:Scheduler>: Subscription, CustomStringConvertible, CustomReflectable, CustomPlaygroundDisplayConvertible {

    let scheduler:S
    let interval:S.SchedulerTimeType.Stride
    let options:S.SchedulerOptions?
    let tolerance:S.SchedulerTimeType.Stride?
    private var token:AnyCancellable?
    private let lock = UnfairLock()
    private var subscribers:[AnySubscriber<S.SchedulerTimeType,Never>] = []
    private var request = Subscribers.Demand.none
    
    fileprivate init(scheduler: S, interval: S.SchedulerTimeType.Stride, options: S.SchedulerOptions? = nil, tolerance:S.SchedulerTimeType.Stride?) {
        self.scheduler = scheduler
        self.interval = interval
        self.options = options
        self.tolerance = tolerance
    }
    
    func schedule() {
        lock.withLock {
            if token != nil {
                return
            }
            let cancellable = scheduler.schedule(
                after: scheduler.now,
                interval: interval,
                tolerance: tolerance ?? scheduler.minimumTolerance,
                options: options
            ) { [unowned self] in
                fire()
            }
            token = AnyCancellable(cancellable)
        }

    }
    
    private func fire() {
        let time = scheduler.now
        var isEmpty = false
        let snapShot = lock.withLock {
            if request > .none {
                request -= 1
            } else {
                isEmpty = true
            }
            return subscribers
        }
        guard !isEmpty else { return }
        let extra = snapShot.map{ $0.receive(time) }.reduce(.none, +)
        guard extra > .none else { return }
        lock.withLock {
            request += extra
        }
    }
    
    func request(_ demand: Subscribers.Demand) {
        lock.withLock {
            request += demand
        }
    }
    
    func cancel() {
        lock.withLock {
            token = nil
            subscribers = []
            request = .none
        }
    }
    
    func addSubscriber<Sub:Subscriber>(_ sub:Sub) where Sub.Input == S.SchedulerTimeType, Sub.Failure == Never {
        lock.withLock {
            subscribers.append(.init(sub))
        }
        sub.receive(subscription: self)
    }

    
    var description: String {
        "SchedulerTimerSubscription<\(type(of: scheduler))>"
    }
    
    var customMirror: Mirror {
        Mirror(self, children: [
            "scheduler": scheduler,
            "interval": interval
        ])
    }
    
    var playgroundDescription: Any { description }
    
}
