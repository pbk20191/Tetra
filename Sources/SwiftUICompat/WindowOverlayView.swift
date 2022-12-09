//
//  WindowOverlayView.swift
//  
//
//  Created by pbk on 2022/12/08.
//

import Foundation
import SwiftUI
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

@MainActor
@usableFromInline
final class OverlayWindow: UIWindow {
    
    @usableFromInline
    nonisolated
    override var canBecomeKey: Bool { false }
    
    @usableFromInline
    override func becomeKey() {
        super.becomeKey()
        print(#function)
    }
    
    @usableFromInline
    override func makeKey() {
        super.makeKey()
        print(#function)
    }
    
    @usableFromInline
    override func makeKeyAndVisible() {
        super.makeKeyAndVisible()
        print(#function)
    }
    
    @usableFromInline
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let targetView = super.hitTest(point, with: event) else { return nil }
        return rootViewController?.view === targetView ? nil : targetView
    }
    
    
}

@MainActor
@usableFromInline
final class WindowCallbackView: UIView {
    
    @usableFromInline
    var callBack:((UIWindowScene?) -> ())? = nil
    
    @usableFromInline
    override func didMoveToWindow() {
        super.didMoveToWindow()
        callBack?(window?.windowScene)
    }
    
    @usableFromInline
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        callBack?(newWindow?.windowScene)
    }
    
}



@usableFromInline
struct OverlayWindowHost<Content>: UIViewRepresentable where Content: View {
    
    @usableFromInline
    internal init(content: Content, isHidden: Bool, level: UIWindow.Level) {
        self.content = content
        self.isHidden = isHidden
        self.level = level
    }
    
    
    @usableFromInline
    typealias UIViewType = WindowCallbackView
    @usableFromInline
    typealias Coordinator = OverlayWindow
    
    var content:Content
    var isHidden:Bool
    var level:UIWindow.Level
    
    @usableFromInline
    func makeCoordinator() -> OverlayWindow {
        let window = OverlayWindow()
        window.isHidden = true
        window.backgroundColor = nil
        return window
    }
    
    @usableFromInline
    func makeUIView(context: Context) -> WindowCallbackView {
        let view = WindowCallbackView()
        let rootView = content.modifier(EnvironmentValueModifier(environment: context.environment))
        let vc = UIHostingController(rootView: rootView)
        view.callBack = { [weak coordinator = context.coordinator] scene in
            coordinator?.windowScene = scene
        }
        vc.view.backgroundColor = nil
        withTransaction(context.transaction) {
            context.coordinator.rootViewController = vc
        }
        return view
    }
    
    @usableFromInline
    func updateUIView(_ uiView: WindowCallbackView, context: Context) {
        uiView.callBack = { [weak coordinator = context.coordinator] scene in
            coordinator?.windowScene = scene
        }
        context.coordinator.isHidden = isHidden
        context.coordinator.isUserInteractionEnabled = context.environment.isEnabled
        let rootView = content.modifier(EnvironmentValueModifier(environment: context.environment))
        switch context.coordinator.rootViewController {
        case let vc as UIHostingController<ModifiedContent<Content,EnvironmentValueModifier>>:
            withTransaction(context.transaction) {
                vc.rootView = rootView
            }
        case .none:
            let vc = UIHostingController(rootView: rootView)
            vc.view.backgroundColor = nil
            withTransaction(context.transaction) {
                context.coordinator.rootViewController = vc
            }
        case let .some(some):
            assertionFailure("\(type(of: some)) is not recognized")
            let vc = UIHostingController(rootView: rootView)
            vc.view.backgroundColor = nil
            withTransaction(context.transaction) {
                context.coordinator.rootViewController = vc
            }
        }
    }
    
    @usableFromInline
    static func dismantleUIView(_ uiView: WindowCallbackView, coordinator: OverlayWindow) {
        
    }
    
}



@usableFromInline
struct EnvironmentValueModifier: ViewModifier {
    
    @usableFromInline
    var environment:EnvironmentValues
    
    @usableFromInline
    func body(content: Content) -> some View {
        if #available(iOS 14.0, tvOS 14.0, *) {
            content
                .preferredColorScheme(environment.colorScheme)
                .disabled(!environment.isEnabled)
                .font(environment.font)
                .environment(\.scenePhase, environment.scenePhase)
        } else {
            content
                .preferredColorScheme(environment.colorScheme)
                .disabled(!environment.isEnabled)
                .font(environment.font)
                
        }
          
    }
    
}

#endif

public struct WindowOverlayView<Content:View>: View {
    
    @usableFromInline
    internal init(level: CGFloat, isHidden: Bool, content: Content) {
        self.level = level
        self.isHidden = isHidden
        self.content = content
    }

    public var level:CGFloat
    public var isHidden:Bool
    public var content:Content
    
    @inlinable
    public var body: some View {
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        OverlayWindowHost(content: content, isHidden: isHidden, level: .init(level))
            .frame(width: 0, height: 0)
        #else
        EmptyView()
        #endif
    }
    
    
}

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
public extension WindowOverlayView where Content == EmptyView {
    
    @inlinable
    init() {
        self.init(level: 0, isHidden: true, content: .init())
    }
    
}

@available(macOS, unavailable)
@available(watchOS, unavailable)
@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, *)
public extension WindowOverlayView {
    
    @inlinable
    init(level:CGFloat, isHidden: Bool, @ViewBuilder content: () -> Content) {
        self.init(level: level, isHidden: isHidden, content: content())
    }
    
}
