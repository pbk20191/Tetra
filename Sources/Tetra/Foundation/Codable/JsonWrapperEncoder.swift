//
//  JsonWrapperEncoder.swift
//  
//
//  Created by pbk on 2023/05/27.
//

import Foundation
import Combine

public struct JsonWrapperEncoder: TopLevelEncoder {
    
    
    public var userInfo: [CodingUserInfoKey : Any] = [:]
    
    public init() {
        
    }
    
    public func encode<T>(_ value: T) throws -> JsonWrapper where T : Encodable {
        let container = JSONReference.emptyContainer
        try value.encode(to: EncoderImp(ref: container, codingPath: [], userInfo: userInfo))
        defer { container.backing = nil }
        switch container.unwrap() {
        case .none:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Top-level \(T.self) did not encode any values."
                )
            )
        case .some(let value):
            return value
        }
        
    }
    
    
}


extension JsonWrapperEncoder {
    
    struct EncoderImp {
        
        let ref:JSONReference
        let codingPath: [CodingKey]
        
        let userInfo: [CodingUserInfoKey : Any]
    }
    
    struct KeyedEncoder<Key:CodingKey> {
        
        let ref:JSONReference
        let codingPath: [CodingKey]
        
        let userInfo: [CodingUserInfoKey : Any]
        
    }
    
    struct UnkeyedEncoder {
        
        let ref:JSONReference
        let codingPath: [CodingKey]
        
        let userInfo: [CodingUserInfoKey : Any]
    }
    
    struct SingleEncoder {
        
        let ref:JSONReference
        let codingPath: [CodingKey]
        
        let userInfo: [CodingUserInfoKey : Any]
        
    }
    
}

extension JsonWrapperEncoder.SingleEncoder: SingleValueEncodingContainer {
    
    private func assertCanEncodeNewValue() {
        precondition(ref.backing == nil, "Attempt to encode value through single value container when previously value already encoded.")
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        assertCanEncodeNewValue()
        switch value {
        case let v as JsonWrapper:
            ref.backing = .primitive(v)
        case let v as [JsonWrapper]:
            ref.backing = .primitive(.array(v))
        case let v as [String:JsonWrapper]:
            ref.backing = .primitive(.object(v))
        default:
            let encoder = JsonWrapperEncoder.EncoderImp(ref: ref, codingPath: codingPath, userInfo: userInfo)
            try value.encode(to: encoder)
        }

    }
    
    func encodeNil() throws {
        assertCanEncodeNewValue()
        ref.backing = .primitive(.null)
    }
    
    func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.bool(value).backing
    }
    
    func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.string(value).backing
    }
    
    func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.float(value).backing
    }
    
    func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.float(value.isSignalingNaN ? .signalingNaN : Double(value)).backing
    }
    
    func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.integer(value).backing
    }
    
    func encode(_ value: Int8) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int16) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int32) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int64) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt8) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt16) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt32) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt64) throws {
        try encode(Int(value))
    }
    
}

extension JsonWrapperEncoder.EncoderImp: Encoder {
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        switch ref.backing {
        case .none:
            ref.backing = .object([:])
            fallthrough
        case .object(_):
            let container = JsonWrapperEncoder.KeyedEncoder<Key>(ref: ref, codingPath: codingPath, userInfo: userInfo)
            return .init(container)
        default:
            preconditionFailure("Attempt to create new keyed encoding container when already previously encoded at this path.")
        }
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        switch ref.backing {
        case .none:
            ref.backing = .array([])
            fallthrough
        case .array(_):
            return JsonWrapperEncoder.UnkeyedEncoder(ref: ref, codingPath: codingPath, userInfo: userInfo)
        default:
            preconditionFailure("Attempt to create new unkeyed encoding container when already previously encoded at this path.")
        }
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        precondition(ref.backing == nil, "Attempt to create new single encoding container when already previously encoded at this path.")
        return JsonWrapperSingleEncoder2(ref: ref, codingPath: codingPath, userInfo: userInfo)
    }
}

extension JsonWrapperEncoder.KeyedEncoder: KeyedEncodingContainerProtocol {
    
    func encodeNil(forKey key: Key) throws {
        ref.insert(.null, for: key.stringValue)
    }
    
    func encode(_ value: Bool, forKey key: Key) throws {
        ref.insert(.bool(value), for: key.stringValue)
    }
    
    func encode(_ value: String, forKey key: Key) throws {
        ref.insert(.string(value), for: key.stringValue)
    }
    
