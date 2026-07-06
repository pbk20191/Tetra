//
//  StackBoundRunLoopExecutor.swift
//  TetraRunLoopConcurrency
//
//  The FACADE half of the kqueue/CFFileDescriptor run-loop executor. A
//  `SerialExecutor` that mounts a stack-bound `KQScheduler` engine on the
//  current CFRunLoop thread, buffers jobs while dormant, and delegates the run
//  frame (`run`/`runUntil`/`stop`) to the engine.
//
//  Ported from swift-platform-executors' `StackBoundRunLoopExecutor2` facade
//  half, adapted to Tetra:
//
//    * iOS 13 / macOS 10.15 (the reference's macOS 15 / iOS 18 gate is dropped;
//      the `ExecutorJob` / timer surfaces keep their own finer availability).
//    * `AtomicStore` (not Synchronization `Atomic`) for `producerGate` and the
//      published-scheduler pointer; `createCheckedStateLock` for the mount FSM.
//    * The engine (`KQScheduler`) already owns the run frame + mount lifetime, so
//      this facade only publishes a freshly mounted engine and forwards to it.
//    * No `TaskExecutor` conformance here — Task 5 supplies the gated task ref.
//      `taskRef` stays nil (the iOS 13 `SerialExecutor` path).
//
//  Concern wiring (Task 3 hand-offs resolved here + in `KQScheduler.swift`):
//    1. Predicate unwinding: `currentPredicate` is bound around the `runUntil`
//       frame; the engine's `handleReadable` consults it after each drain and
//       stops the run loop when it returns true.
//    2. `current()` / mount: `currentOnLocal` is bound around the run frame so a
//       nested `current()` on the same thread recovers this facade.
//    3. Nested re-entry: the engine's own `enterRunLoop` installs the
//       `beforeWaiting` observer + `deferredReadable` guard.
//

#if canImport(Darwin)
import Darwin
import Dispatch
import CoreFoundation
import CriticalSection
import Builtin
// SchedulingExecutor / RunLoopExecutor / MainExecutor are SPI on `_Concurrency`.
// The SPI groups match the ones the test target imports.
@_spi(ExperimentalScheduling) @_spi(ConcurrencyExecutors) @_spi(ExperimentalCustomExecutors) import _Concurrency

@available(macOS 10.15, iOS 13, *)
public final class StackBoundRunLoopExecutor: SerialExecutor, @unchecked Sendable {

    /// Dormant (buffering) → live (engine mounted & published) → dead (unwound).
    private enum MountState {
        case dormant(ContiguousArray<UnownedJob>)
        case live
        case dead
    }
    private let mount: some UnfairStateLock<MountState> =
        createCheckedStateLock(checkedState: MountState.dormant([]))

    /// The published live engine, dereferenced by producers while `producerGate`
    /// is held. `nil` unless mounted. Stored as a raw pointer inside an
    /// `AtomicStore<UInt>` (Tetra has no `AtomicStore<Unmanaged<…>?>`).
    private let liveSchedulerBits = AtomicStore<Unmanaged<KQScheduler>?>(.none)

    /// Producers in flight. Held across every dereference of the live engine and
    /// doubles as the engine's shutdown quiescence count (`finishAndDie`).
    let producerGate = AtomicStore<UInt>(0)

    nonisolated(unsafe) let cfRunLoop: CFRunLoop
    nonisolated(unsafe) let thread: pthread_t

    // MARK: Task locals (concern #1 predicate, #2 mount recovery)

    @TaskLocal static var currentOnLocal: Unmanaged<StackBoundRunLoopExecutor>?
    @TaskLocal static var currentPredicate: UnsafeBlockBox?

    struct UnsafeBlockBox: @unchecked Sendable {
        nonisolated(unsafe) let block: () -> Bool
    }

    #if DEBUG
    /// Test-only hook, invoked with a freshly mounted engine (before the run frame
    /// spins) so a lifetime test can capture it in a `weak` box and later assert it
    /// deallocated once `run()` returned. Not compiled into release.
    nonisolated(unsafe) static var _debugOnMountEngine: ((KQScheduler) -> Void)?
    #endif

    // MARK: Init / mount lookup

    private init() {
        self.thread = pthread_self()
        self.cfRunLoop = CFRunLoopGetCurrent()
    }

