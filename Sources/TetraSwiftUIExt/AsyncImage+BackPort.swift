//
//  AsyncImage+BackPort.swift
//  
//
//  Created by pbk on 2022/12/08.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(SwiftUI) && (canImport(UIKit) || canImport(AppKit))
import SwiftUI

@available(iOS, introduced: 13.0, obsoleted: 15.0)
@available(tvOS, introduced: 13.0, obsoleted: 15.0)
@available(macCatalyst, introduced: 13.0, obsoleted: 15.0)
@available(macOS, introduced: 10.15, obsoleted: 12.0)
@available(watchOS, introduced: 6.0, obsoleted: 8.0)
public enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)
    
    @inlinable
    var image: Image? {
        guard case .success(let image) = self else { return nil }
        return image
    }
    
    @inlinable
    var error: Error? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}

@available(iOS, introduced: 13.0, obsoleted: 15.0)
@available(tvOS, introduced: 13.0, obsoleted: 15.0)
@available(macCatalyst, introduced: 13.0, obsoleted: 15.0)
@available(macOS, introduced: 10.15, obsoleted: 12.0)
@available(watchOS, introduced: 6.0, obsoleted: 8.0)
public struct AsyncImage<Content: View>: View {
    
    @usableFromInline
    var url: URL?
    @usableFromInline
    var scale: CGFloat = 1
    @usableFromInline
    var content: ((TetraSwiftUIExt.AsyncImagePhase) -> Content)?
    @State private var imagePhase:AsyncImagePhase = .empty
    @usableFromInline
    var someView:AnyView
    
    @usableFromInline
    @ViewBuilder
    var contentOrImage: some View {
        if let content = content {
            content(imagePhase)
        } else if case let .success(image) = imagePhase {
            image
        } else {
            #if canImport(UIKit)
            Color(UIColor.secondarySystemBackground)
            #elseif canImport(AppKit)
            Color(NSColor.systemGray)
            #else
            Color.gray
            #endif
        }
    }

    public var body: some View {
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            someView
        } else {
            contentOrImage
                .async {
                    guard let url else { return }
                    switch imagePhase {
                    case .failure(let error) where (error as? URLError)?.code == .cancelled:
                        imagePhase = .empty
                        fallthrough
                    case .empty:
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            #if canImport(UIKit)
                            if let image = UIImage(data: data, scale: scale) {
                                imagePhase = .success(Image(uiImage: image))
                            } else {
                                throw URLError(.cannotDecodeContentData)
                            }
                            #elseif canImport(AppKit)
                            if let image = NSImage(data: data) {
                                imagePhase = .success(Image(nsImage: image))
                            } else {
                                throw URLError(.cannotDecodeContentData)
                            }
                            #endif
                        } catch {
                            imagePhase = .failure(error)
                        }
                    default:
                        break
                    }


                }
        }
    }

    @inlinable
    public init(url: URL, scale: CGFloat = 1) where Content == Image {
        self.url = url
        self.scale = scale
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            self.someView = AnyView(SwiftUI.AsyncImage(url: url, scale: scale))
        } else {
            self.someView = AnyView(EmptyView())
        }
    }

    @inlinable
    public init<I, P>(
        url: URL?,
        scale: CGFloat = 1,
        content: @escaping (Image) -> I,
        placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.init(url: url, scale: scale) { phase in
            if let image = phase.image {
                content(image)
            } else {
                placeholder()
            }
        }
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            self.someView = AnyView(
                SwiftUI.AsyncImage(url: url, scale: scale, content: content, placeholder: placeholder)
            )
        } else {
            self.someView = AnyView(EmptyView())
        }
    }

    @inlinable
    public init(
        url: URL?,
        scale: CGFloat = 1,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        if #available(iOS 15.0, tvOS 15.0, macCatalyst 15.0, watchOS 8.0, macOS 12.0, *) {
            self.someView = AnyView(
                SwiftUI.AsyncImage(url: url, scale: scale, transaction: transaction) { phase in
                    switch phase {
                    case .empty:
                        content(.empty)
                    case .success(let image):
                        content(.success(image))
                    case .failure(let error):
                        content(.failure(error))
                    @unknown default:
                        EmptyView()
                    }
                }
            )
        } else {
            self.someView = AnyView(EmptyView())
        }
    }
}


#endif
