//
//  BackportedCell.swift
//
//
//  Created by 박병관 on 6/26/24.
//
package import Builtin

//@available(macOS 26.0.0, *)
@_rawLayout(likeArrayOf: T, count: 5, movesAsLike)
package struct FiveArray<T:~Copyable>:~Copyable {
    @_transparent
    @usableFromInline
    package var _rawAddress: Builtin.RawPointer {
        Builtin.addressOfRawLayout(self)
    }
    @_transparent
    @usableFromInline
    package var _address: UnsafeMutableBufferPointer<T> {
        .init(start: .init(_rawAddress), count: 5)
    }
    
    public init<E>(initializingWith initializer: (inout OutputSpan<T>) throws(E) -> Void) throws(E) where E : Error {
        var span = unsafe OutputSpan(buffer: _address, initializedCount: 0)
        try initializer(&span)
        let count = span.finalize(for: _address)
        
        precondition(5 == count)
    }
    
    deinit {
        _address.deinitialize()
    }
    public
    var span:Span<T> {
        @_lifetime(borrow self)
        borrowing get {
            _overrideLifetime(Span(_unsafeStart: UnsafePointer<T>(_rawAddress), count: 5), borrowing: self)
        }
    }
    public
    var mutableSpan:MutableSpan<T> {
        @_lifetime(&self)
        mutating get {
            _overrideLifetime(MutableSpan(_unsafeStart: UnsafeMutablePointer<T>(_rawAddress), count:5), mutating: &self)
        }
    }
    
    package subscript (index: Int) -> T {
        borrowing _read {
            yield _address[index]
        }
        mutating _modify {
            yield &_address[index]
        }
    }
    
}

@_rawLayout(likeArrayOf: T, count: 3, movesAsLike)
package struct ThreeArray<T:~Copyable>:~Copyable {
    @_transparent
    @usableFromInline
    package var _rawAddress: Builtin.RawPointer {
        Builtin.addressOfRawLayout(self)
    }
    @_transparent
    @usableFromInline
    package var _address: UnsafeMutableBufferPointer<T> {
        .init(start: .init(_rawAddress), count: 3)
    }
    
    public init<E>(initializingWith initializer: (inout OutputSpan<T>) throws(E) -> Void) throws(E) where E : Error {
        var span = unsafe OutputSpan(buffer: _address, initializedCount: 0)
        try initializer(&span)
        let count = span.finalize(for: _address)
        
        precondition(5 == count)
    }
    
    deinit {
        _address.deinitialize()
    }
    public
    var span:Span<T> {
        @_lifetime(borrow self)
        borrowing get {
            _overrideLifetime(Span(_unsafeStart: UnsafePointer<T>(_rawAddress), count: 3), borrowing: self)
        }
    }
    public
    var mutableSpan:MutableSpan<T> {
        @_lifetime(&self)
        mutating get {
            _overrideLifetime(MutableSpan(_unsafeStart: UnsafeMutablePointer<T>(_rawAddress), count:3), mutating: &self)
        }
    }
    
    package subscript (index: Int) -> T {
        borrowing _read {
            yield _address[index]
        }
        mutating _modify {
            yield &_address[index]
        }
    }
    
}

@frozen
@usableFromInline
@_rawLayout(like: Value, movesAsLike)
package struct BackportedCell<Value: ~Copyable>: ~Copyable {

    @_transparent
    @usableFromInline
    package var _address: UnsafeMutablePointer<Value> {
        UnsafeMutablePointer<Value>(_rawAddress)
    }
    
    @_transparent
//    @usableFromInline
    public var _rawAddress: Builtin.RawPointer {
        Builtin.addressOfRawLayout(self)
    }
    
    @_transparent
    @usableFromInline
    package init(_ initialValue: consuming Value) {
        _address.initialize(to: initialValue)
    }
        
    @inlinable
    deinit {
        _address.deinitialize(count: 1)
    }
    
}
