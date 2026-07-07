//
//  ThreeElement.swift
//  Tetra
//
//  Created by 박병관 on 7/7/26.
//


struct ThreeElement<T:~Copyable>:~Copyable {
    var e0: T
    var e1: T
    var e2: T

    init(_ body: (Int) -> T) {
        e0 = body(0)
        e1 = body(1)
        e2 = body(2)
    }



    init(repeating value: T) where T:Copyable{
        self.init { _ in value }
    }

    var indices: Range<Int> { 0..<3 }

    subscript(i: Int) -> T {
        _read {
            switch i {
            case 0: yield e0
            case 1: yield e1
            case 2: yield e2
            default: preconditionFailure("ThreeElement index out of bounds: \(i)")
            }
        }
        _modify {
            switch i {
            case 0: yield &e0
            case 1: yield &e1
            case 2: yield &e2
            default: preconditionFailure("ThreeElement index out of bounds: \(i)")
            }
        }
    }
}

extension ThreeElement: Sendable where T: Sendable {}
extension ThreeElement:Copyable where T:Copyable {}
extension ThreeElement:BitwiseCopyable where T:BitwiseCopyable {}

/// Five inline elements, indexable `0...4` — the QoS ready lanes. Supports noncopyable
/// `T` (the per-lane MPSC queues and QoS-override atomics).
internal struct FiveElement<T: ~Copyable>: ~Copyable {
    var e0: T
    var e1: T
    var e2: T
    var e3: T
    var e4: T

    public init(_ body: (Int) -> T) {
        e0 = body(0)
        e1 = body(1)
        e2 = body(2)
        e3 = body(3)
        e4 = body(4)
    }
    init(repeating value: T) where T:Copyable{
        self.init { _ in value }
    }

    public var indices: Range<Int> { 0..<5 }
    public var startIndex: Int { 0 }
    public var endIndex: Int { 5 }

    public subscript(i: Int) -> T {
        _read {
            switch i {
            case 0: yield e0
            case 1: yield e1
            case 2: yield e2
            case 3: yield e3
            case 4: yield e4
            default: preconditionFailure("FiveElement index out of bounds: \(i)")
            }
        }
      _modify {
        switch i {
        case 0: yield &e0
        case 1: yield &e1
        case 2: yield &e2
        case 3: yield &e3
        case 4: yield &e4
        default: preconditionFailure("FiveElement index out of bounds: \(i)")
        }
      }

    }
}

extension FiveElement: Sendable where T: Sendable & ~Copyable {}
extension FiveElement: Copyable where T:Copyable {}
extension FiveElement: BitwiseCopyable where T:BitwiseCopyable {}
