//
//  SlicedJobQueue.swift
//  Tetra
//
//  Created by 박병관 on 2/14/26.
//
import Atomics
import Darwin
import CriticalSection
import Dispatch
import Foundation
import HeapModule
import os
import Builtin

internal struct SlicedJobQueue: ~Copyable, Sendable {
    
    nonisolated(unsafe)
    let jobs:FiveArray<__MPSCQueue<UnownedJob>>
    nonisolated(unsafe)
    let boost:FiveArray<AtomicStore<UnsafeRawPointer?>>

    let cache1:__MPSCQueue<UnownedJob>.NodeCache
//    let cache2:__MPSCQueue<TimestampJob>.NodeCache

    init(cacheSize:Int = 2048) {
        let cache1 = __MPSCQueue<UnownedJob>.NodeCache(size: cacheSize)
//        let cache2 = __MPSCQueue<TimestampJob>.NodeCache(size: cacheSize / 2)
        self.cache1 = cache1
//        self.cache2 = cache2
        boost = .init(initializingWith: {
            while !$0.isFull {
                $0.append(.init(nil))
            }
        })
        jobs = .init(initializingWith: {
            while !$0.isFull {
                $0.append(.init(cache: cache1))
            }
        })
    }
    
    /// Drains the 5 ready lanes on the owning thread, highest-priority-first.
    ///
    /// Two disciplines ported from the reference engine:
    ///   * I4a (QoS-once): the per-lane `pthread_override` boosts are NOT ended
    ///     here. They are held across drains and released ONCE by the engine's
    ///     `endAllBoosts()` on the idle path (no refire) / at teardown — avoiding
    ///     per-drain start/end syscall thrash and a mid-busy priority drop. This
    ///     method only sets the *thread* QoS floor (`pthread_set_qos_class_self_np`)
    ///     per lane so the owning thread runs each lane's jobs at that lane's class.
    ///   * I4b (fairness cap): each lane's dequeue loop is capped at
    ///     `getDrainIterations(queueIndex:)`, so a high-priority flood cannot starve
    ///     the run loop's other CFRunLoop sources. A capped lane may leave jobs; the
    ///     engine pump re-checks `readyLanesEmpty()` and re-fires until empty.
    internal func runBatch(
        executor:UnownedSerialExecutor,
        taskRef: Builtin.Executor? = nil
    ) {

        let qos:DispatchQoS
        do {
            var _qos = QOS_CLASS_UNSPECIFIED
            var priority = Int32(0)
            pthread_get_qos_class_np(pthread_self(), &_qos, &priority)
            qos = .init(qosClass: .init(rawValue: _qos)!, relativePriority: .init(priority))
        }
        var currentQos = qos.qosClass.rawValue
        defer {
            pthread_set_qos_class_self_np(qos.qosClass.rawValue, .init(qos.relativePriority))
        }
        do {

            for i in 0..<5 {
                let laneQos = switch i {
                case 0:
                    QOS_CLASS_USER_INTERACTIVE
                case 1:
                    QOS_CLASS_USER_INITIATED
                case 2:
                    QOS_CLASS_DEFAULT
                case 3:
                    QOS_CLASS_UTILITY
                case 4:
                    fallthrough
                default:
                    QOS_CLASS_BACKGROUND
                }
                let iterations = getDrainIterations(queueIndex: i)
                var count = 0
                if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *), let t = taskRef {
                    let taskExecutor = UnownedTaskExecutor(t)
                    while count < iterations, let j = self.jobs[i].dequeue() {
                        if count == 0, laneQos != currentQos {
                            pthread_set_qos_class_self_np(laneQos, 0)
                            currentQos = laneQos
                        }
                        j.runSynchronously(isolatedTo: executor, taskExecutor: taskExecutor)
                        count &+= 1
                    }
                } else {
                    while count < iterations, let j = self.jobs[i].dequeue() {
                        if count == 0, laneQos != currentQos {
                            pthread_set_qos_class_self_np(laneQos, 0)
                            currentQos = laneQos
                        }
                        j.runSynchronously(on: executor)
                        count &+= 1
                    }
                }
            }
        }
    }

    /// Release every active QoS override. Called by the engine ONLY when the busy
    /// period ends (no refire) or at teardown — NOT per drain. Holding overrides
    /// across drains mirrors libdispatch's runloop-queue discipline
    /// (`_dispatch_runloop_queue_wakeup`: end the override only when the queue drains
    /// empty), avoiding per-drain start/end syscall thrash and the mid-busy priority
    /// drop that would otherwise open an inversion window.
    internal func endAllBoosts() {
        for i in 0..<5 {
            if let override = boost[i].exchange(nil, ordering: .acquiring) {
                pthread_override_qos_class_end_np(.init(override))
            }
        }
    }
    
    nonisolated func enqueue(_ job:UnownedJob, _ thread:pthread_t) {
        if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *){
            let priority = TaskPriority(job.priority)
            let index = priority?.jobQueueIndex ?? 4
            jobs[index].enqueue(job)
            // Install a QoS override for this lane only when none is active yet — the
            // hot path (a burst of same-priority jobs) then costs one acquiring load and
            // no syscall. (Was inverted `!= nil`, which never installed an override.)
            if boost[index].load(ordering: .acquiring) == nil {
                let qos = switch index {
                case 0:
                    QOS_CLASS_USER_INTERACTIVE
                case 1:
                    QOS_CLASS_USER_INITIATED
                case 2:
                    QOS_CLASS_DEFAULT
                case 3:
                    QOS_CLASS_UTILITY
                case 4:
                    fallthrough
                default:
                    QOS_CLASS_BACKGROUND
                }
                
                let override = pthread_override_qos_class_start_np(thread, qos, 0)
                let (exchanged, _) = boost[index].compareExchange(expected: nil, desired: .init(override), ordering: .releasing)
                if !exchanged {
                    pthread_override_qos_class_end_np(override)
                }
            }
        } else {
            jobs[2].enqueue(job)
        }
    }
    
    internal enum ClockIndex:Int, Sendable, BitwiseCopyable {
        case continuous
        case suspending
        case walltime
    }
    

    deinit {
//        let span = boost.span
        for i in 0..<5 {
            if let t = boost[i].exchange(nil, ordering: .relaxed) {
                pthread_override_qos_class_end_np(.init(t))
            }
        }
    }
    public struct __MPSCQueue<Element: ~Copyable>: ~Copyable, @unchecked Sendable {
        
        typealias ForwardItem = ForwardItemT

        
        @usableFromInline
        internal struct BufferNode: ~Copyable {
            @usableFromInline
            internal var data: Element?
            
            @usableFromInline
            internal let next: AtomicStore<Optional<ForwardItem>> = .init(nil)
            
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
        internal let _cache:NodeCache
        
        @usableFromInline
        final class NodeCache: Sendable {
            
            @usableFromInline
            let pool:MPMCBoundedQueue<ForwardItem>
            
            deinit {
                while let node:UnsafeMutablePointer<BufferNode> = pool.dequeue()?.load() {
                    node.deinitialize(count: 1)
                    node.deallocate()
                }
            }
            @usableFromInline
            init(size:Int = 1024) {
                pool = .init(size: size)
            }
            
            
            @preconcurrency
            @usableFromInline
            nonisolated
            func consume(_ node: consuming sending UnsafeMutablePointer<BufferNode>) {
                if let dropped = pool.enqueue(.init(rawValue: node))?.load(BufferNode.self) {
                    dropped.deinitialize(count: 1)
                    dropped.deallocate()
                }
            }
            @usableFromInline
            func dequeue() -> UnsafeMutablePointer<BufferNode>? {
                let t = pool.dequeue()?.load(BufferNode.self)
                t?.pointee.next.store(nil, ordering: .relaxed)
                return t
            }
        }
        
        @inlinable
        public init(cacheSize: Int = 1024) {
            
            let node = UnsafeMutablePointer<BufferNode>.allocate(capacity: 1)
            node.initialize(to: BufferNode(data: nil))
            self.head = .init(.init(rawValue: node))
            self.tail = .init(.init(rawValue: node))
            self._cache = .init(size: cacheSize)
        }
        
        @inlinable
        internal init(cache:NodeCache) {
            
            let node = UnsafeMutablePointer<BufferNode>.allocate(capacity: 1)
            node.initialize(to: BufferNode(data: nil))
            self.head = .init(.init(rawValue: node))
            self.tail = .init(.init(rawValue: node))
            self._cache = cache
        }
        
        deinit {
            while let _ = dequeue() {}
            let last = tail.load(ordering: .relaxed).load(BufferNode.self)
            last.deinitialize(count: 1)
            last.deallocate()
//            tail.load(ordering: .relaxed).deallocate()
        }
        

        
        @inlinable
        public func enqueue(_ value: consuming sending Element) {
            let bufferNode = allocateNode()
            bufferNode.pointee.data = consume value
            let previous = tail.exchange(.init(rawValue: bufferNode), ordering: .acquiringAndReleasing).load(BufferNode.self)
            previous.pointee.next.store(.init(rawValue: bufferNode), ordering: .releasing)
        }
        
        @inlinable
        public borrowing func dequeue() -> sending Element? {
            let currentHead = head.load(ordering: .relaxed).load(BufferNode.self)
            guard let next = currentHead.pointee.next.load(ordering: .acquiring)?.load(BufferNode.self) else {
                return nil
            }
            var result:Element? = nil
            swap(&result, &next.pointee.data)
//            let result = next.pointee.data.take()

            head.store(.init(rawValue: next), ordering: .releasing)
            do {
                let t = Int(bitPattern: currentHead)
                _cache.consume(.init(bitPattern: t)!)
            }
            return result
        }
        
        /// Consumer-side emptiness check: true when there is no dequeuable node.
        /// Mirrors `dequeue`'s producer-published-`next` protocol (an in-flight
        /// producer that has swung `tail` but not yet published `next` reads as empty,
        /// same as `dequeue` returning nil).
        @inline(__always)
        public var isEmpty: Bool {
            let currentHead = head.load(ordering: .relaxed).load(BufferNode.self)
            return currentHead.pointee.next.load(ordering: .acquiring) == nil
        }

        @inline(__always)
        public func withFirst<T:~Copyable,Failure:Error>(_ body: (borrowing Element?) throws(Failure) -> T) throws(Failure) -> T {
            let currentHead = head.load(ordering: .relaxed).load(BufferNode.self)
            guard let next = currentHead.pointee.next.load(ordering: .acquiring)?.load(BufferNode.self) else {
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
            if let node = _cache.dequeue() {
                return node
            }
            let node: UnsafeMutablePointer<BufferNode> = .allocate(capacity: 1)
            node.initialize(to: BufferNode(data: nil))
            return node
        }
    }

    
}
struct TimestampJob: Comparable {
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp.deadline < rhs.timestamp.deadline
    }
    
    static func > (lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp.deadline > rhs.timestamp.deadline
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp == rhs.timestamp
    }
    
    let timestamp:Timestamp
    let job:UnownedJob
    
    init(job:consuming UnownedJob, timestamp:Timestamp) {
        self.job = job
        self.timestamp = timestamp
    }
}

