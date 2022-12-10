//
//  CodablePrimitive.swift
//
//
//  Created by pbk on 2022/09/23.
//

import Foundation

/**
    Codable Object Wrapper which provides opportunity to mix general primitive types into single value.
    ```
        let wrapped:CodablePrimitive = [
            "api_key":"unqiueKeys",
            "values": [["fruit":"apple", "cost":100.0], ["fruit":"banana", "cost":20.0],
            "codeNumber": 123,
            "isUser": false,
            "mixedArray":[false, 0, "asds", [1]]
        ]
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(CodablePrimitive.self, from:data)
 ```
 */
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
    
    @inlinable
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .bool(let bool):
            try bool.encode(to: encoder)
        case .string(let string):
            try string.encode(to: encoder)
        case .integer(let integer):
            try integer.encode(to: encoder)
        case .double(let double):
            try double.encode(to: encoder)
        case .array(let array):
            try array.encode(to: encoder)
        case .object(let dictionary):
            try dictionary.encode(to: encoder)
        }
    }
    
    public init(from decoder: Decoder) throws {
        var isKeyedContainer = false
        do {
            let _ = try decoder.container(keyedBy: StringCodingKey.self)
            isKeyedContainer = true
            
        } catch DecodingError.typeMismatch(_, let context) {
            if let underlyingError = context.underlyingError {
                throw underlyingError
            }
        }
        if isKeyedContainer {
            let container = try [String:Self?](from: decoder)
            self = .object(container.compactMapValues { $0 })
            return
        }
        var isUnkeyedContainer = false
        do {
            let _ = try decoder.unkeyedContainer()
            isUnkeyedContainer = true
        } catch DecodingError.typeMismatch(_, let context) {
            if let underlyingError = context.underlyingError {
                throw underlyingError
            }
        }
        if isUnkeyedContainer {
            let container = try [Self?](from: decoder)
            self = .array(container.compactMap{ $0 })
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
extension CodablePrimitive: Hashable {}

// MARK: - Expressible Initializer
extension CodablePrimitive: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral, CustomStringConvertible {
    
    @inlinable
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
    
    @inlinable
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
    
    @inlinable
    public init(integerLiteral value: IntegerLiteralType) {
        self = .integer(value)
    }
    
    @inlinable
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(value)
    }
    
    @inlinable
    public init(dictionaryLiteral elements: (String, Self)...) {
        self = .object(.init(elements) { old, new in new })
    }
    
    @inlinable
    public init(arrayLiteral elements: Self...) {
        self = .array(elements)
    }
    
    @inlinable
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
    
    @inlinable
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
    
    @inlinable
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
    
    @inlinable
    var object:[String:Self]? {
        switch self {
        case .object(let object):
            return object
        default:
            return nil
        }
    }
    
    @inlinable
    var array:[Self]? {
        switch self {
        case .array(let array):
            return array
        default:
            return nil
        }
    }
    
    @inlinable
    var bool:Bool? {
        switch self {
        case .bool(let bool):
            return bool
        default:
            return nil
        }
    }
    
    @inlinable
    var integer:Int? {
        switch self {
        case .integer(let int):
            return int
        default:
            return nil
        }
    }
    
    @inlinable
    var string:String? {
        switch self {
        case .string(let string):
            return string
        default:
            return nil
        }
    }
    
    @inlinable
    var double:Double? {
        switch self {
        case .double(let double):
            return double
        default:
            return nil
        }
    }
}

@usableFromInline
struct StringCodingKey: CodingKey, RawRepresentable, Sendable {
    @usableFromInline
    var stringValue: String { rawValue }
    
    @usableFromInline
    init(stringValue: String) {
        self.rawValue = stringValue
    }
    
    @usableFromInline
    var intValue: Int?
    
    @usableFromInline
    init?(intValue: Int) {
        self.intValue = intValue
        self.rawValue = intValue.description
    }
    
    @usableFromInline
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    @usableFromInline
    var rawValue: String
    
    @usableFromInline
    typealias RawValue = String
    
}