    func encode(_ value: Double, forKey key: Key) throws {
        ref.insert(.float(value), for: key.stringValue)
    }
    
    func encode(_ value: Float, forKey key: Key) throws {
        ref.insert(.float(value.isSignalingNaN ? .signalingNaN : Double(value)), for: key.stringValue)
    }
    
    func encode(_ value: Int, forKey key: Key) throws {
        ref.insert(.integer(value), for: key.stringValue)
    }
    
    func encode(_ value: Int8, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }
    
    func encode(_ value: Int16, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }
    
    func encode(_ value: Int32, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }
    
    func encode(_ value: Int64, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }
    
    func encode(_ value: UInt, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }
    
    func encode(_ value: UInt8, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }
    
    func encode(_ value: UInt16, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }
    
    func encode(_ value: UInt32, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }
    
    func encode(_ value: UInt64, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }
    
    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        let newRef = JSONReference(.primitive(.null))
        newRef.backing = nil
        let newContainer = JsonWrapperSingleEncoder2(ref: newRef, codingPath: codingPath + [key], userInfo: userInfo)
        try newContainer.encode(value)
        ref.insert(newRef, for: key.stringValue)
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let newRef = JSONReference(.object([:]))
        ref.insert(newRef, for: key.stringValue)
        let newContainer = JsonWrapperEncoder.KeyedEncoder<NestedKey>(ref: newRef, codingPath: codingPath + [key], userInfo: userInfo)
        return .init(newContainer)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let newRef = JSONReference(.array([]))
        ref.insert(newRef, for: key.stringValue)
        let newContainer = JsonWrapperEncoder.UnkeyedEncoder(ref: newRef, codingPath: codingPath + [key], userInfo: userInfo)
        return newContainer
    }
    
    func superEncoder() -> Encoder {
        let newRef = JSONReference.emptyContainer
        let newEncoder = JsonWrapperEncoder.EncoderImp(ref: newRef, codingPath: codingPath + [TetraCodingKey.super], userInfo: userInfo)
        ref.insert(newRef, for: TetraCodingKey.super.stringValue)
        return newEncoder
    }
    
    func superEncoder(forKey key: Key) -> Encoder {
        let newRef = JSONReference.emptyContainer
        let newEncoder = JsonWrapperEncoder.EncoderImp(ref: newRef, codingPath: codingPath + [key], userInfo: userInfo)
        ref.insert(newRef, for: key.stringValue)
        return newEncoder
    }
    
}



extension JsonWrapperEncoder.UnkeyedEncoder: UnkeyedEncodingContainer {

    
    var count: Int { ref.count }
    
    func encodeNil() throws {
        ref.insert(.null)
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let currentPath = codingPath + [TetraCodingKey(index: count)]
        let newRef = JSONReference(.object([:]))
        ref.insert(newRef)
        let newContainer = JsonWrapperEncoder.KeyedEncoder<NestedKey>(ref: ref, codingPath: currentPath, userInfo: userInfo)
        return .init(newContainer)
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let path = codingPath + [TetraCodingKey(index: count)]
        let newRef = JSONReference(.array([]))
        ref.insert(newRef)
        let newContainer = Self(ref: newRef, codingPath: path, userInfo: userInfo)
        return newContainer
    }
    
    func superEncoder() -> Encoder {
        let newRef = JSONReference.emptyContainer
        let newEncoder = JsonWrapperEncoder.EncoderImp(ref: newRef, codingPath: codingPath + [TetraCodingKey.init(index: count)], userInfo: userInfo)
        ref.insert(newRef)
        return newEncoder
    }
    
    
    func encode(_ value: String) throws {
        ref.insert(.string(value))
    }
    
    func encode(_ value: Double) throws {
        ref.insert(.float(value))
    }
    
    func encode(_ value: Float) throws {
        ref.insert(.float(value.isSignalingNaN ? .signalingNaN : Double(value)))
    }
    
    func encode(_ value: Int) throws {
        ref.insert(.integer(value))
    }
    
    func encode(_ value: Int8) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int16) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int32) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int64) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt8) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt16) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt32) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt64) throws {
        try encode(Int(value))
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        let newRef = JSONReference.emptyContainer
        let container = JsonWrapperSingleEncoder2(ref: newRef, codingPath: codingPath + [TetraCodingKey(index: count)], userInfo: userInfo)
        try container.encode(value)
        ref.insert(newRef)
    }
    
    func encode(_ value: Bool) throws {
        ref.insert(.bool(value))
    }
    
}


