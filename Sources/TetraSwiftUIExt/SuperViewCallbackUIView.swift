//
//  SuperViewCallbackUIView.swift
//  
//
//  Created by pbk on 2022/12/14.
//

import Foundation
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

@MainActor
@usableFromInline
internal final class SuperViewCallbackUIView: UIView {
    
    @usableFromInline
    var callBack:((UIView?) -> ())?
    
    @usableFromInline
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        callBack?(newSuperview)
    }
    
    @usableFromInline
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        callBack?(superview)
    }
    
}

#endif
