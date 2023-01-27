//
//  CodablePrimitive.swift
//
//
//  Created by pbk on 2022/09/23.
//

import Foundation

/**
    Codable Object Wrapper which provides opportunity to mix general primitive types into single value. Currently supported Decoders are `JSONDecoder` and `PropertyListDecoder`
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
    
    @inlinable
    public init(from decoder: Decoder) throws {
        do {
            let arrayResult = Result<[Self],Error> {
                try [Self?](from: decoder).compactMap{ $0 }
            }
            if case let .failure(DecodingError.typeMismatch(_, context)) = arrayResult, context.underlyingError == nil {
                // fallthrough
            } else {
                self = try .array(arrayResult.get())
                return
            }
            let dictionaryResult = Result<[String:Self],Error> {
                try [String:Self?](from: decoder).compactMapValues{ $0 }
            }
            if case let .failure(DecodingError.typeMismatch(_, context)) = dictionaryResult, context.underlyingError == nil {
                // fallthrough
            } else {
                self = try .object(dictionaryResult.get())
                return
            }
            let container = try decoder.singleValueContainer()
            guard !container.decodeNil() else {
                let context = DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected Primitive value (one of Double, Bool, String, Int) but found null instead",
                    underlyingError: nil
                )
                throw DecodingError.valueNotFound(Self.self, context)
            }
            self = try Self.decodeSingle(from: decoder.singleValueContainer())
        } catch let error as WrappedError {
            throw error.decodingError
        }
    }
    
    @usableFromInline
    internal static func decodeSingle(from container:SingleValueDecodingContainer) throws -> Self {
        do {
            let string = try container.decode(String.self)
            return .string(string)
        } catch DecodingError.typeMismatch(let expectType, let context) {
            if context.underlyingError == nil && expectType == String.self {
                
            } else {
                throw WrappedError(expectedType: expectType, context: context)
            }
        }
        do {
            let boolValue = try container.decode(Bool.self)
            return .bool(boolValue)
        } catch DecodingError.typeMismatch(let expectType, let context) {
            if context.underlyingError == nil && expectType == Bool.self {
                
            } else {
                throw WrappedError(expectedType: expectType, context: context)
            }
        }
        do {
            let intValue = try container.decode(Int.self)
            return .integer(intValue)
        } catch DecodingError.typeMismatch(let expectType, let context) {
            if context.underlyingError == nil && expectType == Int.self {
                
            } else {
                throw WrappedError(expectedType: expectType, context: context)
            }
            /// `JSONDecoder` throws `DecodingError.dataCorrupted` when encountered value is `Double` but tried to decode into `Int`
        } catch DecodingError.dataCorrupted(let context) where context.underlyingError == nil {
            let double = try container.decode(Double.self)
            return .double(double)
        }
        do {
            let doubleValue = try container.decode(Double.self)
            return .double(doubleValue)
        } catch DecodingError.typeMismatch(let expectType, let context) {
            if context.underlyingError == nil && expectType == Double.self {
                
            } else {
                throw WrappedError(expectedType: expectType, context: context)
            }
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected Primitive value (one of Double, Bool, String, Int) but underlying Type is not primitive"
        )
    }
    
    /// `DecodingError.typeMismatch` wrapper type to unwind stack of decoding
    @usableFromInline
    struct WrappedError: Sendable {
        @usableFromInline
        let expectedType:Any.Type
        @usableFromInline
        let context:DecodingError.Context
        
        @usableFromInline
        init(expectedType: Any.Type, context: DecodingError.Context) {
            self.expectedType = expectedType
            self.context = context
        }
        
        
    }

    
}

extension CodablePrimitive.WrappedError: LocalizedError {
    
    @usableFromInline
    var decodingError:DecodingError {
        .typeMismatch(expectedType, context)
    }
    
    @usableFromInline
    var localizedDescription:String {
        decodingError.localizedDescription
    }
    
    @usableFromInline
    var errorDescription: String? {
        decodingError.errorDescription
    }
    
    @usableFromInline
    var failureReason: String? {
        decodingError.failureReason
    }
    
    @usableFromInline
    var helpAnchor: String? {
        decodingError.helpAnchor
    }
    
    @usableFromInline
    var recoverySuggestion: String? {
        decodingError.recoverySuggestion
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
    
    @inlinable
    var number:NSNumber? {
        switch self {
        case .bool(let bool):
            return bool as NSNumber
        case .integer(let int):
            return int as NSNumber
        case .double(let double):
            return double as NSNumber
        default:
            return nil
        }
    }
    
}

public extension CodablePrimitive {
    
    @inlinable
    static func == (lhs: Self, rhs: Int) -> Bool {
        switch lhs {
        case .integer(let integer):
            return integer == rhs
        case .double(let double):
            return double == Double(rhs)
        default:
            return false
        }
    }
    
    @inlinable
    static func == (lhs: Self, rhs: Double) -> Bool {
        switch lhs {
        case .integer(let integer):
            return Double(integer) == rhs
        case .double(let double):
            return double == rhs
        default:
            return false
        }
    }
    
    @inlinable
    static func == (lhs: Self, rhs: String) -> Bool {
        lhs.string == rhs
    }
    
    @inlinable
    static func == (lhs: Self, rhs: Bool) -> Bool {
        lhs.bool == rhs
    }
    
    @inlinable
    static func == (lhs: Self, rhs: [Self]) -> Bool {
        lhs.array == rhs
    }
    
    @inlinable
    static func == (lhs: Self, rhs: [String:Self]) -> Bool {
        lhs.object == rhs
    }
    
}

