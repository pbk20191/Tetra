//
//  Environments.swift
//  
//
//  Created by pbk on 2023/01/02.
//

import Foundation
import SwiftUI

public extension EnvironmentValues {
    
    @inlinable
    internal(set) var viewTaskScope: ViewBoundTaskScope {
        get { self[ViewBoundTaskScope.Key.self] }
        set { self[ViewBoundTaskScope.Key.self] = newValue }
    }
    
}
