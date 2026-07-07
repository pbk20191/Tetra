//
//  MPMCBoundedQueue.swift
//  Tetra
//
//  Created by 박병관 on 2/14/26.
//
import Atomics
import CriticalSection

internal struct MPMCBoundedQueue<Element: ~Copyable>: ~Copyable, @unchecked Sendable {
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
        
        @inlinable
        init() {
            self.data = nil
        }
    }
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal let buffer: ManagedBuffer<Int, BufferNode>
    
    @usableFromInline
    internal let head: AtomicStore<Int> = .init(0)
    
    @usableFromInline
    internal let tail: AtomicStore<Int> = .init(0)
    
    public var count: Int {
        let headIndex = head.load(ordering: .relaxed)
        let tailIndex = tail.load(ordering: .relaxed)
        return tailIndex < headIndex ? (buffer.header - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public var wasFull: Bool {
        buffer.header - count == 1
    }
    
    public init(size: Int) {
        let size = size.nextPowerOf2()
        self.mask = size - 1
        self.buffer = .create(minimumCapacity: size, makingHeaderWith: { _ in
            size
        })
        buffer.withUnsafeMutablePointerToElements {
            let pointer = UnsafeMutableBufferPointer(start: $0, count: size)
            for i in 0..<size {
                pointer.baseAddress?.advanced(by: i).initialize(to: BufferNode())
                pointer[i].sequence.store(i, ordering: .relaxed)
            }
        }
        
    }
    
    deinit {
        while dequeue() != nil {}
        buffer.withUnsafeMutablePointers {
            let _ = UnsafeMutableBufferPointer(start: $1, count: $0.pointee).deinitialize()
        }
    }
    
    @discardableResult
    @inlinable
    public func enqueue(_ value: consuming sending Element) -> sending Element? {
        var result:Element? = consume value
        return buffer.withUnsafeMutablePointers {
            
            let pointer = UnsafeMutableBufferPointer(start: $1, count: $0.pointee)
            var node: UnsafeMutablePointer<BufferNode>!
            var pos = tail.load(ordering: .relaxed)
            
            while true {
                node = pointer.baseAddress?.advanced(by: pos & mask)
                let seq = node.pointee.sequence.load(ordering: .acquiring)
                let difference = seq - pos
                
                if difference == 0 {
                    if tail.weakCompareExchange(expected: pos,
                                                desired: pos + 1,
                                                successOrdering: .relaxed,
                                                failureOrdering: .relaxed).exchanged {
                        break
                    }
                } else if difference < 0 {
                    let a = consume result
                    result = nil
                    return a
                } else {
                    pos = tail.load(ordering: .relaxed)
                }
            }
            swap(&node.pointee.data, &result)
            
            node.pointee.sequence.store(pos + 1, ordering: .releasing)
            return nil
        }
       
    }
    
    @inlinable
    public func dequeue() -> sending Element? {
        return buffer.withUnsafeMutablePointers {
            let pointer = UnsafeMutableBufferPointer(start: $1, count: $0.pointee)
            var node: UnsafeMutablePointer<BufferNode>!
            var pos = head.load(ordering: .relaxed)
            
            while true {
                node = pointer.baseAddress?.advanced(by: pos & mask)
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
            var result: Element? = nil
            swap(&result, &node.pointee.data)
//            let result = node.pointee.data.move()
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
