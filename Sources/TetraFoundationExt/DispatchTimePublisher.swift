//
//  DispatchTimePublisher.swift
//  
//
//  Created by pbk on 2022/12/09.
//

import Foundation
import Dispatch
import Combine

public final class DispatchTimePublisher: ConnectablePublisher {
    
    public typealias Output = DispatchTime
    public typealias Failure = Never

    public var interval:TimeInterval { subscription.interval }
    public var leeway:DispatchTimeInterval { subscription.leeway }
    public var qos:DispatchQoS { subscription.qos }
    public var workFlags: DispatchWorkItemFlags { subscription.workFlags }
    private let subscription:DispatchTimeSubscription
    
    
    public init(
        interval: TimeInterval,
        leeway:DispatchTimeInterval = .nanoseconds(0),
        flags: DispatchSource.TimerFlags = [],
        qos:DispatchQoS = .unspecified,
        workFlags: DispatchWorkItemFlags = [],
        queue: DispatchQueue? = nil
    ) {
        self.subscription = DispatchTimeSubscription(
            interval: interval,
            leeway: leeway,
            qos: qos,
            workFlags: workFlags,
            flags: flags,
            queue: queue
        )
    }
    
    public func connect() -> Cancellable {
        subscription.schedule()
        return subscription
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, DispatchTime == S.Input {
        subscription.addSubscriber(subscriber)
    }
    
}

final internal class DispatchTimeSubscription: Subscription, CustomStringConvertible, CustomReflectable, CustomPlaygroundDisplayConvertible {
    
    let leeway:DispatchTimeInterval
    let interval:TimeInterval
    let qos:DispatchQoS
    let workFlags:DispatchWorkItemFlags
    private let lock = UnfairLock()
    private var request = Subscribers.Demand.none
    private var subscribers: [AnySubscriber<DispatchTime,Never>] = []
    private let timerSource:DispatchSourceTimer

    init(
        interval: TimeInterval,
        leeway: DispatchTimeInterval,
        qos: DispatchQoS,
        workFlags: DispatchWorkItemFlags,
        flags: DispatchSource.TimerFlags,
        queue: DispatchQueue?
    ) {
        self.leeway = leeway
        self.interval = interval
        self.qos = qos
        self.workFlags = workFlags
        self.timerSource = DispatchSource.makeTimerSource(flags: flags, queue: queue)
    }
    
    func request(_ demand: Subscribers.Demand) {
        lock.withLock {
            request += demand
        }
    }
    
    func schedule() {
        guard !timerSource.isCancelled else { return }
        timerSource.schedule(deadline: .now(), repeating: interval, leeway: leeway)
        timerSource.setEventHandler(qos: qos, flags: workFlags) { [unowned self] in
            fire()
        }
        timerSource.activate()
    }
    
    private func fire() {
        guard !self.timerSource.isCancelled else { return }
        let time = DispatchTime.now()
//        var isEmpty = false
//        let snapShot = lock.withLock {
//            if (request > .none) {
//                request -= 1
//            } else {
//                isEmpty = true
//            }
//            return subscribers
//        }
//        guard !isEmpty else { return }
//
//        let extra = snapShot.map{ $0.receive(time) }.reduce(.none, +)
//        guard extra > .none else { return }
//        lock.withLock {
//            request += extra
//        }

        lock.withLock {
            if request > .none {
                request -= 1
            } else {
                return
            }
            let extra = subscribers.map{ $0.receive(time) }.reduce(.none, +)
            request += extra
        }
    }
    
    func cancel() {
        timerSource.cancel()
        lock.withLock {
            subscribers = []
            request = .none
        }
    }
    
    
    func addSubscriber<S:Subscriber>(_ sub: S) where S.Failure == Never, S.Input == DispatchTime {
        lock.withLock {
            subscribers.append(.init(sub))
        }
        sub.receive(subscription: self)
    }
    
    var description: String { return "DispatchSourceTimer" }
    var playgroundDescription: Any { return description }
    var customMirror: Mirror {
        let demand = lock.withLock {
            return (request)
        }
        return Mirror(self, children: [
            "request":demand,
            "timerSource":timerSource
        ])
    }
}





