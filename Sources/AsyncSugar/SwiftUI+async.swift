//
//  File.swift
//  
//
//  Created by pbk on 2022/05/23.
//
#if canImport(SwiftUI)
import SwiftUI
import _Concurrency

//@available(iOS, introduced: 13.0, obsoleted: 15.0)
//@available(tvOS, introduced: 13.0, obsoleted: 15.0)
//@available(macCatalyst, introduced: 13.0, obsoleted: 15.0)
//@available(macOS, introduced: 10.15, obsoleted: 12.0)
//@available(watchOS, introduced: 6.0, obsoleted: 8.0)
private struct TaskModifier: ViewModifier {
    var priority: TaskPriority
    var action: @Sendable () async -> Void
    @State private var task: Task<Void,Never>?
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

//@available(iOS, introduced: 14.0, obsoleted: 15.0)
//@available(tvOS, introduced: 14.0, obsoleted: 15.0)
//@available(macCatalyst, introduced: 14.0, obsoleted: 15.0)
//@available(macOS, introduced: 11.0, obsoleted: 12.0)
//@available(watchOS, introduced: 7.0, obsoleted: 8.0)
@available(iOS 14.0, tvOS 14.0, macCatalyst 14.0, macOS 11.0, watchOS 7.0, *)
private struct TaskIdentityModifer<T:Equatable>: ViewModifier {
    var id:T
    var priority: TaskPriority
    var action: @Sendable () async -> Void
    @State private var task: Task<Void,Never>?
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
    @ViewBuilder
    func async<T:Equatable>(id value: T, priority: TaskPriority = .userInitiated, _ action: @Sendable @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, macOS 12.0, watchOS 8.0, *) {
            task(id: value, priority: priority, action)
        } else {
            modifier(TaskIdentityModifer(id: value, priority: priority, action: action))
        }
    }

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
