//
//  _SPMCBoundedQueue.swift
//  Tetra
//
//  Created by 박병관 on 2/12/26.
//
import Atomics
import CriticalSection


internal struct _SPMCBoundedQueue<Element:~Copyable>: ~Copyable, @unchecked Sendable {
    
    @usableFromInline
    internal struct Header {
        
        @usableFromInline
        var capacity:Int

        
        @usableFromInline
        var tail = 0
        
    }
    
    @usableFromInline
    internal struct BufferNode: ~Copyable {
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        internal let sequence: AtomicStore<Int> = .init(0)
        
        @inlinable
        init(data: consuming Element) {
            self.data = consume data
        }
        
        init() {
            self.data = nil
        }
    }
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal let _buffer: ManagedBuffer<Header,BufferNode>
    
    @usableFromInline
    internal let head: AtomicStore<Int> = .init(0)
    
    public var count: Int {
        let headIndex = head.load(ordering: .relaxed)
        let tailIndex = _buffer.header.tail
        return tailIndex < headIndex ? (_buffer.header.capacity - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public var wasFull: Bool {
        _buffer.header.capacity - count == 1
    }
    
    public init(size: Int) {
        let size = size.nextPowerOf2()
        self.mask = size - 1
        self._buffer = .create(minimumCapacity: size, makingHeaderWith: { ref in
            .init(capacity: size, tail: 0)
        })
        _buffer.withUnsafeMutablePointers { headPtr, buffPtr in
            let buffer = UnsafeMutableBufferPointer(start: buffPtr, count: headPtr.pointee.capacity)
            for i in 0..<size {
                buffer.initializeElement(at: i, to: BufferNode())
                buffer[i].sequence.store(i, ordering: .releasing)
            }
        }

    }
    
    deinit {
        while dequeue() != nil {}
        _buffer.withUnsafeMutablePointers { headPtr, buffPtr in
            let buffer = UnsafeMutableBufferPointer(start: buffPtr, count: headPtr.pointee.capacity)
            buffer.deinitialize()
        }
    }
    
    @discardableResult
    @inlinable
    public func enqueue(_ value: consuming sending Element) -> sending Element? {
        let pos = _buffer.header.tail
        var result:Element? = consume value
        _buffer.withUnsafeMutablePointers { headPtr, buffPtr in
            let buffer = UnsafeMutableBufferPointer(start: buffPtr, count: headPtr.pointee.capacity)
            let node: UnsafeMutablePointer<BufferNode> = buffer.baseAddress!.advanced(by: pos & mask)
            let seq = node.pointee.sequence.load(ordering: .acquiring)
            let difference = seq - pos
            
            if difference == 0 {
                headPtr.pointee.tail += 1
            } else if difference < 0 {
                return
            }
            node.pointee.data = consume result
            result = nil
            node.pointee.sequence.store(pos + 1, ordering: .releasing)
            return
        }
        return result
    }
    
    @inlinable
    public func dequeue() -> sending Element? {
        return _buffer.withUnsafeMutablePointers { headPtr, buffPtr in
            let buffer = UnsafeMutableBufferPointer(start: buffPtr, count: headPtr.pointee.capacity)
            var node: UnsafeMutablePointer<BufferNode>!
            var pos = head.load(ordering: .relaxed)
            
            while true {
                
                node = buffer.baseAddress!.advanced(by: pos & mask)
                let seq = node.pointee.sequence.load(ordering: .acquiring)
                let difference = seq - (pos + 1)
                
                if difference == 0 {
                    if head.weakCompareExchange(expected: pos, desired: pos + 1, successOrdering: .relaxed, failureOrdering: .relaxed).exchanged {
                        break
                    }
                } else if difference < 0 {
                    return nil
                } else {
                    pos = head.load(ordering: .relaxed)
                }
            }
            var result:Element? = nil
            swap(&result, &node.pointee.data)
            node.pointee.sequence.store(pos + mask + 1, ordering: .releasing)
            return result
        }

    }
    
    @inline(__always)
    public func dequeueAll(_ closure: (consuming sending Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
    
}
extension FixedWidthInteger {
    /// Returns the next power of two.
    @inlinable
    @_transparent
    func nextPowerOf2() -> Self {
        guard self != 0 else {
            return 1
        }
        return 1 << (Self.bitWidth - (self - 1).leadingZeroBitCount)
    }
}