    /// Recover the facade mounted on the current thread, if any.
    static func peek() -> StackBoundRunLoopExecutor? {
        if let existing = currentOnLocal?.takeUnretainedValue(),
           pthread_equal(existing.thread, pthread_self()) != 0 {
            return existing
        }
        // Fallback: we may be running inside a job whose task is isolated to this
        // executor without `currentOnLocal` being bound. Recover the concrete executor
        // from the current task's serial-executor ref.
        return withUnsafeCurrentTask {
            if $0 != nil, let serial = SerialExecutorRef.peek() as? StackBoundRunLoopExecutor {
                return serial
            }
            return nil
        }
    }

    /// Mount an engine on the current CFRunLoop thread (or recover the one already
    /// mounted here).
    public static func current() -> StackBoundRunLoopExecutor {
        if let existing = peek() { return existing }
        return StackBoundRunLoopExecutor()
    }
    
    public var isMainExecutor:Bool {
        false
    }

    // MARK: Published-engine helpers

    private func publishedScheduler() -> Unmanaged<KQScheduler>? {
        return liveSchedulerBits.load(ordering: .acquiring)
    }

    private func publish(_ scheduler: KQScheduler) {
//        let raw = Unmanaged.passUnretained(scheduler).toOpaque()
        liveSchedulerBits.store(.passUnretained(scheduler), ordering: .releasing)
    }

    /// Retire the published engine: no producer may dereference it after this
    /// returns, and the mount FSM is dead. Spins until every in-flight producer
    /// releases the gate.
    private func retireScheduler() {
        liveSchedulerBits.store(nil, ordering: .releasing)
        mount.withLock { $0 = .dead }
        while producerGate.load(ordering: .acquiring) != 0 { _ = sched_yield() }
    }

    // MARK: producerGate counter (AtomicStore has no wrapping add/sub)

    private func gateEnter() {
        while true {
            let old = producerGate.load(ordering: .relaxed)
            let (ok, _) = producerGate.compareExchange(
                expected: old, desired: old &+ 1, ordering: .acquiring)
            if ok { return }
        }
    }
    private func gateLeave() {
        while true {
            let old = producerGate.load(ordering: .relaxed)
            let (ok, _) = producerGate.compareExchange(
                expected: old, desired: old &- 1, ordering: .releasing)
            if ok { return }
        }
    }

    // MARK: SerialExecutor

    /// Primary `SerialExecutor` conformance method, available at iOS 13 / macOS 10.15.
    public func enqueue(_ job: UnownedJob) {
        gateEnter()
        defer { gateLeave() }

        if let ref = publishedScheduler() {
            ref._withUnsafeGuaranteedRef { $0.enqueueReady(job) }
            return
        }
        let scheduler = mount.withLock { state -> Unmanaged<KQScheduler>? in
            switch state {
            case .dormant(var buffer):
                state = .dormant([])
                buffer.append(job)
                state = .dormant(buffer)
                return nil
            case .live:
                return publishedScheduler()
            case .dead:
                preconditionFailure("StackBoundRunLoopExecutor.enqueue(_:) called after its run loop finished.")
            }
        }
        scheduler?._withUnsafeGuaranteedRef { $0.enqueueReady(job) }
    }

    /// `ExecutorJob` overload available on newer platforms; forwards to the primary path.
    @available(macOS 14, iOS 17, watchOS 10, tvOS 17, visionOS 1, *)
    public func enqueue(_ job: consuming ExecutorJob) {
        enqueue(UnownedJob(job))
    }

    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *) {
            return .init(complexEquality: self)
        } else {
            return .init(ordinary: self)
        }
    }

    public static func == (lhs: StackBoundRunLoopExecutor, rhs: StackBoundRunLoopExecutor) -> Bool {
        pthread_equal(lhs.thread, rhs.thread) != 0
    }

    public func checkIsolated() {
        precondition(isIsolatingCurrentContext() == true,
                     "Caller is not isolated to this executor's thread.")
    }
    public func isIsolatingCurrentContext() -> Bool? {
        pthread_equal(thread, pthread_self()) != 0
    }

    // MARK: Timer enqueue (delegates to the engine's clock-domain heaps)

    /// `ClockIndex` is module-internal, so this timer surface is `internal` even
    /// though the type is public (mirrors the reference's `SchedulingExecutor`
    /// surface, reduced to the concrete Tetra domain index).
