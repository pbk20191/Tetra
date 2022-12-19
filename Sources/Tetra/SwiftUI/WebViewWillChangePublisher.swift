//
//  WebViewWillChangePublisher.swift
//  
//
//  Created by pbk on 2022/12/17.
//

import Foundation
#if canImport(WebKit)
import WebKit
import Combine

struct WebViewWillChangePublisher: Publisher {
    
    typealias Output = Void
    typealias Failure = Never
    
    let webView:WKWebView
    
    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Void == S.Input {
        
        let base = webView.publisher(for: \.isLoading, options: [.prior])
            .didChange()
            .merge(
                with: webView.publisher(for: \.canGoBack, options: [.prior])
                    .didChange(),
                webView.publisher(for: \.canGoForward, options: [.prior])
                    .didChange(),
                webView.publisher(for: \.title)
                    .didChange(),
                webView.publisher(for: \.url)
                    .didChange(),
                webView.publisher(for: \.serverTrust, options: [.prior])
                    .didChange(),
                webView.publisher(for: \.hasOnlySecureContent, options: [.prior])
                    .didChange(),
                webView.publisher(for: \.estimatedProgress, options: [.prior])
                    .didChange()
            )
        if #available(iOS 16.0, macOS 13.0, macCatalyst 16.0, *) {
            base
                .merge(
                    with:  webView.publisher(for: \.cameraCaptureState, options: [.prior])
                        .didChange(),
                    webView.publisher(for: \.microphoneCaptureState, options: [.prior])
                        .didChange(),
                    webView.publisher(for: \.themeColor, options: [.prior])
                        .didChange(),
                    webView.publisher(for: \.underPageBackgroundColor, options: [.prior])
                        .didChange(),
                    webView.publisher(for: \.fullscreenState, options: [.prior])
                        .didChange()
                )
                .debounce(
                    for: 0.05,
                    scheduler: DispatchQueue.global(),
                    options: nil
                ).receive(on: RunLoop.main)
                .subscribe(subscriber)
        } else if #available(iOS 15.0, macOS 12.0, macCatalyst 15.0, *) {
            base
                .merge(
                    with: webView.publisher(for: \.microphoneCaptureState, options: [.prior])
                        .didChange(),
                    webView.publisher(for: \.themeColor, options: [.prior])
                        .didChange(),
                    webView.publisher(for: \.underPageBackgroundColor, options: [.prior])
                        .didChange(),
                    webView.publisher(for: \.cameraCaptureState, options: [.prior])
                        .didChange()
                )
                .debounce(
                    for: 0.05,
                    scheduler: DispatchQueue.global(),
                    options: nil
                ).receive(on: RunLoop.main)
                .subscribe(subscriber)
        } else {
            base
                .debounce(
                    for: 0.05,
                    scheduler: DispatchQueue.global(),
                    options: nil
                )
                .receive(on: RunLoop.main)
                .subscribe(subscriber)
        }
    }
    
    
}

#endif