struct Timestamp:BitwiseCopyable, Hashable, Sendable, Copyable {
  /// The earliest time at which a job should run.
  ///
  /// Jobs will never be run earlier than this.
  var target: UInt64

  /// The maximum (ideal) tolerable delay.
  ///
  /// We make no guarantee that we won't run over this, but it is taken
  /// into consideration when scheduling jobs.
  var leeway: UInt64

  /// The latest time at which a job should (ideally) run.
  ///
  /// We may run the job after this point, but we will not run other jobs
  /// with later deadlines before this job.
  var deadline: UInt64 {
    get {
      if UInt64.max - target < leeway {
        return UInt64.max
      }
      return target + leeway
    }
    set {
      if newValue < leeway {
        target = 0
      } else {
        target = newValue - leeway
      }
    }
  }
}

extension TaskPriority {
    
    var jobQueueIndex:Int {
        
        if self > .high {
            0
        } else if self > .medium {
            1
        } else if self > .low {
            2
        } else if self > .background {
            3
        } else {
            4
        }
    }
    
}

/// Per-lane drain cap (I4b fairness). Ported from the reference engine's exact
/// values: userInteractive(0) is uncapped; high(1) and default(2) get 128; utility(3)
/// gets 2; background(4) gets 1. A capped lane leaves residual jobs, which the engine
/// pump drains on subsequent re-fires (see `handleReadable`'s `readyLanesEmpty` recheck).
@inlinable
@inline(__always)
internal func getDrainIterations(queueIndex: Int) -> Int {
    switch queueIndex {
        case 0: .max        // userInteractive
        case 1: 128         // high
        case 2: 128         // default
        case 3: 2           // utility
        default: 1          // background and lower
    }
}



