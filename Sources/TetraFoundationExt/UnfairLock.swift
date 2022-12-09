//
//  UnfairLock.swift
//  
//
//  Created by pbk on 2022/12/09.
//

import Foundation
import os

@available(iOS, introduced: 10.0, deprecated: 16.0, renamed: "OSAllocatedUnfairLock")
@available(tvOS, introduced: 10.0, deprecated: 16.0, renamed: "OSAllocatedUnfairLock")
@available(macCatalyst, introduced: 13.1, deprecated: 16.0, renamed: "OSAllocatedUnfairLock")
@available(watchOS, introduced: 3.0, deprecated: 9.0, renamed: "OSAllocatedUnfairLock")
@available(macOS, introduced: 10.12, deprecated: 13.0, renamed: "OSAllocatedUnfairLock")
public final class UnfairLock: NSObject, NSLocking, Sendable {
    
    private let ptr:os_unfair_lock_t
    
    public override init() {
        ptr = .allocate(capacity: 1)
        ptr.initialize(to: .init())
        super.init()
    }
    
    deinit {
        ptr.deinitialize(count: 1)
        ptr.deallocate()
    }
    /**
     Attempts to acquire a lock, blocking a thread’s execution until the lock can be acquire

     An application protects a critical section of code by requiring a thread to acquire a lock before executing the code. Once the critical section is completed, the thread relinquishes the lock by invoking unlock().
    */
    @Sendable
    @available(*, noasync, message: "Use async-safe scoped locking instead")
    public func lock() {
        os_unfair_lock_lock(ptr)
    }
    
    /**
     Relinquishes a previously acquired lock.
     
     */
    @Sendable
    @available(*, noasync, message: "Use async-safe scoped locking instead")
    public func unlock() {
        os_unfair_lock_unlock(ptr)
    }
    
    /**
     Attempts to acquire a lock without regard to the receiver’s condition.
     - Returns: true if the lock could be acquired, false otherwise.
     
     This method returns immediately.
     
    */
    @available(*, noasync, message: "Use async-safe scoped locking instead")
    @Sendable @objc
    public func lockIfAvailable() -> Bool {
        os_unfair_lock_trylock(ptr)
    }
    
    @Sendable
    public func precondition(_ condition: Ownership) {
        switch condition {
        case .owner:
            os_unfair_lock_assert_not_owner(ptr)
        case .notOwner:
            os_unfair_lock_assert_owner(ptr)
        }
    }
    
    @frozen
    public enum Ownership: Sendable, Hashable {
        case owner
        case notOwner
    }
    
}
