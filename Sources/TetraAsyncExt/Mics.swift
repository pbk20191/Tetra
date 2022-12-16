//
//  mics.swift
//  
//
//  Created by pbk on 2022/12/08.
//

import Foundation
import Combine
import os

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
@preconcurrency
internal final class UnsafeReference<T:Sendable> {
    @usableFromInline
    var value:T?
}

@inline(__always)
@usableFromInline
internal func wrapRethrow<T>(body: () async throws -> T) async rethrows -> T {
    try await body()
}

internal enum SubscriptionStatus {
    case awaitingSubscription
    case subscribed(Subscription)
    case terminal
    
    var subscription:Subscription? {
        guard case .subscribed(let subscription) = self else {
            return nil
        }
        return subscription
    }
    
}

