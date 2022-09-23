//
//  CodablePrimitive.swift
//  
//
//  Created by pbk on 2022/09/23.
//

import Foundation

public enum CodablePrimitive {

    case bool(Bool)
    case string(String)
    case integer(Int)
    case double(Double)
    case array([Self])
    case object([String:Self])
    
}

#if canImport(_Concurrency)
extension CodablePrimitive: Sendable {}
#endif

// MARK: - Codable
extension CodablePrimitive: Codable {
    internal struct CodingKeys: CodingKey, Sendable, RawRepresentable, ExpressibleByStringLiteral {
        
        var stringValue: String
        
        init(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init(stringLiteral value: String) {
            self.stringValue = value
        }
        
        init(rawValue: String) {
            self.stringValue = rawValue
        }
        
        var intValue: Int? = nil
        
        init?(intValue: Int) {
            return nil
        }
        
        var rawValue: String { stringValue }
        
    }

    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .bool(let bool):
            var container = encoder.singleValueContainer()
            try container.encode(bool)
        case .string(let string):
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case .integer(let integer):
            var container = encoder.singleValueContainer()
            try container.encode(integer)
        case .double(let double):
            var container = encoder.singleValueContainer()
            try container.encode(double)
        case .array(let array):
            var container = encoder.unkeyedContainer()
            try container.encode(contentsOf: array)
        case .object(let dictionary):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try dictionary.forEach { key, value in
                try container.encode(value, forKey: CodingKeys(stringValue: key))
            }
        }
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            var dictionary:[String:Self] = [:]
            try container.allKeys.forEach { key in
                dictionary[key.stringValue] = try container.decodeIfPresent(Self.self, forKey: key)
            }
            self = .object(dictionary)
            return
        } else if var container = try? decoder.unkeyedContainer() {
            var array = [Self]()
            while (!container.isAtEnd) {
                if let value = try container.decodeIfPresent(Self.self) {
                    array.append(value)
                }
            }
            self = .array(array)
            return
        }
        let container = try decoder.singleValueContainer()
        guard !container.decodeNil() else {
            let context = DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Expected Primitive Type but found null value instead.",
                underlyingError: nil
            )
            throw DecodingError.valueNotFound(Self.self, context)
        }
        var errorContainer = [Error]()
        let stringResult = Result { try container.decode(String.self) }
        switch stringResult {
        case .success(let success):
            self = .string(success)
            return
        case .failure(let failure):
            errorContainer.append(failure)
        }
        let boolResult = Result{ try container.decode(Bool.self) }
        switch boolResult {
        case .success(let success):
            self = .bool(success)
            return
        case .failure(let failure):
            errorContainer.append(failure)
            break
        }
        let integerResult = Result { try container.decode(Int.self) }
        switch integerResult {
        case .success(let success):
            self = .integer(success)
            return
        case .failure(let failure):
            errorContainer.append(failure)
        }
        let floatingResult = Result { try container.decode(Double.self) }
        switch floatingResult {
        case .success(let success):
            self = .double(success)
            return
        case .failure(let failure):
            errorContainer.append(failure)
        }

        let context = DecodingError.Context(
            codingPath: container.codingPath,
            debugDescription: "Expected Primitive value (one of Double, Bool, String, Int) but underlying Type is not primitive",
            underlyingError: errorContainer.randomElement()
        )
        throw DecodingError.typeMismatch(Self.self, context)
    }
    
}


// MARK: - Hashable
extension CodablePrimitive: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.bool(let left), .bool(let right)):
            return left == right
        case (.integer(let left), .integer(let right)):
            return left == right
        case (.double(let left), .double(let right)):
            return left == right
        case (.array(let left), .array(let right)):
            return left == right
        case (.object(let left), .object(let right)):
            return left == right
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .bool(let bool):
            hasher.combine(bool)
        case .string(let string):
            hasher.combine(string)
        case .integer(let value):
            hasher.combine(value)
        case .double(let value):
            hasher.combine(value)
        case .array(let array):
            hasher.combine(array)
        case .object(let dictionary):
            hasher.combine(dictionary)
        }
    }
}

// MARK: - Expressible Initializer
extension CodablePrimitive: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral, CustomStringConvertible {
    
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
    
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
    
    public init(integerLiteral value: IntegerLiteralType) {
        self = .integer(value)
    }
    
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
    
    public init(dictionaryLiteral elements: (String, Self)...) {
        self = .object(.init(elements) { old, new in new })
    }
    
    public init(arrayLiteral elements: Self...) {
        self = .array(elements)
    }
    
    public var description: String {
        """
        \(Self.self)(\(propertyObject))
        """
    }
    
}

// MARK: - Content Accessor
public extension CodablePrimitive {
    
    var propertyObject:Any {
        switch self {
        case .bool(let bool):
            return bool
        case .string(let string):
            return string
        case .integer(let int):
            return int
        case .double(let double):
            return double
        case .array(let array):
            return array.map(\.propertyObject)
        case .object(let dictionary):
            return dictionary.mapValues(\.propertyObject)
        }
    }
    
    subscript(_ key: String) -> Self? {
        get {
            switch self {
            case .object(let dictionary):
                return dictionary[key]
            default:
                return nil
            }
        }
    }
    
    subscript(_ index: Int) -> Self? {
        get {
            switch self {
            case .array(let array) where array.indices.contains(index):
                return array[index]
            default:
                return nil
            }
        }
    }
    
    var object:[String:Self]? {
        switch self {
        case .object(let object):
            return object
        default:
            return nil
        }
    }
    
    var array:[Self]? {
        switch self {
        case .array(let array):
            return array
        default:
            return nil
        }
    }
    
    var bool:Bool? {
        switch self {
        case .bool(let bool):
            return bool
        default:
            return nil
        }
    }
    
    var integer:Int? {
        switch self {
        case .integer(let int):
            return int
        default:
            return nil
        }
    }
    
    var string:String? {
        switch self {
        case .string(let string):
            return string
        default:
            return nil
        }
    }
    
    var double:Double? {
        switch self {
        case .double(let double):
            return double
        default:
            return nil
        }
    }
}
