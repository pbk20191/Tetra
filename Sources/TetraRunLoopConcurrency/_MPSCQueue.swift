//
//  BufferNode.swift
//  Tetra
//
//  Created by 박병관 on 2/12/26.
//

import CriticalSection
import Atomics
//import Synchronization



internal struct _MPSCQueue<Element: ~Copyable>: ~Copyable, @unchecked Sendable {

    
    @usableFromInline
    struct ForwardItem: RawRepresentable, AtomicValue, AtomicOptionalWrappable {
        @usableFromInline
        var rawValue: UnsafeMutableRawPointer
        @usableFromInline
        var pointer:UnsafeMutablePointer<BufferNode> {
            _read {
                yield rawValue.assumingMemoryBound(to: BufferNode.self)
            }
            set {
                rawValue = .init(newValue)
            }
            @storageRestrictions(initializes: rawValue)
            init(newValue) {
                rawValue = .init(newValue)
            }
        }
        
        @usableFromInline
        init(rawValue: UnsafeMutableRawPointer) {
            self.rawValue = rawValue
        }
        @usableFromInline
        init(_ pointer:UnsafeMutablePointer<BufferNode>) {
            self.pointer = pointer
        }
    }
    
    @usableFromInline
    internal struct BufferNode: ~Copyable {
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        internal let next: AtomicStore<ForwardItem?> = .init(nil)
        
        @inlinable
        internal init(data: consuming Element?) {
            self.data = data
        }
    }
    
    
    @usableFromInline
    internal struct Header:Copyable {
        @usableFromInline
        internal var capacity:Int
    }
    
    @usableFromInline
    internal let head: AtomicStore<ForwardItem>
    
    @usableFromInline
    internal let tail: AtomicStore<ForwardItem>
    
    @usableFromInline
    internal let cache: _SPMCBoundedQueue<ForwardItem>
    
    @inlinable
    public var wasFull: Bool { false }

    @inlinable
    public init(cacheSize: Int = 1024) {
        
        let node = UnsafeMutablePointer<BufferNode>.allocate(capacity: 1)
        node.initialize(to: BufferNode(data: nil))
        self.head = AtomicStore(.init(node))
        self.tail = AtomicStore(.init(node))
        self.cache = _SPMCBoundedQueue(size: cacheSize)
    }
    
    deinit {
        while let _ = dequeue() {}
        while let node = cache.dequeue() {
            node.pointer.deinitialize(count: 1)
            node.pointer.deallocate()
        }
        tail.load(ordering: .relaxed).pointer.deinitialize(count: 1)
        tail.load(ordering: .relaxed).pointer.deallocate()
    }
    
    @inlinable
    public func flushCache() {
        while let node = cache.dequeue() {
            node.pointer.deinitialize(count: 1)
            node.pointer.deallocate()
        }
    }
    
    @inlinable
    public func enqueue(_ value: consuming sending Element) -> sending Element? {
        let bufferNode = allocateNode()
        bufferNode.pointee.data = consume value
        let previous = tail.exchange(.init(bufferNode), ordering: .acquiringAndReleasing).pointer
        previous.pointee.next.store(.init(bufferNode), ordering: .releasing)
        return nil
    }
    
    @inlinable
    public func dequeue() -> sending Element? {
        let currentHead = head.load(ordering: .relaxed)
        guard let next = currentHead.pointer.pointee.next.load(ordering: .acquiring)?.pointer else {
            return nil
        }
        let result = next.pointee.data.take()
        
        head.store(.init(next), ordering: .releasing)
        let dummy = Int(bitPattern: currentHead.rawValue)
        if let dropped = cache.enqueue(.init(rawValue: .init(bitPattern: dummy)!))?.pointer {
            dropped.deinitialize(count: 1)
            dropped.deallocate()
        }
        return result
    }
    
    @inline(__always)
    public func withFirst<T:~Copyable,Failure:Error>(_ body: (borrowing Element?) throws(Failure) -> T) throws(Failure) -> T {
        let currentHead = head.load(ordering: .relaxed).pointer
        guard let next = currentHead.pointee.next.load(ordering: .acquiring)?.pointer else {
            return try body(nil)
        }
        let first = next.pointee.data.take()
        let result = try body(first)
        next.pointee.data = first
        return result
    }

    @inline(__always)
    public func dequeueAll(_ closure: (consuming sending Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
    
    @inlinable
    internal func allocateNode() -> UnsafeMutablePointer<BufferNode> {
        if let node = cache.dequeue()?.pointer {
            node.pointee.next.store(nil, ordering: .relaxed)
            return node
        }
        let node: UnsafeMutablePointer<BufferNode> = .allocate(capacity: 1)
        node.initialize(to: BufferNode(data: nil))
        return node
    }
}

