//
//  InvalidTaskScope.swift
//  
//
//  Created by pbk on 2023/01/02.
//

import Foundation

@usableFromInline
struct InvalidTaskScope: TaskScopeProtocol {
    
    @usableFromInline
    var isCancelled:Bool { true }
    
    @usableFromInline
    func launch(operation: @escaping Job) -> Bool {
        print("InvalidTaskScope never launch")
        return false
    }
    
    @usableFromInline
    func cancel() {}
    

    @usableFromInline
    init() {}
    
}