struct JsonWrapperSingleEncoder2: SingleValueEncodingContainer {
    
    let ref:JSONReference
    let codingPath: [CodingKey]
    
    let userInfo: [CodingUserInfoKey : Any]
    
    private func assertCanEncodeNewValue() {
        precondition(ref.backing == nil, "Attempt to encode value through single value container when previously value already encoded.")
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        assertCanEncodeNewValue()
        switch value {
        case let v as JsonWrapper:
            ref.backing = .primitive(v)
        case let v as [JsonWrapper]:
            ref.backing = .primitive(.array(v))
        case let v as [String:JsonWrapper]:
            ref.backing = .primitive(.object(v))
        default:
            let encoder = JsonWrapperEncoder.EncoderImp(ref: ref, codingPath: codingPath, userInfo: userInfo)
            try value.encode(to: encoder)
        }

    }
    
    func encodeNil() throws {
        assertCanEncodeNewValue()
        ref.backing = .primitive(.null)
    }
    
    func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.bool(value).backing
    }
    
    func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.string(value).backing
    }
    
    func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.float(value).backing
    }
    
    func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.float(value.isSignalingNaN ? .signalingNaN : Double(value)).backing
    }
    
    func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        ref.backing = JSONReference.integer(value).backing
    }
    
    func encode(_ value: Int8) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int16) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int32) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int64) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt8) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt16) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt32) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt64) throws {
        try encode(Int(value))
    }
    
}


class JSONReference {
    
    func unwrap() -> JsonWrapper? {
        switch backing {
        case .none:
            return nil
        case .primitive(let value):
            return value
        case .object(let dictionary):
            return .object(dictionary.compactMapValues{ $0.unwrap() })
        case .array(let array):
            return .array(array.compactMap{ $0.unwrap() })
        }
    }
    
    enum Backing {

        case primitive(JsonWrapper)
        case array([JSONReference])
        case object([String:JSONReference])

    }
    
    var backing: Backing?

    @inline(__always)
    func insert(_ ref: JSONReference, for key: String) {
        guard case .object(var object) = backing else {
            preconditionFailure("Wrong underlying JSON reference type")
        }
        backing = .primitive(.null)
        object[key] = ref
        backing = .object(object)
    }

    @inline(__always)
    func insert(_ ref: JSONReference, at index: Int) {
        guard case .array(var array) = backing else {
            preconditionFailure("Wrong underlying JSON reference type")
        }
        backing = .primitive(.null)
        array.insert(ref, at: index)
        backing = .array(array)
    }

    @inline(__always)
    func insert(_ ref: JSONReference) {
        guard case .array(var array) = backing else {
            preconditionFailure("Wrong underlying JSON reference type")
        }
        backing = .primitive(.null)
        array.append(ref)
        backing = .array(array)
    }

    @inline(__always)
    var count: Int {
        switch backing {
        case .array(let array): return array.count
        case .object(let dict): return dict.count
        default: preconditionFailure("Count does not apply to count")
        }
    }

    @inline(__always)
    init(_ backing: Backing) {
        self.backing = backing
    }

    @inline(__always)
    subscript (_ key: String) -> JSONReference? {
        switch backing {
        case .object(let backingDict):
            return backingDict[key]
        default:
            preconditionFailure("Wrong underlying JSON reference type")
        }
    }

    @inline(__always)
    subscript (_ index: Int) -> JSONReference {
        switch backing {
        case .array(let array):
            return array[index]
        default:
            preconditionFailure("Wrong underlying JSON reference type")
        }
    }

    static var null : JSONReference { .init(.primitive(.null)) }
    static func string(_ str: String) -> JSONReference { .init(.primitive(.string(str))) }
    static func integer<T:FixedWidthInteger>(_ str: T) -> JSONReference { .init(.primitive(.integer(Int(str)))) }
    static func float<T:BinaryFloatingPoint>(_ number:T) -> JSONReference { .init(.primitive(.double(number.isSignalingNaN ? .signalingNaN : Double(number))))}
    static let `true` : JSONReference = .init(.primitive(.bool(true)))
    static let `false` : JSONReference = .init(.primitive(.bool(false)))
    static func bool(_ b: Bool) -> JSONReference { b ? .true : .false }
    static var emptyArray : JSONReference { .init(.array([])) }
    static var emptyObject : JSONReference { .init(.object([:])) }
    static var emptyContainer: JSONReference {
        let item = JSONReference.null
        item.backing = nil
        return item
    }
}
