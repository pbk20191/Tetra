//
//  AnyEncodable.swift
//  
//
//  Created by pbk on 2022/12/10.
//

import Foundation

public struct AnyEncodable: Encodable {
    
    public let value:Encodable
    
    @inlinable
    public init(_ wrapped: Encodable) {
        self.value = wrapped
    }
    
    @inlinable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try value.encode(to: &container)
    }
    
}


extension Encodable {
    
    @usableFromInline
    internal func encode(to container: inout SingleValueEncodingContainer) throws {
        try container.encode(self)
    }
    
}
