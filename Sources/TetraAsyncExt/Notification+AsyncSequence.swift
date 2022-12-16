//
//  Notification+AsyncSequence.swift
//  
//
//  Created by pbk on 2022/12/09.
//

import Foundation
import _Concurrency
import TetraFoundationExt

@available(iOS, introduced: 13.0, deprecated: 15.0, renamed: "notifications")
@available(tvOS, introduced: 13.0, deprecated: 15.0, renamed: "notifications")
@available(macCatalyst, introduced: 13.0, deprecated: 15.0, renamed: "notifications")
@available(watchOS, introduced: 6.0, deprecated: 8.0, renamed: "notifications")
@available(macOS, introduced: 10.15, deprecated: 12.0, renamed: "notifications")
@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
public extension NotificationCenter {
    
    func sequence(named:Notification.Name, object:AnyObject? = nil) -> NotificationSequence {
        NotificationSequence(center: self, named: named, object: object)
    }
    
}

public final class NotificationSequence: AsyncTypedSequence {
    
    public typealias Element = Notification
    public typealias AsyncIterator = Iterator
    
    public func makeAsyncIterator() -> Iterator {
        Iterator(parent: self)
    }
    
    let center:NotificationCenter
    private let lock = ManagedUnfairLock<NotficationState>(initialState: .init())
    
    public struct Iterator: AsyncTypedIteratorProtocol {
        public typealias Element = Notification
        
        let parent:NotificationSequence
        
        public func next() async -> Notification? {
            await withTaskCancellationHandler {
                await parent.await()
            } onCancel: {
                parent.cancel()
            }
        }
        

    }
    
    private struct NotficationState {
        var buffer:[Notification] = []
        var observer:Any! = nil
        var pending:[UnsafeContinuation<Notification?,Never>] = []
    }
    
    
    init(center: NotificationCenter, named name: Notification.Name, object: AnyObject? = nil) {
        self.center = center
        let token = center.addObserver(forName: name, object: object, queue: nil) { [lock] notification in
            lock.withLockUnchecked { state in
                if state.pending.isEmpty {
                    state.buffer.append(notification)
                }
                let captured = state.pending
                state.pending = []
                return captured
            }.forEach{
                $0.resume(returning: notification)
            }
        }
        lock.withLock {
            $0.observer = token
        }
    }
    

    deinit {
        let (pending, observer) = lock.withLockUnchecked {
            let continuation = $0.pending
            $0.buffer = []
            $0.pending = []
            return (continuation, $0.observer)
        }
        if let observer {
            center.removeObserver(observer)
        }
        pending.forEach{ $0.resume(returning: nil) }
    }
    
    func cancel() {
        lock.withLock{
            let captured = $0.pending
            $0.pending = []
            return captured
        }.forEach{
            $0.resume(returning: nil)
        }
    }
    
    func await() async -> Notification? {
        await withUnsafeContinuation { continuation in
            let notification = lock.withLockUnchecked { state in
                if state.buffer.isEmpty {
                    state.pending.append(continuation)
                    return nil as Notification?
                } else {
                    return state.buffer.removeFirst() as Notification?
                }
            }
            if let notification {
                continuation.resume(returning: notification)
            }
        }
    }
    
}
