//
//  SchedulerTimePublisher.swift
//  
//
//  Created by pbk on 2022/12/19.
//

import Foundation
import Combine


public struct SchedulerTimePublisher<T:Scheduler>: Publisher {
    
    public typealias Output = T.SchedulerTimeType
    public typealias Failure = Never
    
    public var scheduler:T
    public var interval:T.SchedulerTimeType.Stride
    public var tolerance:T.SchedulerTimeType.Stride? = nil
    public var options:T.SchedulerOptions? = nil
    
    public init(scheduler: T, interval: T.SchedulerTimeType.Stride, tolerance: T.SchedulerTimeType.Stride? = nil, options: T.SchedulerOptions? = nil) {
        self.scheduler = scheduler
        self.interval = interval
        self.tolerance = tolerance
        self.options = options
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Output == S.Input {
        subscriber.receive(
            subscription: Inner(
                publisher: self, subscriber: subscriber
            )
        )
    }

    private struct State<S:Subscriber> where S.Input == Output, S.Failure == Failure {
        
        var started = false
        var subscriber:S? = nil
        var request:Subscribers.Demand = .none
        var token:AnyCancellable? = nil
        
    }
    
    final class Inner<S:Subscriber>: Subscription, CustomStringConvertible, CustomPlaygroundDisplayConvertible where S.Input == Output, S.Failure == Failure  {
        
        var description: String {
            "SchedulerTimer<\(type(of: publisher.scheduler))>"
        }
        
        var playgroundDescription: Any { description }
        
        private let publisher:SchedulerTimePublisher<T>
        private let lock:some UnfairStateLock<State<S>> = createUncheckedStateLock(uncheckedState: State<S>())
        
        init(publisher: SchedulerTimePublisher<T>, subscriber:S) {
            self.publisher = publisher
            lock.withLock{
                $0.subscriber = subscriber
            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            let shouldStart = lock.withLock{
                $0.request += demand
                if !$0.started {
                    $0.started = true
                    return true
                }
                return false
            }
            if shouldStart {
                let token = publisher.scheduler.schedule(after: publisher.scheduler.now, interval: publisher.interval, tolerance: publisher.tolerance ?? publisher.scheduler.minimumTolerance, options: publisher.options) { [weak self] in
                    self?.fire()
                }
                let oldValue = lock.withLock{
                    let oldValue = $0.token
                    $0.token = AnyCancellable(token)
                    return oldValue
                }
                let _ = oldValue
            }
        }
        
        private func fire() {
            let subscriber = lock.withLockUnchecked{
                if $0.request > .none {
                    $0.request -= 1
                    return $0.subscriber
                }
                return nil
            }
            if let demand = subscriber?.receive(publisher.scheduler.now), demand > .none {
                lock.withLock{
                    $0.request += demand
                }
            }
        }
        
        func cancel() {
            let token = lock.withLockUnchecked{
                let cancellable = $0.token
                $0.token = nil
                $0.request = .none
                return cancellable
            }
            let _ = token
        }
        
        
        
    }
    
}