//    @available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    func enqueue(_ job: consuming ExecutorJob, after: Duration,
                 tolerance: Duration? = nil, clock: SlicedJobQueue.ClockIndex) {
        let unowned = UnownedJob(job)
        gateEnter()
        defer { gateLeave() }

        if let ref = publishedScheduler() {
            ref._withUnsafeGuaranteedRef {
                $0.enqueueTimer(unowned, after: after, tolerance: tolerance, index: clock)
            }
            return
        }
        // Dormant / not-yet-published: buffer the job on the ready lanes (fires
        // ASAP once mounted). The engine owns the delay heaps and is only reachable
        // once live; timers scheduled before mount degrade to immediate.
        let scheduler = mount.withLock { state -> Unmanaged<KQScheduler>? in
            switch state {
            case .dormant(var buffer):
                state = .dormant([])
                buffer.append(unowned)
                state = .dormant(buffer)
                return nil
            case .live:
                return publishedScheduler()
            case .dead:
                preconditionFailure("StackBoundRunLoopExecutor.enqueue(_:after:...) called after its run loop finished.")
            }
        }
        scheduler?._withUnsafeGuaranteedRef {
            $0.enqueueTimer(unowned, after: after, tolerance: tolerance, index: clock)
        }
    }

    // MARK: Run frame (owned by the facade; drives the engine's pump)

    public func run() throws {
        try enterRunLoop(stopScope: true) { engine in
            Self.$currentPredicate.withValue(nil) {
                while !engine._withUnsafeGuaranteedRef(\.isStopRequested) {
                    let result = CFRunLoopRunInMode(.defaultMode, 1.0e10, false)
                    if result == .finished { break }
                }
            }
        }
    }

    public func runUntil(_ condition: @escaping () -> Bool) throws {
        try enterRunLoop(stopScope: false) { engine in
            withoutActuallyEscaping(condition) { escaping in
                Self.$currentPredicate.withValue(.init(block: escaping)) {
                    while !engine._withUnsafeGuaranteedRef(\.isStopRequested) {
                        let result = CFRunLoopRunInMode(.defaultMode, 1.0e10, false)
                        if result == .finished { break }
                    }
                }
            }
        }
    }

    public func stop() {
        let onOwningThread = pthread_equal(thread, pthread_self()) != 0
        gateEnter()
        publishedScheduler()?._withUnsafeGuaranteedRef { $0.requestStop() }
        gateLeave()
        if onOwningThread {
            CFRunLoopStop(cfRunLoop)
        }
    }

    // MARK: Mount + install run-loop source + spin

    /// Mounts a fresh engine on the current thread (or reuses the one already mounted
    /// for nested re-entry), installs the CFFileDescriptor run-loop source + a
    /// `beforeWaiting` observer that re-enables the one-shot readable callback deferred
    /// while inside a task context, binds the mount task-local, spins the caller's loop,
    /// then tears everything down, drains to empty, and retires the engine.
    private func enterRunLoop(stopScope: Bool,
                              _ spin: (Unmanaged<KQScheduler>) -> Void) throws {
        guard pthread_equal(thread, pthread_self()) != 0 else {
            preconditionFailure("StackBoundRunLoopExecutor.run()/runUntil(_:) called from a non-owning thread.")
        }
        guard withUnsafeCurrentTask(body: { $0 == nil }) else {
            throw CancellationError()
        }

        // Nested re-entry: reuse the already-mounted engine. The fd/observer are
        // installed once by the outermost frame. The engine stays alive for the nested
        // spin via the outer frame's keep-alive (the CFFileDescriptor context retain +
        // the outer frame's strong local), so we hand the spin an unretained
        // `Unmanaged` — no extra retain across the loop.
        if Self.peek() === self, let ref = publishedScheduler() {
            if !stopScope {
                // Force one drain pass so the predicate is evaluated on entry.
                ref._withUnsafeGuaranteedRef { KQueueSelector.wakeup(fileDescriptor: $0.kqueueFD) }
            }
            defer {
                ref._withUnsafeGuaranteedRef { $0.clearStopRequested() }
            }
            spin(ref)
            return
        }

        // Outermost: mount a fresh engine bound to this thread's run loop, drain any
        // buffered jobs, publish it, install the run-loop source, spin, then retire it
        // (stack-bound lifetime).
        //
        // On the iOS-18 path this facade is a `TaskExecutor`, so hand the engine a
        // task-executor ref; `runBatch` then runs jobs via
        // `runSynchronously(isolatedTo:taskExecutor:)`. Below iOS 18 the ref stays nil
        // (the `SerialExecutor`-only `runSynchronously(on:)` path).
        let taskRef: Builtin.Executor?
        if #available(iOS 18, macOS 15, watchOS 11, tvOS 18, visionOS 2, *) {
            taskRef = self.asUnownedTaskExecutor()._executor
        } else {
            taskRef = nil
        }
        // The frame keeps a plain strong local; the CFFileDescriptor context holds a
        // second retain. Both drop on exit — so the engine deallocates when this frame
        // returns (stack-bound lifetime; the lifetime test enforces this).
        unowned(unsafe) let engine: KQScheduler
        let fd: CFFileDescriptor
        do {
            let _engine = KQScheduler(facade: self,
                                      serial: asUnownedSerialExecutor(),
                                      taskRef: taskRef,
                                      cfRunLoop: cfRunLoop)
            let buffered: ContiguousArray<UnownedJob> = mount.withLock { state in
                switch state {
                case .dormant(let buffer):
                    // Publish inside the lock so a producer that observes `.live` here
                    // never reads a nil published pointer (and drops the job).
                    publish(_engine)
                    state = .live
                    return buffer
                case .live, .dead:
                    return []
                }
            }
            fd = _engine.makeFileDescriptor()
            engine = _engine
            _engine.enqueueBatch(buffered)

            #if DEBUG
            Self._debugOnMountEngine?(_engine)
            #endif
        }

        guard let source = CFFileDescriptorCreateRunLoopSource(nil, fd, 0) else {
            // Undo the publish so no producer dereferences the about-to-be-freed
            // engine, then invalidate the descriptor (closes the kqueue).
            retireScheduler()
            CFFileDescriptorInvalidate(fd)
            throw CancellationError()
        }

        let observer = CFRunLoopObserverCreateWithHandler(
            nil, ([.beforeWaiting] as CFRunLoopActivity).rawValue, true, 0
        ) { [unowned(unsafe) engine, unowned(unsafe) fd] _, activity in
            // Re-arm a readable that was deferred because we were inside a task-context.
            // Safe: the observer is removed and invalidated in the same defer that
            // precedes the engine's release, and the fd is valid for the frame.
            if activity == .beforeWaiting, engine.deferredReadable, withUnsafeCurrentTask(body: { $0 == nil }) {
                engine.deferredReadable = false
                CFFileDescriptorEnableCallBacks(fd, kCFFileDescriptorReadCallBack)
            }
        }!

        Self.$currentOnLocal.withValue(Unmanaged.passUnretained(self)) {
            CFRunLoopAddSource(cfRunLoop, source, .commonModes)
            CFRunLoopAddObserver(cfRunLoop, observer, .commonModes)
            CFFileDescriptorEnableCallBacks(fd, kCFFileDescriptorReadCallBack)

            // Initial kick: drain anything buffered before the source was installed.
            KQueueSelector.wakeup(fileDescriptor: engine.kqueueFD)

            defer {
                CFFileDescriptorDisableCallBacks(fd, kCFFileDescriptorReadCallBack)
                CFRunLoopRemoveSource(cfRunLoop, source, .commonModes)
                CFRunLoopRemoveObserver(cfRunLoop, observer, .commonModes)
                CFRunLoopSourceInvalidate(source)
                CFRunLoopObserverInvalidate(observer)
                engine.teardown()
                // Invalidate the descriptor last: closes the kqueue (closeOnInvalidate)
                // and drops the context's retain; the local strong `engine` releases as
                // this frame returns (stack-bound lifetime).
                CFFileDescriptorInvalidate(fd)
            }

            spin(.passUnretained(engine))
            engine.clearStopRequested()
            engine.beginClosing()
            engine.finishAndDie()
            retireScheduler()
        }
    }
}

