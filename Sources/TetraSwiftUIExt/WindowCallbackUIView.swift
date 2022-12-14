//
//  WindowCallbackUIView.swift
//  
//
//  Created by pbk on 2022/12/14.
//

import Foundation
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

@MainActor
@usableFromInline
final class WindowCallbackUIView: UIView {
    
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

#endif
