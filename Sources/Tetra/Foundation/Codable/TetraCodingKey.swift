//
//  TetraCodingKey.swift
//  
//
//  Created by pbk on 2023/01/31.
//

import Foundation

@usableFromInline
internal struct TetraCodingKey: CodingKey, Sendable, Hashable {
    
    @usableFromInline
    var stringValue: String
    
    @usableFromInline
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    @usableFromInline
    var intValue: Int?
    
    @usableFromInline
    init(intValue: Int) {
        self.stringValue = "Index \(intValue)"
        self.intValue = intValue
    }
    
    
}
