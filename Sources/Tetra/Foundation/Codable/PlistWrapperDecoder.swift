//
//  PlistWrapperDecoder.swift
//  
//
//  Created by pbk on 2023/05/27.
//

import Foundation
import Combine


public struct PlistWrapperDecoder: TopLevelDecoder {
    
//    public init() {
//        
//    }
    
    public var userInfo: [CodingUserInfoKey : Any] = [:]
    
    public func decode<T>(_ type: T.Type, from: PlistWrapper) throws -> T where T : Decodable {
        let decoder = PlistWrapperDecoderImp(container: from, codingPath: [], userInfo: userInfo)
        return try T(from: decoder)
    }
    
}


struct PlistWrapperDecoderImp: Decoder {
    
    let container:PlistWrapper
    
    var codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey : Any]
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: container.typeMissmatchDescription(for: [String:Any].self))
        switch container {
        case .object(let dictionary):
            let newDecoder = KeyedDecoder<Key>(dictionary: dictionary, codingPath: codingPath, userInfo: userInfo)
            return .init(newDecoder)
        default:
            throw DecodingError.typeMismatch(KeyedDecodingContainer<Key>.self, context)
        }
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let context = DecodingError.Context(codingPath: codingPath, debugDescription: container.typeMissmatchDescription(for: [Any].self))
        switch container {
        case .array(let array):
            return UnkeyedDecoder(container: array, codingPath: codingPath, userInfo: userInfo)
        default:
            throw DecodingError.typeMismatch(UnkeyedDecodingContainer.self, context)
        }
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueDecoder(
            container: container,
            codingPath: codingPath,
            userInfo: userInfo
        )
    }
    
}

extension PlistWrapperDecoderImp {
    
    
    
    struct SingleValueDecoder {
        
        let container:PlistWrapper
        
        var codingPath: [CodingKey]
        
        var userInfo: [CodingUserInfoKey : Any]
        
    }
    
    struct UnkeyedDecoder {
        
        let container:[PlistWrapper]
        
        var codingPath: [CodingKey]
        
        var userInfo: [CodingUserInfoKey : Any]
        
        private(set) var currentIndex: Int = 0
    }
    
    struct KeyedDecoder<Key:CodingKey> {
        
        let dictionary:[String:PlistWrapper]
        
        var codingPath: [CodingKey]
        
        var userInfo: [CodingUserInfoKey : Any]
        
    }
    
}

extension PlistWrapperDecoderImp.SingleValueDecoder: SingleValueDecodingContainer {
    
