//
//  JsonWrapperDecoder.swift
//  
//
//  Created by pbk on 2023/05/27.
//

import Foundation
import Combine

public struct JsonWrapperDecoder: TopLevelDecoder {
    
    public init() {
        
    }
    
    public var userInfo: [CodingUserInfoKey : Any] = [:]
    
    public func decode<T>(_ type: T.Type, from: JsonWrapper) throws -> T where T : Decodable {
        let decoder = JsonWrapperDecoderImp(container: from, codingPath: [], userInfo: userInfo)
        return try T(from: decoder)
    }
    
}

struct JsonWrapperDecoderImp: Decoder {
    
    let container:JsonWrapper
    
    var codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey : Any]
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: container.typeMissmatchDescription(for: [String:Any].self))
        switch container {
        case .null:
            throw DecodingError.valueNotFound(KeyedDecodingContainer<Key>.self, context)
        case .object(let dictionary):
            let newDecoder = JsonWrapperKeyedDecoder<Key>(dictionary: dictionary, codingPath: codingPath, userInfo: userInfo)
            return .init(newDecoder)
        default:
            throw DecodingError.typeMismatch(KeyedDecodingContainer<Key>.self, context)
        }
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: container.typeMissmatchDescription(for: [Any].self))
        switch container {
        case .null:
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self, context)
        case .array(let array):
            return JsonWrapperUnkeyedDecoder(container: array, codingPath: codingPath, userInfo: userInfo)
        default:
            throw DecodingError.typeMismatch(UnkeyedDecodingContainer.self, context)
        }
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return JsonWrapperSingleDecodingContainer(
            container: container,
            codingPath: codingPath,
            userInfo: userInfo
        )
    }
    
}

struct JsonWrapperSingleDecodingContainer: SingleValueDecodingContainer {
   
    let container:JsonWrapper
    
    var codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey : Any]
    
    func decodeNil() -> Bool {
        container == .null
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        let reachedType:Any.Type
        switch container {
        case .null:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "expected \(type) but found null instead")
            throw DecodingError.valueNotFound(type, context)
        case .bool(let bool):
            return bool
        case .string(_):
            reachedType = String.self
        case .integer(_):
            reachedType = Int.self
        case .double(_):
            reachedType = Double.self
        case .array(_):
            reachedType = [Any].self
        case .object(_):
            reachedType = [String:Any].self
        }
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: "expected \(type) but found \(reachedType) instead")
        throw DecodingError.typeMismatch(reachedType, context)
    }
    
    func decode(_ type: String.Type) throws -> String {
        let reachedType:Any.Type
        switch container {
        case .null:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "expected \(type) but found null instead")
            throw DecodingError.valueNotFound(type, context)
        case .bool(_):
            reachedType = Bool.self
        case .string(let string):
            return string
        case .integer(_):
            reachedType = Int.self
        case .double(_):
            reachedType = Double.self
        case .array(_):
            reachedType = [Any].self
        case .object(_):
            reachedType = [String:Any].self
        }
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: "expected \(type) but found \(reachedType) instead")
        throw DecodingError.typeMismatch(reachedType, context)
    }
    
    func decodeBinaryFloating<T:BinaryFloatingPoint>(_ type:T.Type) throws -> T {
        let reachedType:Any.Type
        switch container {
        case .null:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "expected \(type) but found null instead")
            throw DecodingError.valueNotFound(type, context)
        case .bool(_):
            reachedType = Bool.self
        case .string(_):
            reachedType = String.self
        case .integer(let integer):
            if let value = T.init(exactly: integer) {
                return value
            } else {
                let context = DecodingError.Context(codingPath: codingPath, debugDescription: "\(integer) does not fit in \(type)")
                throw DecodingError.typeMismatch(type, context)
            }
        case .double(let double):
            if double.isSignalingNaN {
                return T.signalingNaN
            }
            return T(double)
        case .array(_):
            reachedType = [Any].self
        case .object(_):
            reachedType = [String:Any].self
        }
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: "expected \(type) but found \(reachedType) instead")
        throw DecodingError.typeMismatch(reachedType, context)
    }
    
    func decodeInteger<T:FixedWidthInteger>(_ type:T.Type) throws -> T {
        let reachedType:Any.Type
        switch container {
        case .null:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "expected \(type) but found null instead")
            throw DecodingError.valueNotFound(type, context)
        case .bool(_):
            reachedType = Bool.self
        case .string(_):
            reachedType = String.self
        case .integer(let integer):
            if let value = T.init(exactly: integer) {
                return value
            } else {
                let context = DecodingError.Context(codingPath: codingPath, debugDescription: "\(integer) does not fit in \(type)")
                throw DecodingError.typeMismatch(type, context)
            }
        case .double(_):
            reachedType = Double.self
        case .array(_):
            reachedType = [Any].self
        case .object(_):
            reachedType = [String:Any].self
        }
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: "expected \(type) but found \(reachedType) instead")
        throw DecodingError.typeMismatch(reachedType, context)
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        try decodeBinaryFloating(type)
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        try decodeBinaryFloating(type)
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        try decodeInteger(type)
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        try decodeInteger(type)
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        try decodeInteger(type)
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        try decodeInteger(type)
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        try decodeInteger(type)
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        try decodeInteger(type)
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try decodeInteger(type)
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try decodeInteger(type)
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try decodeInteger(type)
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try decodeInteger(type)
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let decoder = JsonWrapperDecoderImp(container: container, codingPath: codingPath, userInfo: userInfo)
        return try T(from: decoder)
    }
    
}

