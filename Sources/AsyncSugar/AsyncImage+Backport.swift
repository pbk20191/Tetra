//
//  File.swift
//  
//
//  Created by pbk on 2022/05/24.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(SwiftUI)
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
    
    var image: Image? {
        guard case .success(let image) = self else { return nil }
        return image
    }
    
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
    var url: URL?
    var scale: CGFloat = 1
    var content: ((AsyncSugar.AsyncImagePhase) -> Content)?
    @State private var imagePhase:AsyncImagePhase = .empty

    
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

    public init(url: URL, scale: CGFloat = 1) where Content == Image {
        self.url = url
        self.scale = scale
    }

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
    }

    public init(
        url: URL?,
        scale: CGFloat = 1,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
    }
}




#endif
