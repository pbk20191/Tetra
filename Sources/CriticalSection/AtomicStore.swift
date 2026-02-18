//
//  AtomicStore.swift
//  Tetra
//
//  Created by 박병관 on 2/14/26.
//
package import Atomics
package import Builtin

@_staticExclusiveOnly
@_rawLayout(like: Value.AtomicRepresentation, movesAsLike)
package struct AtomicStore<Value:AtomicValue>:~Copyable where Value.AtomicRepresentation.Value == Value {
    
    @_transparent
    @usableFromInline
    package var _address: UnsafeMutablePointer<Value.AtomicRepresentation> {
        UnsafeMutablePointer<Value.AtomicRepresentation>(_rawAddress)
    }
    
    @_transparent
    @inline(__always)
    @usableFromInline
    internal var _rawAddress: Builtin.RawPointer {
        Builtin.addressOfRawLayout(self)
    }
    
    @_transparent
    @usableFromInline
    package init(_ initialValue: consuming Value) {
        _address.initialize(to: Value.AtomicRepresentation(initialValue))
    }
        
    @inlinable
    deinit {
        let _ = _address.pointee.dispose()
    }
    
    
    @usableFromInline
    @inline(__always)
    @_transparent
    var _ptr:UnsafeMutablePointer<_Storage> {
        _address
    }
    
    
    @usableFromInline
    @inline(__always)
    @_transparent
    var store:UnsafeAtomic<Value> {
        .init(at: _address)
    }
    
    @usableFromInline
    typealias _Storage = Value.AtomicRepresentation

}








 extension AtomicStore {
    


//    typealias Atomic
    
  /// Atomically loads and returns the current value, applying the specified
  /// memory ordering.
  ///
  /// - Parameter ordering: The memory ordering to apply on this operation.
  /// - Returns: The current value.
  @_semantics("atomics.requires_constant_orderings")
     @inlinable
  @_transparent
//     @_alwaysEmitIntoClient
  public func load(
    ordering: AtomicLoadOrdering
  ) -> Value {
//    _Storage.atomicLoad(at: _ptr, ordering: ordering)
      store.load(ordering: ordering)
  }

  /// Atomically sets the current value to `desired`, applying the specified
  /// memory ordering.
  ///
  /// - Parameter desired: The desired new value.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  @_semantics("atomics.requires_constant_orderings")
  @_transparent
     //@_alwaysEmitIntoClient
  public func store(
    _ desired: consuming Value,
    ordering: AtomicStoreOrdering
  ) {
    _Storage.atomicStore(desired, at: _ptr, ordering: ordering)
  }

  /// Atomically sets the current value to `desired` and returns the original
  /// value, applying the specified memory ordering.
  ///
  /// - Parameter desired: The desired new value.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  /// - Returns: The original value.
  @_semantics("atomics.requires_constant_orderings")
  @_transparent
     //@_alwaysEmitIntoClient
  public func exchange(
    _ desired: consuming Value,
    ordering: AtomicUpdateOrdering
  ) -> Value {
    _Storage.atomicExchange(desired, at: _ptr, ordering: ordering)
  }

  /// Perform an atomic compare and exchange operation on the current value,
  /// applying the specified memory ordering.
  ///
  /// This operation performs the following algorithm as a single atomic
  /// transaction:
  ///
  /// ```
  /// atomic(self) { currentValue in
  ///   let original = currentValue
  ///   guard original == expected else { return (false, original) }
  ///   currentValue = desired
  ///   return (true, original)
  /// }
  /// ```
  ///
  /// This method implements a "strong" compare and exchange operation
  /// that does not permit spurious failures.
  ///
  /// - Parameter expected: The expected current value.
  /// - Parameter desired: The desired new value.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  /// - Returns: A tuple `(exchanged, original)`, where `exchanged` is true if
  ///   the exchange was successful, and `original` is the original value.
  @_semantics("atomics.requires_constant_orderings")
  @_transparent
     //@_alwaysEmitIntoClient
  public func compareExchange(
    expected:consuming Value,
    desired: consuming Value,
    ordering: AtomicUpdateOrdering
  ) -> (exchanged: Bool, original: Value) {
    _Storage.atomicCompareExchange(
      expected: expected,
      desired: desired,
      at: _ptr,
      ordering: ordering)
  }

  /// Perform an atomic compare and exchange operation on the current value,
  /// applying the specified success/failure memory orderings.
  ///
  /// This operation performs the following algorithm as a single atomic
  /// transaction:
  ///
  /// ```
  /// atomic(self) { currentValue in
  ///   let original = currentValue
  ///   guard original == expected else { return (false, original) }
  ///   currentValue = desired
  ///   return (true, original)
  /// }
  /// ```
  ///
  /// The `successOrdering` argument specifies the memory ordering to use when
  /// the operation manages to update the current value, while `failureOrdering`
  /// will be used when the operation leaves the value intact.
  ///
  /// This method implements a "strong" compare and exchange operation
  /// that does not permit spurious failures.
  ///
  /// - Parameter expected: The expected current value.
  /// - Parameter desired: The desired new value.
  /// - Parameter successOrdering: The memory ordering to apply if this
  ///    operation performs the exchange.
  /// - Parameter failureOrdering: The memory ordering to apply on this
  ///    operation does not perform the exchange.
  /// - Returns: A tuple `(exchanged, original)`, where `exchanged` is true if
  ///   the exchange was successful, and `original` is the original value.
  @_semantics("atomics.requires_constant_orderings")
  @_transparent
     //@_alwaysEmitIntoClient
  public func compareExchange(
    expected: consuming Value,
    desired: consuming Value,
    successOrdering: AtomicUpdateOrdering,
    failureOrdering: AtomicLoadOrdering
  ) -> (exchanged: Bool, original: Value) {
    _Storage.atomicCompareExchange(
      expected: expected,
      desired: desired,
      at: _ptr,
      successOrdering: successOrdering,
      failureOrdering: failureOrdering)
  }

  /// Perform an atomic weak compare and exchange operation on the current
  /// value, applying the memory ordering. This compare-exchange variant is
  /// allowed to spuriously fail; it is designed to be called in a loop until
  /// it indicates a successful exchange has happened.
  ///
  /// This operation performs the following algorithm as a single atomic
  /// transaction:
  ///
  /// ```
  /// atomic(self) { currentValue in
  ///   let original = currentValue
  ///   guard original == expected else { return (false, original) }
  ///   currentValue = desired
  ///   return (true, original)
  /// }
  /// ```
  ///
  /// (In this weak form, transient conditions may cause the `original ==
  /// expected` check to sometimes return false when the two values are in fact
  /// the same.)
  ///
  /// - Parameter expected: The expected current value.
  /// - Parameter desired: The desired new value.
  /// - Parameter ordering: The memory ordering to apply on this operation.
  /// - Returns: A tuple `(exchanged, original)`, where `exchanged` is true if
  ///   the exchange was successful, and `original` is the original value.
  @_semantics("atomics.requires_constant_orderings")
  @_transparent
     //@_alwaysEmitIntoClient
  public func weakCompareExchange(
    expected: consuming Value,
    desired: __owned Value,
    ordering: AtomicUpdateOrdering
  ) -> (exchanged: Bool, original: Value) {
    _Storage.atomicWeakCompareExchange(
      expected: expected,
      desired: desired,
      at: _ptr,
      ordering: ordering)
  }

  /// Perform an atomic weak compare and exchange operation on the current
  /// value, applying the specified success/failure memory orderings. This
  /// compare-exchange variant is allowed to spuriously fail; it is designed to
  /// be called in a loop until it indicates a successful exchange has happened.
  ///
  /// This operation performs the following algorithm as a single atomic
  /// transaction:
  ///
  /// ```
  /// atomic(self) { currentValue in
  ///   let original = currentValue
  ///   guard original == expected else { return (false, original) }
  ///   currentValue = desired
  ///   return (true, original)
  /// }
  /// ```
  ///
  /// (In this weak form, transient conditions may cause the `original ==
  /// expected` check to sometimes return false when the two values are in fact
  /// the same.)
  ///
  /// The `ordering` argument specifies the memory ordering to use when the
  /// operation manages to update the current value, while `failureOrdering`
  /// will be used when the operation leaves the value intact.
  ///
  /// - Parameter expected: The expected current value.
  /// - Parameter desired: The desired new value.
  /// - Parameter successOrdering: The memory ordering to apply if this
  ///    operation performs the exchange.
  /// - Parameter failureOrdering: The memory ordering to apply on this
  ///    operation does not perform the exchange.
  /// - Returns: A tuple `(exchanged, original)`, where `exchanged` is true if
  ///   the exchange was successful, and `original` is the original value.
  @_semantics("atomics.requires_constant_orderings")
  @_transparent
     //@_alwaysEmitIntoClient
  public func weakCompareExchange(
    expected:consuming Value,
    desired: consuming Value,
    successOrdering: AtomicUpdateOrdering,
    failureOrdering: AtomicLoadOrdering
  ) -> (exchanged: Bool, original: Value) {
    _Storage.atomicWeakCompareExchange(
      expected: expected,
      desired: desired,
      at: _ptr,
      successOrdering: successOrdering,
      failureOrdering: failureOrdering)
  }
}