class Backing {
    
    
    
    unowned(unsafe) var runLoop:RunLoop? = nil
    unowned(unsafe) var source:CFRunLoopSource! = nil
    var serialExecutor:UnownedSerialExecutor! = nil
    let timers = [
        DispatchSource.makeTimerSource(),
        DispatchSource.makeTimerSource(),
        DispatchSource.makeTimerSource(),
    ] as! [DispatchSource & DispatchSourceTimer]
    let store = SlicedJobQueue()
    let registry = NSMapTable<CFRunLoop, NSMutableSet>.weakToStrongObjects()
    
    open var taskRef:Builtin.Executor? { nil }
    
    required init() {
        
        timers.forEach {
            $0.setEventHandler { [unowned(unsafe) self] in
                if let s = source {
                    CFRunLoopSourceSignal(s)
                    withExtendedLifetime(s) {
                        let valueTypes = Unmanaged.passUnretained(s).toOpaque().assumingMemoryBound(to: CFRunLoopSourceOpaqeueValue.self)
                        let bag:CFBag
                        do {
                            CFRunLoopSourceOpaqeueValue.lock(&valueTypes.pointee.mutex)
                            if let mutbag = valueTypes.pointee.mutableBag?.takeUnretainedValue() {
                                bag = CFBagCreateCopy(nil, mutbag)
                            } else {
                                
                                bag = withUnsafePointer(to: kCFTypeBagCallBacks) {
                                    CFBagCreateMutable(nil, 0, $0)
                                }
                            }
                            CFRunLoopSourceOpaqeueValue.unlock(&valueTypes.pointee.mutex)
                        }
                        let runloopArrays = withUnsafeTemporaryAllocation(of: UnsafeRawPointer?.self, capacity: CFBagGetCount(bag)) { buffer in
                            CFBagGetValues(bag, buffer.baseAddress!)
                            return buffer.withMemoryRebound(to: CFRunLoop.self) {
                                Array($0)
                            }
                        }
                        
                    }
                
                }
                if let rl = runLoop?.getCFRunLoop() {
                    CFRunLoopWakeUp(rl)
                }
                
            }
        }
        timers.forEach{ $0.activate() }
    }
    