    func decodeNil() -> Bool {
       false
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        switch container {
        case .bool(let bool):
            return bool
        default:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: container.typeMissmatchDescription(for: type))
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    func decode(_ type: String.Type) throws -> String {
        switch container {
        case .string(let string):
            return string
        default:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: container.typeMissmatchDescription(for: type))
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    func decodeBinaryFloating<T:BinaryFloatingPoint>(_ type:T.Type) throws -> T {
        switch container {
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
        default:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: container.typeMissmatchDescription(for: type))
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    func decodeInteger<T:FixedWidthInteger>(_ type:T.Type) throws -> T {
        switch container {
        case .integer(let integer):
            if let value = T.init(exactly: integer) {
                return value
            } else {
                let context = DecodingError.Context(codingPath: codingPath, debugDescription: "\(integer) does not fit in \(type)")
                throw DecodingError.typeMismatch(type, context)
            }
        default:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: container.typeMissmatchDescription(for: type))
            throw DecodingError.typeMismatch(type, context)
        }
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
        switch container {
        case .data(let data) where type == Data.self:
            return data as! T
        case .date(let  date) where type == Date.self:
            return date as! T
        default:
            break
        }
        let decoder = PlistWrapperDecoderImp(container: container, codingPath: codingPath, userInfo: userInfo)
        return try T(from: decoder)
    }
    
    
}



extension PlistWrapperDecoderImp.UnkeyedDecoder: UnkeyedDecodingContainer {

    var count: Int? { container.count }
    
    var isAtEnd: Bool {
        if (container.isEmpty) {
            return true
        } else {
            return !container.indices.contains(currentIndex)
        }
    }
    
    
    func checkEnd() throws {
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        if isAtEnd {
            let context = DecodingError.Context(codingPath: currentPath, debugDescription: "Unkeyed container is at end.")
            throw DecodingError.valueNotFound(Never.self, context)
        }
    }
    
    mutating func decodeNil() throws -> Bool {
        try checkEnd()
        return false
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try checkEnd()
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        let item = container[currentIndex]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: [String:Any].self))
        switch item {
        
        case .object(let object):
            currentIndex += 1
            let newDecoder = PlistWrapperDecoderImp.KeyedDecoder<NestedKey>(dictionary: object, codingPath: currentPath, userInfo: userInfo)
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
        case .array(let array):
            currentIndex += 1
            return Self(container: array, codingPath: currentPath, userInfo: userInfo)
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
        
        currentIndex += 1
        let newDecoder = PlistWrapperDecoderImp(container: object, codingPath: currentPath, userInfo: userInfo)
        return newDecoder
    }
    
    mutating func decodeInteger<T:FixedWidthInteger>(_ type:T.Type) throws -> T {
        try checkEnd()
        let currentPath = codingPath + [TetraCodingKey(index: currentIndex)]
        let item = container[currentIndex]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        
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
        let container = PlistWrapperDecoderImp.SingleValueDecoder(container: item, codingPath: currentPath, userInfo: userInfo)
        let value = try container.decode(type)
        currentIndex += 1
        return value
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


extension PlistWrapperDecoderImp.KeyedDecoder: KeyedDecodingContainerProtocol {
    
    var allKeys: [Key] { dictionary.keys.compactMap(Key.init)}
    
    func contains(_ key: Key) -> Bool {
        dictionary.keys.contains(key.stringValue)
    }
    
    func getValue(forKey key: some CodingKey) throws -> PlistWrapper {
        guard let value = dictionary[key.stringValue] else {
            throw DecodingError.keyNotFound(key, .init(
                codingPath: codingPath,
                debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."
            ))
        }
        return value
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        guard dictionary[key.stringValue] != nil else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\").")
            throw DecodingError.keyNotFound(key, context)
        }
        return false
    }
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let item = try getValue(forKey: key)
        let context = DecodingError.Context(codingPath: codingPath + [key], debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        case .bool(let bool):
            return bool
       
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
        
        default:
            throw DecodingError.typeMismatch(type, context)
        }
    }
    
    func decodeInteger<T:FixedWidthInteger>(_ type: T.Type, forKey key:Key) throws -> T {
        let item = try getValue(forKey: key)
        let currentPath = codingPath + [key]
        let context = DecodingError.Context(codingPath: currentPath, debugDescription: item.typeMissmatchDescription(for: type))
        switch item {
        
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
        let container = PlistWrapperDecoderImp.SingleValueDecoder(container: item, codingPath: codingPath + [key], userInfo: userInfo)
        return try container.decode(type)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let item = try getValue(forKey: key)
        let context = DecodingError.Context(codingPath: codingPath + [key], debugDescription: item.typeMissmatchDescription(for: [String:Any].self))
        switch item {
        case .object(let dictionary):
            let container = PlistWrapperDecoderImp.KeyedDecoder<NestedKey>(dictionary: dictionary, codingPath: codingPath + [key], userInfo: userInfo)
            return .init(container)
        
        default:
            throw DecodingError.typeMismatch(KeyedDecodingContainer<NestedKey>.self, context)
        }
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let item = try getValue(forKey: key)
        let context = DecodingError.Context(codingPath: codingPath + [key], debugDescription: item.typeMissmatchDescription(for: [Any].self))
        switch item {
        case .array(let array):
            let container = PlistWrapperDecoderImp.UnkeyedDecoder(container: array, codingPath: codingPath + [key], userInfo: userInfo)
            return container
       
        default:
            throw DecodingError.typeMismatch(UnkeyedDecodingContainer.self, context)
        }
    }
    
    func superDecoder() throws -> Decoder {
        let item = try getValue(forKey: TetraCodingKey.super)
        return PlistWrapperDecoderImp(container: item, codingPath: codingPath + [TetraCodingKey.super], userInfo: userInfo)
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        let item = try getValue(forKey: key)
        return PlistWrapperDecoderImp(container: item, codingPath: codingPath + [key], userInfo: userInfo)
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
