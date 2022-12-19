//
//  AnyEncodable.swift
//  
//
//  Created by pbk on 2022/12/10.
//

import Foundation

public struct AnyEncodable: Encodable {
    
    public let value:any Encodable
    
    @inlinable
    public init(_ wrapped:some Encodable) {
        self.value = wrapped
    }
    
    @inlinable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
}
