//
//  CoreDataStack+Concurrency.swift
//  
//
//  Created by pbk on 2022/12/07.
//

import Foundation
import _Concurrency

#if canImport(CoreData)
import CoreData

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
public extension NSPersistentContainer {
    
    @available(iOS, introduced: 13.0, deprecated: 15.0, renamed: "performBackgroundTask(_:)")
    @available(tvOS, introduced: 13.0, deprecated: 15.0, renamed: "performBackgroundTask(_:)")
    @available(macCatalyst, introduced: 13.0, deprecated: 15.0, renamed: "performBackgroundTask(_:)")
    @available(watchOS, introduced: 6.0, deprecated: 8.0, renamed: "performBackgroundTask(_:)")
    @available(macOS, introduced: 10.15, deprecated: 12.0, renamed: "performBackgroundTask(_:)")
    @inlinable
    func performBackground<T>(body: @escaping (NSManagedObjectContext) throws -> T) async rethrows -> T {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            return try await performBackgroundTask(body)
        } else {
            return try await asyncPerformBackgroundTask(self, body)
        }
    }
    
}


@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
public extension NSManagedObjectContext {
    
    @available(iOS, introduced: 13.0, deprecated: 15.0, renamed: "perform(schedule:_:)")
    @available(tvOS, introduced: 13.0, deprecated: 15.0, renamed: "perform(schedule:_:)")
    @available(macCatalyst, introduced: 13.0, deprecated: 15.0, renamed: "perform(schedule:_:)")
    @available(watchOS, introduced: 6.0, deprecated: 8.0, renamed: "perform(schedule:_:)")
    @available(macOS, introduced: 10.15, deprecated: 12.0, renamed: "perform(schedule:_:)")
    @inlinable
    func withContext<T>(body: @escaping () throws -> T) async rethrows -> T {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            return try await perform(body)
        } else {
            return try await asyncPerform(self, body)
        }
    }
    
    @available(iOS, introduced: 13.0, deprecated: 15.0, renamed: "performAndWait(_:)")
    @available(tvOS, introduced: 13.0, deprecated: 15.0, renamed: "performAndWait(_:)")
    @available(macCatalyst, introduced: 13.0, deprecated: 15.0, renamed: "performAndWait(_:)")
    @available(watchOS, introduced: 6.0, deprecated: 8.0, renamed: "performAndWait(_:)")
    @available(macOS, introduced: 10.15, deprecated: 12.0, renamed: "performAndWait(_:)")
    @inlinable
    func withBlocking<T>(body: () throws -> T) rethrows -> T {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            return try performAndWait(body)
        } else {
            return try perfomBlocking(self, body)
        }
    }
    
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
public extension NSPersistentStoreCoordinator {
    
    @available(iOS, introduced: 13.0, deprecated: 15.0, renamed: "perform(_:)")
    @available(tvOS, introduced: 13.0, deprecated: 15.0, renamed: "perform(_:)")
    @available(macCatalyst, introduced: 13.0, deprecated: 15.0, renamed: "perform(_:)")
    @available(watchOS, introduced: 6.0, deprecated: 8.0, renamed: "perform(_:)")
    @available(macOS, introduced: 10.15, deprecated: 12.0, renamed: "perform(_:)")
    @inlinable
    func withContext<T>(body: @escaping () throws -> T) async rethrows -> T {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            return try await perform(body)
        } else {
            return try await asyncPerform(self, body)
        }
    }
    
    @available(iOS, introduced: 13.0, deprecated: 15.0, renamed: "performAndWait(_:)")
    @available(tvOS, introduced: 13.0, deprecated: 15.0, renamed: "performAndWait(_:)")
    @available(macCatalyst, introduced: 13.0, deprecated: 15.0, renamed: "performAndWait(_:)")
    @available(watchOS, introduced: 6.0, deprecated: 8.0, renamed: "performAndWait(_:)")
    @available(macOS, introduced: 10.15, deprecated: 12.0, renamed: "performAndWait(_:)")
    @inlinable
    func withBlocking<T>(body: () throws -> T) rethrows -> T {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            return try performAndWait(body)
        } else {
            return try perfomBlocking(self, body)
        }
    }
    
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
@usableFromInline
internal func asyncPerform<T>(_ coordinator:NSPersistentStoreCoordinator, _ block: @escaping () throws -> T) async rethrows -> T {
    let result:Result<T,Error>
    do {
        let value = try await withUnsafeThrowingContinuation { continuation in
            coordinator.perform {
                continuation.resume(with: Result{ try block() })
            }
        }
        result = .success(value)
    } catch {
        result = .failure(error)
    }
    switch result {
    case .success(let success):
        return success
    case .failure:
        try result._rethrowOrFail()
    }
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
@usableFromInline
internal func perfomBlocking<T>(_ coordinator:NSPersistentStoreCoordinator, _ block: () throws -> T) rethrows -> T {
    let reference = UnsafeMutablePointer<Result<T,Error>>.allocate(capacity: 1)
    defer { reference.deallocate() }
    coordinator.performAndWait {
        reference.initialize(to: Result{ try block() })
    }
    let result = reference.move()
    switch result {
    case .success(let value):
        return value
    case .failure:
        try result._rethrowOrFail()
    }
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
@usableFromInline
internal func asyncPerform<T>(_ context:NSManagedObjectContext, _ block: @escaping () throws -> T) async rethrows -> T {
    let result:Result<T,Error>
    do {
        let value = try await withUnsafeThrowingContinuation { continuation in
            context.perform {
                continuation.resume(with: Result{ try block() })
            }
        }
        result = .success(value)
    } catch {
        result = .failure(error)
    }
    switch result {
    case .success(let success):
        return success
    case .failure:
        try result._rethrowOrFail()
    }
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
@usableFromInline
internal func perfomBlocking<T>(_ context:NSManagedObjectContext, _ block: () throws -> T) rethrows -> T {
    let reference = UnsafeMutablePointer<Result<T,Error>>.allocate(capacity: 1)
    defer { reference.deallocate() }
    context.performAndWait {
        reference.initialize(to: Result{ try block() })
    }
    let result = reference.move()
    switch result {
    case .success(let value):
        return value
    case .failure:
        try result._rethrowOrFail()
    }
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, watchOS 6.0, macOS 10.15, *)
@usableFromInline
internal func asyncPerformBackgroundTask<T>(_ container:NSPersistentContainer, _ block: @escaping (NSManagedObjectContext) throws -> T) async rethrows -> T {
    let result:Result<T,Error>
    do {
        let value = try await withUnsafeThrowingContinuation { continuation in
            container.performBackgroundTask { newContext in
                continuation.resume(with: Result{ try block(newContext) })
            }
        }
        result = .success(value)
    } catch {
        result = .failure(error)
    }
    switch result {
    case .success(let success):
        return success
    case .failure:
        try result._rethrowOrFail()
    }
}

#endif
