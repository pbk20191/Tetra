//
//  RefreshableScrollView.swift
//
//
//  Created by pbk on 2022/09/30.
//

import Foundation
import SwiftUI
import Combine

@available(iOS, deprecated: 16, renamed: "ScrollView")
@available(tvOS, deprecated: 16, renamed: "ScrollView")
@available(macCatalyst, deprecated: 16, renamed: "ScrollView")
@available(macOS, deprecated: 13, renamed: "ScrollView")
@available(watchOS, deprecated: 9, renamed: "ScrollView")
public struct RefreshableScrollView<Content:View>: View {
    
    @State private var task:Task<Void,Never>? = nil
    @State private var flag = false
    
    public var content:Content
    public var axes: Axis.Set = .vertical
    public var showsIndicators: Bool = true
    
    
    public var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
#if os(iOS) || targetEnvironment(macCatalyst)
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                content
            } else if #available(iOS 15.0, macCatalyst 15.0, *) {
                content.background(
                    RefreshControlHostingView1(task: $task, refreshing: $flag)
                        .frame(width: 0, height: 0)
                )
            } else {
                content.background(
                    RefreshControlHostingView2(task: $task, refreshing: $flag)
                        .frame(width: 0, height: 0)
                )
            }
#else
            content
#endif

        }
        .onDisappear{
            task?.cancel()
            task = nil
            flag = false
        }
    }
    
    @inlinable
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.axes = axes
        self.showsIndicators = showsIndicators
    }
    
}

public extension View {
    
    @available(iOS, deprecated: 16, renamed: "refreshable")
    @available(tvOS, deprecated: 16, renamed: "refreshable")
    @available(macCatalyst, deprecated: 16, renamed: "refreshable")
    @available(macOS, deprecated: 13, renamed: "refreshable")
    @available(watchOS, deprecated: 9, renamed: "refreshable")
    @inlinable
    @ViewBuilder
    func refreshControl(action: @escaping @Sendable () async -> Void) -> some View {
        if #available(iOS 15.0, tvOS 15.0, macOS 12.0, macCatalyst 15.0, watchOS 8.0, *) {
            self.refreshable(action: action)
        } else {
            self.environment(\.refreshControl, .init(action: action))
        }
    }
    
}

@available(iOS 15.0, tvOS 15.0, macOS 12.0, macCatalyst 15.0, watchOS 8.0, *)
@usableFromInline
struct RefreshControlHostingView1: View {
    
    @Environment(\.refresh) private var refresh
    @Binding var task:Task<Void,Never>?
    @Binding var refreshing:Bool
    
    @usableFromInline
    var body: some View {
        #if os(iOS) || targetEnvironment(macCatalyst)
        if let refresh {
            ScrollRefreshImp(task: $task, refreshing: refreshing) {
                refreshing = true
                await refresh()
                refreshing = false
            }
        }
        #else
        EmptyView()
        #endif
    }
}

@usableFromInline
struct RefreshControlHostingView2: View {
    
    @Environment(\.refreshControl) private var refreshControl
    @Binding var task:Task<Void,Never>?
    @Binding var refreshing:Bool
    
    @usableFromInline
    var body: some View {
        #if os(iOS) || targetEnvironment(macCatalyst)
        if let refresh = refreshControl {
            ScrollRefreshImp(task: $task, refreshing: refreshing) {
                refreshing = true
                await refresh.action()
                refreshing = false
            }
        }
        #else
        EmptyView()
        #endif
    }
}

struct RefreshControlKey: EnvironmentKey {
    static var defaultValue: RefreshableControl? { nil }
}

public struct RefreshableControl {
    
    internal(set) public var action:@Sendable () async -> Void

    @usableFromInline
    init(action: @Sendable @escaping () async -> Void) {
        self.action = action
    }
    
}

extension EnvironmentValues {
    @usableFromInline
    var refreshControl: RefreshableControl? {
        get {
            return self[RefreshControlKey.self]
        }
        set {
            self[RefreshControlKey.self] = newValue
        }
        
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit

public struct ScrollRefreshImp: UIViewRepresentable {

    public typealias UIViewType = UIView
    public typealias Coordinator = RefreshingCoordinator
    @usableFromInline
    @Binding var task:Task<Void,Never>?
    @usableFromInline
    var refreshing:Bool
    @usableFromInline
    let operation:@Sendable () async -> Void
    
    @usableFromInline
    internal init(
        task: Binding<Task<Void, Never>?>,
        refreshing: Bool,
        operation: @escaping @Sendable () async -> Void
    ) {
        self._task = task
        self.refreshing = refreshing
        self.operation = operation
    }
    
    @inlinable
    public func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(parent: self)
        return coordinator
    }
    
    @inlinable
    public func makeUIView(context: Context) -> UIViewType {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isHidden = true
        context.coordinator.control.addTarget(context.coordinator, action: #selector(RefreshingCoordinator.refresh), for: .valueChanged)
        Task{ @MainActor in
            await Task.yield()
            let scrollView = sequence(first: view, next: \.superview).first{ $0 is UIScrollView } as? UIScrollView
            if let scrollView, !(scrollView is UITableView) {
                scrollView.refreshControl = context.coordinator.control
            }
        }
        return view
    }
    
    @inlinable
    public func updateUIView(_ uiView: UIViewType, context: Context) {
        print(#function)
        context.coordinator.parent = self
        if !refreshing && context.coordinator.control.isRefreshing {
            context.coordinator.control.endRefreshing()
        } else if refreshing && !context.coordinator.control.isRefreshing {
            context.coordinator.control.beginRefreshing()
        }
    }
    
    @inlinable
    public static func dismantleUIView(_ uiView: UIViewType, coordinator: Coordinator) {
        print("RefreshImp \(#function)")
        let scrollView = sequence(first: coordinator.control, next: \.superview).first{ $0 is UIScrollView } as? UIScrollView
        if let scrollView, scrollView.refreshControl == coordinator.control {
            scrollView.refreshControl = nil
        }
        coordinator.parent.task?.cancel()
    }
    
    
}

@MainActor
public final class RefreshingCoordinator: NSObject {
    
    @usableFromInline
    internal init(parent: ScrollRefreshImp) {
        self.parent = parent
        self.control = UIRefreshControl()
        super.init()
    }
    
    @usableFromInline
    let control:UIRefreshControl
    @usableFromInline
    var parent:ScrollRefreshImp
    
    @usableFromInline
    @objc func refresh() {
        parent.task?.cancel()
        parent.task = Task(operation: parent.operation)
    }
    
}
#endif