struct JsonWrapperUnkeyedDecoder: UnkeyedDecodingContainer {

    let container:[JsonWrapper]
    
    var codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey : Any]
    
    var count: Int? { container.count }
    
    var isAtEnd: Bool {
        if (container.isEmpty) {
            return true
        } else {
            return !container.indices.contains(currentIndex)
        }
    }
    
    private(set) var currentIndex: Int = 0
    
    
    func checkEnd() throws {
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        if isAtEnd {
            let context = DecodingError.Context(codingPath: currentPath, debugDescription: "Unkeyed container is at end.")
            throw DecodingError.valueNotFound(Never.self, context)
        }
    }
    
    mutating func decodeNil() throws -> Bool {
        try checkEnd()
        let object = container[currentIndex]
        if object == .null {
            currentIndex += 1
            return true
        } else {
            return false
        }
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try checkEnd()
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        let item = container[currentIndex]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: [String:Any].self))
        switch item {
        case .null:
            throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self, context)
        case .object(let object):
            currentIndex += 1
            let newDecoder = JsonWrapperKeyedDecoder<NestedKey>(dictionary: object, codingPath: currentPath, userInfo: userInfo)
            return .init(newDecoder)
        default:
            throw DecodingError.typeMismatch(KeyedDecodingContainer<NestedKey>.self, context)
        }
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try checkEnd()
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        let item = container[currentIndex]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: Array<Any>.self))
        switch item {
        case .null:
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self, context)
        case .array(let array):
            currentIndex += 1
            return JsonWrapperUnkeyedDecoder(container: array, codingPath: currentPath, userInfo: userInfo)
        default:
            throw DecodingError.typeMismatch(UnkeyedDecodingContainer.self, context)
        }
    }
    
    mutating func superDecoder() throws -> Decoder {
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        if isAtEnd {
            let context = DecodingError.Context(codingPath: currentPath, debugDescription:"Cannot get superDecoder() -- unkeyed container is at end.")
            throw DecodingError.valueNotFound(Decoder.self, context)
        }
        let object = container[currentIndex]
        if object == .null {
            let context = DecodingError.Context(codingPath: currentPath, debugDescription:"Cannot get superDecoder() -- encounter null")
            throw DecodingError.valueNotFound(Decoder.self, context)
        }
        currentIndex += 1
        let newDecoder = JsonWrapperDecoderImp(container: object, codingPath: currentPath, userInfo: userInfo)
        return newDecoder
    }
    
    mutating func decodeInteger<T:FixedWidthInteger>(_ type:T.Type) throws -> T {
        try checkEnd()
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        let item = container[currentIndex]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        case .null:
            throw DecodingError.valueNotFound(type, context)
        case .integer(let int):
            if let value = T.init(exactly: int) {
                currentIndex += 1
                return value
            } else {
                let context = DecodingError.Context(codingPath: currentPath, debugDescription: "\(int) does not fit in \(type)")
                throw DecodingError.typeMismatch(type, context)
            }
        default:
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    mutating func decodeBinaryFloating<T:BinaryFloatingPoint>(_ type:T.Type) throws -> T {
        try checkEnd()
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        let item = container[currentIndex]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: type))
        let realValue:T
        switch item {
        case .null:
            throw DecodingError.valueNotFound(type, context)
        case .integer(let int):
            if let value = T.init(exactly: int) {
                realValue = value
            } else {
                let context = DecodingError.Context(codingPath: currentPath, debugDescription: "\(int) does not fit in \(type)")
                throw DecodingError.typeMismatch(type, context)
            }
        case .double(let double):
            if (double.isSignalingNaN) {
                realValue = .signalingNaN
            } else {
                realValue = .init(double)
            }
        default:
            throw DecodingError.typeMismatch(type, context)
        }
        currentIndex += 1
        return realValue
    }
    
    mutating func decode(_ type: Bool.Type) throws -> Bool {
        try checkEnd()
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        let item = container[currentIndex]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        case .null:
            throw DecodingError.valueNotFound(type, context)
        case .bool(let bool):
            currentIndex += 1
            return bool
        default:
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    mutating func decode(_ type: String.Type) throws -> String {
        try checkEnd()
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        let item = container[currentIndex]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        case .null:
            throw DecodingError.valueNotFound(type, context)
        case .string(let string):
            currentIndex += 1
            return string
        default:
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        try checkEnd()
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        let item = container[currentIndex]
        if item == .null {
            let context = DecodingError.Context(codingPath: currentPath, debugDescription: "expected \(type) but found null instead")
            throw DecodingError.valueNotFound(type, context)
        }
        let decoder = JsonWrapperDecoderImp(container: item, codingPath: currentPath, userInfo: userInfo)
        currentIndex += 1
        return try T(from: decoder)
    }
    
    mutating func decode(_ type: Double.Type) throws -> Double {
        try decodeBinaryFloating(type)
    }
    
    mutating func decode(_ type: Float.Type) throws -> Float {
        try decodeBinaryFloating(type)
    }
    
    mutating func decode(_ type: Int.Type) throws -> Int {
        try decodeInteger(type)
    }
    
    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        try decodeInteger(type)
    }
    
    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        try decodeInteger(type)
    }
    
    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        try decodeInteger(type)
    }
    
    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        try decodeInteger(type)
    }
    
    mutating func decode(_ type: UInt.Type) throws -> UInt {
        try decodeInteger(type)
    }
    
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        try decodeInteger(type)
    }
    
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        try decodeInteger(type)
    }
    
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        try decodeInteger(type)
    }
    
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        try decodeInteger(type)
    }
    
}


