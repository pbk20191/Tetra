//
//  Notification+AsyncSequence.swift
//  
//
//  Created by pbk on 2022/12/09.
//

import Foundation
import _Concurrency

@available(iOS, introduced: 13.0, deprecated: 15.0, renamed: "notifications")
@available(tvOS, introduced: 13.0, deprecated: 15.0, renamed: "notifications")
@available(macCatalyst, introduced: 13.0, deprecated: 15.0, renamed: "notifications")
@available(watchOS, introduced: 6.0, deprecated: 8.0, renamed: "notifications")
@available(macOS, introduced: 10.15, deprecated: 12.0, renamed: "notifications")
@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
public extension NotificationCenter {
    
    func sequence(named:Notification.Name, object:AnyObject? = nil) -> NotificationSequence {
        NotificationSequence(center: self, name: named, object: object)
    }
}


@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
public struct NotificationSequence: AsyncTypedSequence {
    public typealias Element = Notification
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(center: center, name: name, object: object)
    }
    
    public struct AsyncIterator: AsyncTypedIteratorProtocol {
        
        let center:NotificationCenter
        let name:Notification.Name
        let object:AnyObject?
        
        private var token:NotficationSuspension? = nil
        
        mutating public func next() async -> Notification? {
            if let token {
                return await token.waitNotification()
            } else {
                let newToken = NotficationSuspension(center: center, name: name, object: object)
                token = newToken
                return await newToken.waitNotification()
            }
        }
        

        public typealias Element = Notification
        
        init(center: NotificationCenter, name: Notification.Name, object: AnyObject?) {
            self.center = center
            self.name = name
            self.object = object
        }
        
    }
    
    var center:NotificationCenter
    var name:Notification.Name
    var object:AnyObject?
    
    internal init(center: NotificationCenter = .default, name: Notification.Name, object: AnyObject? = nil) {
        self.center = center
        self.name = name
        self.object = object
        
    }
    
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
internal final class NotficationSuspension: CustomStringConvertible, CustomReflectable, CustomPlaygroundDisplayConvertible {
    
    var description: String { "NotficationSuspension(center: \(center), name: \(name), object: \(String(describing: object)))" }
    
    var customMirror: Mirror {
        var children:KeyValuePairs<String,Any> = [
            "center": center,
            "name":name
        ]
        if let object {
            children = [
                "center": center,
                "name":name,
                "object": object
            ]
        }
        return Mirror(self, children: children)
    }
    
    var playgroundDescription: Any { description }
    
    
    private let lock = NSLock()
    private var store = [UnsafeContinuation<Notification?,Never>]()
    let center:NotificationCenter
    let name:Notification.Name
    let object:AnyObject?
    
    init(center: NotificationCenter, name: Notification.Name, object: AnyObject?) {
        self.center = center
        self.name = name
        self.object = object
        center.addObserver(self, selector: #selector(receive), name: name, object: object)
    }
    
    func waitNotification() async -> Notification? {
        guard !Task.isCancelled else { return nil }
        return await withTaskCancellationHandler {
            await withUnsafeContinuation { continuation in
                lock.withLock {
                    store.append(continuation)
                }
            }
        } onCancel: {
            cancel()
        }

    }
    
    func cancel() {
        lock.withLock {
            let captured = store
            store = []
            return captured
        }.forEach{ $0.resume(returning: nil) }
        center.removeObserver(self, name: name, object: object)
    }
    
    @objc
    func receive(_ notification:Notification) {
        lock.withLock {
            let captured = store
            store = []
            return captured
        }.forEach{ $0.resume(returning: notification) }
    }
    
}
