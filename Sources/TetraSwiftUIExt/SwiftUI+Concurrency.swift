//
//  SwiftUI+Concurrency.swift
//  
//
//  Created by pbk on 2022/12/08.
//

import Foundation
import _Concurrency
#if canImport(SwiftUI)
import SwiftUI

@usableFromInline
struct TaskModifier: ViewModifier {
    
    @usableFromInline
    init(priority:TaskPriority, action:@escaping @Sendable () async -> Void) {
        self.priority = priority
        self.action = action
    }
    
    @usableFromInline
    var priority: TaskPriority
    
    @usableFromInline
    var action: @Sendable () async -> Void
    
    @State private var task: Task<Void,Never>?
    
    @usableFromInline
    func body(content: Content) -> some View {
        content
            .onAppear{
                task?.cancel()
                task = Task(priority: priority, operation: action)
            }
            .onDisappear{
                task?.cancel()
                task = nil
            }
    }
}


@available(iOS 14.0, tvOS 14.0, macCatalyst 14.0, macOS 11.0, watchOS 7.0, *)
@usableFromInline
struct TaskIdentityModifer<T:Equatable>: ViewModifier {

    @usableFromInline
    init(id:T, priority:TaskPriority, action:@escaping @Sendable () async -> Void) {
        self.id = id
        self.priority = priority
        self.action = action
    }
    
    @usableFromInline
    var id:T

    @usableFromInline
    var priority: TaskPriority

    @usableFromInline
    var action: @Sendable () async -> Void

    @State private var task: Task<Void,Never>?
    
    @usableFromInline
    func body(content: Content) -> some View {
        content
            .onChange(of: id) { newValue in
                task?.cancel()
                task = Task(priority: priority, operation: action)
            }
            .onAppear{
                task?.cancel()
                task = Task(priority: priority, operation: action)
            }
            .onDisappear{
                task?.cancel()
                task = nil
            }
    }
    
}


@available(iOS, deprecated: 15, renamed: "task")
@available(tvOS, deprecated: 15, message: "task")
@available(macCatalyst, deprecated: 15, message: "task")
@available(macOS, deprecated: 12, message: "task")
@available(watchOS, deprecated: 8, message: "task")
public extension View {
    
    @available(iOS 14.0, tvOS 14.0, macCatalyst 14.0, macOS 11.0, watchOS 7.0, *)
    @inlinable
    @ViewBuilder
    func async<T:Equatable>(id value: T, priority: TaskPriority = .userInitiated, _ action: @Sendable @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            task(id: value, priority: priority, action)
        } else {
            modifier(TaskIdentityModifer(id: value, priority: priority, action: action))
        }
    }

    @inlinable
    @ViewBuilder
    func async(priority: TaskPriority = .userInitiated, _ action: @Sendable @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            task(priority: priority, action)
        } else {
            modifier(TaskModifier(priority: priority, action: action))
        }
    }
    
}


#endif
