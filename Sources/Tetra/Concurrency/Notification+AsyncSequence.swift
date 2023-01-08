//
//  Notification+AsyncSequence.swift
//  
//
//  Created by pbk on 2022/12/09.
//

import Foundation
import _Concurrency


@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
public extension NotificationCenter {
    
    
    @available(iOS, introduced: 13.0, deprecated: 15.0, renamed: "notifications")
    @available(tvOS, introduced: 13.0, deprecated: 15.0, renamed: "notifications")
    @available(macCatalyst, introduced: 13.0, deprecated: 15.0, renamed: "notifications")
    @available(watchOS, introduced: 6.0, deprecated: 8.0, renamed: "notifications")
    @available(macOS, introduced: 10.15, deprecated: 12.0, renamed: "notifications")
    func sequence(named:Notification.Name, object:AnyObject? = nil) -> WrappedAsyncSequence<Notification> {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            return WrappedAsyncSequence(base: self.notifications(named: named, object: object))
        } else {
            return WrappedAsyncSequence(base: NotificationSequence(center: self, named: named, object: object))
        }
    }
    
}

@available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *)
extension NotificationCenter.Notifications.AsyncIterator: NonThrowingAsyncIteratorProtocol {}

public final class NotificationSequence: AsyncSequence {
    
    public typealias Element = Notification
    public typealias AsyncIterator = Iterator
    
    public func makeAsyncIterator() -> Iterator {
        Iterator(parent: self)
    }
    
    let center: NotificationCenter
    private let observer: NSObjectProtocol
    private let lock:some UnfairStateLock<NotficationState> = createUncheckedStateLock(uncheckedState: NotficationState())
    
    public struct Iterator: NonThrowingAsyncIteratorProtocol {
        public typealias Element = Notification
        
        let parent:NotificationSequence
        
        public func next() async -> Notification? {
            await withTaskCancellationHandler(
                operation: parent.next,
                onCancel: parent.cancel
            )
        }

    }
    
    private struct NotficationState {
        var buffer:[Notification] = []
        var pending:[UnsafeContinuation<Notification?,Never>] = []
    }
    
    
    public init(
        center: NotificationCenter,
        named name: Notification.Name,
        object: AnyObject? = nil
    ) {
        
        self.center = center
        observer = center.addObserver(forName: name, object: object, queue: nil) { [lock] notification in
            lock.withLockUnchecked { state in
                let captured = state.pending.first

                if state.pending.isEmpty {
                    state.buffer.append(notification)
                } else {
                    state.pending.removeFirst()
                }
                return captured
            }?.resume(returning: notification)
        }
    }
    

    deinit {
        center.removeObserver(observer)
        lock.withLock {
            let continuation = $0.pending
            $0.buffer = []
            $0.pending = []
            return continuation
        }.forEach{ $0.resume(returning: nil) }
    }
    
    @Sendable
    func cancel() {
        lock.withLock{
            let captured = $0.pending
            $0.pending = []
            return captured
        }.forEach{
            $0.resume(returning: nil)
        }
    }
    
    func next() async -> Notification? {
        await withUnsafeContinuation { continuation in
            let notification: Notification? = lock.withLockUnchecked { state in
                if state.buffer.isEmpty {
                    state.pending.append(continuation)
                    return nil
                } else {
                    return state.buffer.removeFirst()
                }
            }
            if let notification {
                continuation.resume(returning: notification)
            }
        }
    }
    
}