    deinit {
        timers.forEach { $0.cancel() }
    }
    
    func dispatch() {
        store.runBatch(executor: serialExecutor.unsafelyUnwrapped, taskRef: taskRef)
    }
    
    func schedule(_ runloop:CFRunLoop, _ mode:CFRunLoopMode) {
        registry.object(forKey: runloop)?.add(mode.rawValue)
    }
    
    func cancel(_ runloop:CFRunLoop, _ mode:CFRunLoopMode) {
        registry.object(forKey: runloop)?.remove(mode.rawValue)
    }
    
    
    class func create() -> CFRunLoopSource {
        let ob = Self.init()
        NSMapTable<CFRunLoop,NSMutableSet>.weakToStrongObjects()
//        malloc_zone_t
        var context = CFRunLoopSourceContext()
        context.info = Unmanaged.passUnretained(ob).toOpaque()
        context.copyDescription = kCFTypeSetCallBacks.copyDescription
        context.equal = kCFTypeSetCallBacks.equal
        context.hash = kCFTypeSetCallBacks.hash
        context.retain = unsafeBitCast(CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier("com.apple.CoreFoundation" as CFString), "CFRetain" as CFString), to: (@convention(c) (UnsafeRawPointer?) -> UnsafeRawPointer?).self)
        context.release = unsafeBitCast(CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier("com.apple.CoreFoundation" as CFString), "CFRelease" as CFString), to: (@convention(c) (UnsafeRawPointer?) -> Void).self)
        context.perform = {
            Unmanaged<Backing>.fromOpaque($0.unsafelyUnwrapped).takeUnretainedValue().dispatch()
        }
        context.schedule = {
            Unmanaged<Backing>.fromOpaque($0.unsafelyUnwrapped).takeUnretainedValue()
                .schedule($1.unsafelyUnwrapped, $2.unsafelyUnwrapped)
        }
        context.cancel = {
            Unmanaged<Backing>.fromOpaque($0.unsafelyUnwrapped).takeUnretainedValue()
                .cancel($1.unsafelyUnwrapped, $2.unsafelyUnwrapped)
        }
        let source = CFRunLoopSourceCreate(nil, 0, &context)!
        ob.source = source
        let bag:CFBag
        do {
//            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
//                        
//            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            let k2 = Unmanaged.passUnretained(source).toOpaque().assumingMemoryBound(to: CFRunLoopSourceOpaqeueValue.self)
            CFRunLoopSourceOpaqeueValue.lock(&k2.pointee.mutex)
            if let mutBag = k2.pointee.mutableBag?.takeUnretainedValue() {
                bag = CFBagCreateCopy(nil, mutBag)
            } else {
                bag = withUnsafePointer(to: kCFTypeBagCallBacks) {
                    CFBagCreate(nil, nil, 0, $0)
                }
            }
            CFRunLoopSourceOpaqeueValue.unlock(&k2.pointee.mutex)

        }
        //AutoreleasingUnsafeMutablePointer
        let t = withUnsafeTemporaryAllocation(of: UnsafeRawPointer?.self, capacity: CFBagGetCount(bag)) {
            CFBagGetValues(bag, $0.baseAddress!)
            let count = CFBagGetCount(bag)
            let buffer = UnsafeMutableBufferPointer(rebasing: $0[..<count])
            
            return ContiguousArray<CFRunLoop>.init(unsafeUninitializedCapacity: buffer.count) {
                for i in buffer.indices {
                    $0.initializeElement(at: i, to: Unmanaged.fromOpaque(buffer[i]!).takeUnretainedValue())
                }
                $1 = buffer.count
            }
            
//            return withUnsafePointer(to: kCFTypeArrayCallBacks) {             CFArrayCreate(nil, buffer.baseAddress!, CFBagGetCount(bag), $0)
//
//            } as! [CFRunLoop]
//            return buffer.withMemoryRebound(to: CFRunLoop.self) {
//                Array($0)
//            }
        }
        print(t)
        return source
    }
}

