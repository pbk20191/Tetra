//
//  TetraCodingKey.swift
//  
//
//  Created by pbk on 2023/01/31.
//

import Foundation

@usableFromInline
internal enum TetraCodingKey: CodingKey, Sendable, Hashable {
    
    @inlinable
    public init?(intValue: Int) {
        self = .int(intValue)
    }
    
    @inlinable
    public init?(stringValue: String) {
        self = .string(stringValue)
    }
    
    @usableFromInline
    internal init(index: Int) {
        self = .index(index)
    }
    
    @inlinable
    public init(stringValue: String, intValue: Int?) {
        if let intValue {
            self = .both(stringValue, intValue)
        } else {
            self = .string(stringValue)
        }
    }
    
    
    case string(String)
    case int(Int)
    case index(Int)
    case both(String, Int)

    @inlinable
    public var stringValue: String {
        switch self {
        case let .string(str): return str
        case let .int(int): return "\(int)"
        case let .index(index): return "Index \(index)"
        case let .both(str, _): return str
        }
    }

    @inlinable
    public var intValue: Int? {
        switch self {
        case .string: return nil
        case let .int(int): return int
        case let .index(index): return index
        case let .both(_, int): return int
        }
    }
    
    @usableFromInline
    internal static let `super` = Self.both("super", 0)
    
    
}