// MARK: - Gated executor-protocol conformances (Task 5)
//
// All four protocols floor at iOS 16 / macOS 13, but this executor supplies a
// task executor to `runBatch` via `runSynchronously(isolatedTo:taskExecutor:)`,
// which is iOS 18 / macOS 15. So the conformances are gated at that higher floor.
// `SchedulingExecutor` / `RunLoopExecutor` / `MainExecutor` are SPI (see the
// `@_spi(...) import _Concurrency` at the top of this file).

@available(iOS 18, macOS 15, watchOS 11, tvOS 18, visionOS 2, *)
extension StackBoundRunLoopExecutor: TaskExecutor {
    // `asUnownedTaskExecutor()` is provided by the protocol's default extension;
    // no explicit member needed. The engine reads `asUnownedTaskExecutor()._executor`
    // when it mounts (see `enterRunLoop`).
}

// The SPI executor protocols `SchedulingExecutor` / `RunLoopExecutor` / `MainExecutor`
// are NOT nameable on the standard/release stdlib: even a `@_spi(...) import _Concurrency`
// cannot see them (they are `internal` on 6.2 as `SchedulableExecutor` etc., and the
// release .swiftinterface does not re-export the SPI decls — confirmed: release Swift 6.4
// reports `cannot find type 'SchedulingExecutor'`). Their visibility depends on the
// TOOLCHAIN FLAVOR (a development snapshot's stdlib exposes them; a release one does not),
// which no `#if compiler(>=x)` can distinguish. So gate on the `SchedulingExecutorSPI`
// package trait (Package.swift): OFF by default (release/standard toolchains → excluded →
// the module compiles as a SerialExecutor + TaskExecutor, clock scheduling falling back to
// the global executor), enabled with `swift build --traits SchedulingExecutorSPI` only on a
// toolchain whose stdlib actually exposes these SPI protocols.
#if SchedulingExecutorSPI
@available(iOS 18, macOS 15, watchOS 11, tvOS 18, visionOS 2, *)
@_spi(ExperimentalCustomExecutors)
extension StackBoundRunLoopExecutor: RunLoopExecutor {
    // `run()` / `runUntil(_:)` / `stop()` already exist on the facade. (The facade's
    // `runUntil` takes an `@escaping` closure, which satisfies the protocol's
    // non-escaping requirement.)
}

