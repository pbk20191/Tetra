//
//  JsonWrapper.swift
//  
//
//  Created by pbk on 2023/01/30.
//

import Foundation


/**
   Encodable  object specialized for JSON, which provides opportunity to mix general primitive types into single value.

    ```
        let wrapped:JsonWrapper = [
            "api_key":"unqiueKeys",
            "values": [["fruit":"apple", "cost":100.0], ["fruit":"banana", "cost":20.0],
            "codeNumber": 123,
            "isUser": false,
            "mixedArray":[false, 0, "asds", [1]]
        ]
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JsonWrapper(from: data)
 ```
 

    
 */
public enum JsonWrapper: Sendable {
    
    case null
    case bool(Bool)
    case string(String)
    case integer(Int)
    case double(Double)
    case array([Self])
    case object([String:Self])
    
}

extension JsonWrapper: Encodable {
    
    @inlinable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
    
    @inlinable
    public init(unsafeObject: Any) throws {
        if JSONSerialization.isValidJSONObject(unsafeObject) {
            self = try .init(unsafeObject, path: [])
        } else if let value = unsafeObject as? Self {
            self = value
        } else {
            switch unsafeObject {
            case let value as Bool:
                self = .bool(value)
            case let value as String:
                self = .string(value)
            case let value as Double:
                self = .double(value)
            case let value as Int:
                self = .integer(value)
            case Optional<Any>.none:
                fallthrough
            case is NSNull:
                self = .null
            default:
                let context = DecodingError.Context(codingPath: [], debugDescription: "\(type(of: unsafeObject)) is not supported")
                throw DecodingError.dataCorrupted(context)
            }
        }
    }
    
    @inlinable
    public func write(to stream:OutputStream, options opt: JSONSerialization.WritingOptions) throws -> Int {
        var error:NSError? = nil
        let byteCount = JSONSerialization.writeJSONObject(propertyObject, to: stream, options: opt, error: &error)
        if let error {
            throw error
        }
        return byteCount
    }
    
    
    /// perform `JSONSerialization`and map the object into `JsonWrapper`
    /// - Parameters:
    ///   - data: A data object containing JSON data.
    ///   - opt: Options for reading the JSON data and creating the Foundation objects. For possible values, see JSONSerialization.ReadingOptions.
    /// - Returns: the `JsonWrapper`
    /// - throws: `JSONSerialization` internal error if  `JSONSerialization` fails. `DecodingError.valueNotFound` if top level object is `null`.  `DecodingError.typeMismatch` otherwise
    @inlinable
    public init(from data: Data, options opt: JSONSerialization.ReadingOptions = []) throws {
        let topLevelRawObject = try JSONSerialization.jsonObject(with: data, options: opt)
        self = try JsonWrapper(topLevelRawObject, path: [])
    }
    
    /// perform `JSONSerialization`and map the object into `JsonWrapper`
    /// - Parameters:
    ///   - stream: A stream from which to read JSON data. The stream should be open and configured.
    ///   - opt: Options for reading the JSON data and creating the Foundation objects. For possible values, see JSONSerialization.ReadingOptions.
    /// - Returns: the `JsonWrapper`
    /// - throws: `JSONSerialization` internal error if  `JSONSerialization` fails. `DecodingError.valueNotFound` if top level object is `null`.  `DecodingError.typeMismatch` otherwise
    @inlinable
    public init(
        from stream: InputStream,
        options opt: JSONSerialization.ReadingOptions = []
    ) throws {
        let topLevelRawObject = try JSONSerialization.jsonObject(with: stream, options: opt)
        self = try JsonWrapper(topLevelRawObject, path: [])
    }
    
    @inlinable
    public func serialize(options opt: JSONSerialization.WritingOptions) throws -> Data {
        try JSONSerialization.data(withJSONObject: propertyObject, options: opt)
    }

    @inlinable
    public static func transform(
        _ value: some Encodable, encoder: JSONEncoder = JSONEncoder(), options: JSONSerialization.ReadingOptions = [.fragmentsAllowed]
    ) throws -> Self {
        switch value {
        case let object as Self:
            return object
        default:
            return try Self(from: encoder.encode(value), options: options)
        }
    }
    
}

extension JsonWrapper: SerializableMappingProtocol {
    
    @usableFromInline
    init(_ deserializedValue: Any, path: [TetraCodingKey]) throws {
        switch deserializedValue {
        case let value as Bool:
            self = .bool(value)
        case let value as String:
            self = .string(value)
        case let value as Double:
            self = .double(value)
        case let value as Int:
            self = .integer(value)
        case Optional<Any>.none:
            fallthrough
        case is NSNull:
            self = .null
        case let value as [Any]:
            var nestedContainer = [Self]()
            nestedContainer.reserveCapacity(value.capacity)
            try drillDownArray(value, &nestedContainer, path: path)
            self = .array(nestedContainer)
        case let value as [String: Any]:
            var nestedContainer = [String:Self](minimumCapacity: value.capacity)
            try drillDownDictionary(value, &nestedContainer, path: path)
            self = .object(nestedContainer)
        default:
            let context = DecodingError.Context(
                codingPath: path,
                debugDescription: "\(type(of: deserializedValue)) is not supported",
                underlyingError: nil
            )
            throw DecodingError.typeMismatch(Self.self, context)
        }
    }
    
}


// MARK: - Hashable
extension JsonWrapper: Hashable {}

// MARK: - Expressible Initializer
extension JsonWrapper: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral, CustomStringConvertible {
    
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

// MARK: - custom operator
public extension JsonWrapper {
    
    @inlinable
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
        case .null:
            return Optional<Any>.none as Any
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
    
    @inlinable
    static func == (lhs: Self, rhs: Int) -> Bool {
        lhs.integer == rhs
    }
    
    @inlinable
    static func == (lhs: Self, rhs: Double) -> Bool {
        lhs.double == rhs
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