struct JsonWrapperKeyedDecoder<Key:CodingKey>: KeyedDecodingContainerProtocol {
    
    
    let dictionary:[String:JsonWrapper]
    
    var codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey : Any]
    
    
    var allKeys: [Key] { dictionary.keys.compactMap(Key.init)}
    
    func contains(_ key: Key) -> Bool {
        dictionary.keys.contains(key.stringValue)
    }
    
    func getValue(forKey key: some CodingKey) throws -> JsonWrapper {
        guard let value = dictionary[key.stringValue] else {
            throw DecodingError.keyNotFound(key, .init(
                codingPath: codingPath,
                debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."
            ))
        }
        return value
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        guard let item = dictionary[key.stringValue] else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\").")
            throw DecodingError.keyNotFound(key, context)
        }
        return item == .null
    }
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let item = try getValue(forKey: key)
        let context = DecodingError.Context(codingPath: codingPath + [key], debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        case .bool(let bool):
            return bool
        case .null:
            throw DecodingError.valueNotFound(type, context)
        default:
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let item = try getValue(forKey: key)
        let context = DecodingError.Context(codingPath: codingPath + [key], debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        case .string(let string):
            return string
        case .null:
            throw DecodingError.valueNotFound(type, context)
        default:
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    func decodeInteger<T:FixedWidthInteger>(_ type: T.Type, forKey key:Key) throws -> T {
        let item = try getValue(forKey: key)
        let currentPath = codingPath + [key]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        case .null:
            throw DecodingError.valueNotFound(type, context)
        case .integer(let int):
            if let realValue = T(exactly: int) {
                return realValue
            } else {
                let context = DecodingError.Context(codingPath: currentPath, debugDescription: "\(int) does not fit in \(type)")
                throw DecodingError.typeMismatch(type, context)
            }
        default:
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    func decodeBinaryFloat<T:BinaryFloatingPoint>(_ type: T.Type, forKey key:Key) throws -> T {
        let item = try getValue(forKey: key)
        let currentPath = codingPath + [key]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        case .null:
            throw DecodingError.valueNotFound(type, context)
        case .double(let double):
            if (double.isSignalingNaN) {
                return T.signalingNaN
            }
            return T(double)
        case .integer(let int):
            if let realValue = T(exactly: int) {
                return realValue
            } else {
                let context = DecodingError.Context(codingPath: currentPath, debugDescription: "\(int) does not fit in \(type)")
                throw DecodingError.typeMismatch(type, context)
            }
        default:
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        let item = try getValue(forKey: key)
        let context = DecodingError.Context(codingPath: codingPath + [key], debugDescription: item.typeMissmatchDescription(for: type))
        if item == .null {
            /// Bypass strict null checking on Optional type
            if let value = Optional<Any>.none as? T {
                return value
            }
            throw DecodingError.valueNotFound(type, context)
        } else {
            let decoder = JsonWrapperDecoderImp(container: item, codingPath: codingPath + [key], userInfo: userInfo)
            return try T(from: decoder)
        }
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let item = try getValue(forKey: key)
        let context = DecodingError.Context(codingPath: codingPath + [key], debugDescription: item.typeMissmatchDescription(for: [String:Any].self))
        switch item {
        case .object(let dictionary):
            let container = JsonWrapperKeyedDecoder<NestedKey>(dictionary: dictionary, codingPath: codingPath + [key], userInfo: userInfo)
            return .init(container)
        case .null:
            throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self, context)
        default:
            throw DecodingError.typeMismatch(KeyedDecodingContainer<NestedKey>.self, context)
        }
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let item = try getValue(forKey: key)
        let context = DecodingError.Context(codingPath: codingPath + [key], debugDescription: item.typeMissmatchDescription(for: [Any].self))
        switch item {
        case .array(let array):
            let container = JsonWrapperUnkeyedDecoder(container: array, codingPath: codingPath + [key], userInfo: userInfo)
            return container
        case .null:
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self, context)
        default:
            throw DecodingError.typeMismatch(UnkeyedDecodingContainer.self, context)
        }
    }
    
    func superDecoder() throws -> Decoder {
        let item = try? getValue(forKey: TetraCodingKey.super)
        return JsonWrapperDecoderImp(container: item ?? .null, codingPath: codingPath + [TetraCodingKey.super], userInfo: userInfo)
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        let item = try? getValue(forKey: key)
        return JsonWrapperDecoderImp(container: item ?? .null, codingPath: codingPath + [key], userInfo: userInfo)
    }
    
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try decodeBinaryFloat(type, forKey: key)
    }
    
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try decodeBinaryFloat(type, forKey: key)
    }
    
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try decodeInteger(type, forKey: key)
    }
    
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try decodeInteger(type, forKey: key)
    }
    
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try decodeInteger(type, forKey: key)
    }
    
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try decodeInteger(type, forKey: key)
    }
    
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeInteger(type, forKey: key)
    }
    
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try decodeInteger(type, forKey: key)
    }
    
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decodeInteger(type, forKey: key)
    }
    
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decodeInteger(type, forKey: key)
    }
    
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decodeInteger(type, forKey: key)
    }
    
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decodeInteger(type, forKey: key)
    }

    
    
}