@available(iOS 18, macOS 15, watchOS 11, tvOS 18, visionOS 2, *)
@_spi(ExperimentalScheduling)
extension StackBoundRunLoopExecutor: SchedulingExecutor {

    /// Delay-scheduling entry point. Maps the standard clocks to the engine's
    /// `SlicedJobQueue.ClockIndex` domains and delegates to the internal
    /// `enqueue(_:after:tolerance:clock:)` timer path (which computes the deadline in
    /// the engine — this facade never recomputes timestamps).
    ///
    /// `ContinuousClock.Duration` and `SuspendingClock.Duration` are both
    /// `Swift.Duration`, so the delay/tolerance forward unchanged.
    ///
    /// For any clock this executor does not model, we prefer to trampoline through the
    /// global concurrent executor (so the job still fires on the *right* clock) and then
    /// hop back here to run. If that SPI cast is unavailable at runtime we fall back to
    /// treating the delay on the suspending (uptime) domain rather than crashing — an
    /// approximation, documented, for exotic custom clocks only.
    @_spi(ExperimentalScheduling)
    public func enqueue<C: Clock>(
        _ job: consuming ExecutorJob,
        after delay: C.Duration,
        tolerance: C.Duration? = nil,
        clock: C
    ) {
        if clock is ContinuousClock {
            let d = delay as! Swift.Duration
            let tol = tolerance as! Swift.Duration?
            self.enqueue(job, after: d, tolerance: tol, clock: .continuous)
            return
        }
        if clock is SuspendingClock {
            let d = delay as! Swift.Duration
            let tol = tolerance as! Swift.Duration?
            self.enqueue(job, after: d, tolerance: tol, clock: .suspending)
            return
        }
        // Unmodeled clock: trampoline through the global executor if it schedules,
        // otherwise approximate on the suspending domain (Tetra has no WallClock type).
        if let global = globalConcurrentExecutor as? (any SchedulingExecutor), !(global === self) {
            let trampoline = job.createTrampoline(to: self)
            global.enqueue(trampoline, after: delay, tolerance: tolerance, clock: clock)
        } else {
            // Fallback: run the delay on the suspending (uptime) domain. This is an
            // approximation for clocks other than Continuous/Suspending; it never
            // crashes on an unknown clock.
            let d = (delay as? Swift.Duration) ?? .zero
            let tol = tolerance as? Swift.Duration
            self.enqueue(job, after: d, tolerance: tol, clock: .suspending)
        }
    }
    
    nonisolated public var asSchedulingExecutor: (any SchedulingExecutor)? { self }


    /// Deadline-scheduling entry point. The `SchedulingExecutor` extension supplies a
    /// default that converts `at:` to `after:` via `clock.now`, so no override is
    /// required here; it routes through `enqueue(_:after:tolerance:clock:)` above.
}

@available(iOS 18, macOS 15, watchOS 11, tvOS 18, visionOS 2, *)
@_spi(ExperimentalCustomExecutors)
extension StackBoundRunLoopExecutor: MainExecutor {
    // MainExecutor == RunLoopExecutor + SerialExecutor; both are already satisfied.
    // `isMainExecutor` is provided by the SerialExecutor default (returns false).
}
#endif // SchedulingExecutorSPI trait — SchedulingExecutor/RunLoopExecutor/MainExecutor

#endif
