//
//  SerializableMappingProtocol.swift
//  
//
//  Created by pbk on 2023/01/31.
//

import Foundation

@usableFromInline
internal protocol SerializableMappingProtocol {
    
    init(_ deserializedValue:Any, path:[TetraCodingKey]) throws
    
}

@usableFromInline
internal func drillDownDictionary<T:SerializableMappingProtocol>(_ source: [String:Any], _ container: inout [String:T], path: [TetraCodingKey]) throws {
    try source.forEach{ key, erasedValue in
        
        let wrappedValue = try T(erasedValue, path: path + CollectionOfOne(TetraCodingKey.string( key)))

        container.updateValue(wrappedValue, forKey: key)
    }
}

@usableFromInline
internal func drillDownArray<T:SerializableMappingProtocol>(_ source: [Any], _ container: inout [T], path: [TetraCodingKey]) throws {
    try source.enumerated().forEach{ key, erasedValue in
        
        let wrappedValue = try T(erasedValue, path: path + CollectionOfOne(TetraCodingKey(index: key)))

        container.append(wrappedValue)
    }
}
