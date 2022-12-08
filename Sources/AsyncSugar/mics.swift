//
//  mics.swift
//  
//
//  Created by pbk on 2022/12/08.
//

import Foundation

@available(iOS 13.0, tvOS 13.0, macCatalyst 13.0, macOS 10.15, watchOS 6.0, *)
@usableFromInline
final class UnsafeReference<T:Sendable> {
    @usableFromInline
    var value:T?
}

@usableFromInline
struct DownloadURLMarker: Sendable {
    
    @usableFromInline
    let target:URL
    @usableFromInline
    let temporal:URL
    @usableFromInline
    let response:URLResponse
    
}