struct CFRunLoopSourceOpaqeueValue:BitwiseCopyable {
    var runtime:(UnsafeMutableRawPointer?, UnsafeMutableRawPointer?)
    
    var mutex:RecursiveMutex
    var order:CFIndex
    var signalTime:UInt64
    var mutableBag:Unmanaged<CFMutableBag>!
    
    var context0:CFRunLoopSourceContext
    
    #if false && canImport(Darwin)
    struct RecursiveMutex:BitwiseCopyable {
        var lock:os_unfair_lock
        var count:UInt32
    }
    @_silgen_name("os_unfair_recursive_lock_lock_with_options")
    static func lock_options(_ lock: inout RecursiveMutex, options:UInt32)
    
    static func lock(_ lock: inout RecursiveMutex) {
        lock_options(&lock, options: 0)
    }
    @_silgen_name("os_unfair_recursive_lock_unlock")
    static func unlock(_ lock: inout RecursiveMutex)
    
    #elseif canImport(WinSDK)
    typealias RecursiveMutex = SWIFT_CRITICAL_SECTION
    static func lock(_ lock: inout RecursiveMutex) {
        EnterCriticalSection(&lock)
    }
    static func unlock(_ lock: inout RecursiveMutex) {
        LeaveCriticalSection(&lock)
    }
    #elseif canImport(pthread)
    
    typealias RecursiveMutex = pthread_mutex_t
    static func lock(_ lock: inout RecursiveMutex) {
        pthread_mutex_lock(&lock)
    }
    static func unlock(_ lock: inout RecursiveMutex) {
        pthread_mutex_unlock(&lock)
    }
    #else
    #error("RecursiveMutex can not be inferred")
    
    #endif

    
}

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
class Backing2: Backing {
    
    
    var taskExecutor:UnownedTaskExecutor!
    
    override var taskRef: Builtin.Executor {
        taskExecutor!._executor
    }
    

}


@usableFromInline
struct ForwardItemT: RawRepresentable, AtomicValue, AtomicOptionalWrappable {
    
    @usableFromInline
    @inline(__always)
    var rawValue: UnsafeMutableRawPointer
    
    @usableFromInline
    @_transparent
    @inline(__always)
    func load<T:~Copyable>(_ type:T.Type = T.self) -> UnsafeMutablePointer<T> {
        rawValue.assumingMemoryBound(to: type)
    }
    
    @_transparent
    @inline(__always)
    @usableFromInline
    init(rawValue: UnsafeMutableRawPointer) {
        self.rawValue = rawValue
    }

}
