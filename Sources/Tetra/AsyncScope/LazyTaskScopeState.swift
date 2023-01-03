//
//  LazyTaskScopeState.swift
//  
//
//  Created by pbk on 2023/01/02.
//

import Foundation
import SwiftUI

@propertyWrapper
internal struct LazyTaskScopeState: DynamicProperty {
    
    private var _cachedWrappedValue: StandaloneTaskScope?
    
    @State private var _wrappedValue: StandaloneTaskScope? = nil
    
    /// The current state value.
    public var wrappedValue: StandaloneTaskScope {
        get {
            let expected = _wrappedValue ?? _cachedWrappedValue
            return expected ?? StandaloneTaskScope(detached: ())
        }
        nonmutating set {
            _wrappedValue = newValue
        }
    }
    
    public mutating func update() {
        if _wrappedValue == nil && _cachedWrappedValue == nil {
            _cachedWrappedValue = StandaloneTaskScope(detached: ())
        }
        if _wrappedValue != nil && _cachedWrappedValue != nil {
            _cachedWrappedValue = nil
        }
    }
    
}
