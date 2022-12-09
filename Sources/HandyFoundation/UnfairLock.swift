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
    
    @Sendable
    @available(*, noasync, message: "Use async-safe scoped locking instead")
    public func lock() {
        os_unfair_lock_lock(ptr)
    }
    
    @Sendable
    @available(*, noasync, message: "Use async-safe scoped locking instead")
    public func unlock() {
        os_unfair_lock_unlock(ptr)
    }
    
    @Sendable
    @available(*, noasync, message: "Use async-safe scoped locking instead")
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
