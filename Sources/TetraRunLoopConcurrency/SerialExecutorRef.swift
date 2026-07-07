//
//  SerialExecutorRef.swift
//  TetraRunLoopConcurrency
//
//  Reconstructs the concrete `any SerialExecutor` backing the *currently running*
//  task, so `StackBoundRunLoopExecutor.peek()` can identify itself even when it is
//  not the `currentOnLocal` TaskLocal (e.g. while running a job whose task is
//  isolated to this executor). Reads the runtime's current-executor ref via
//  `swift_task_getCurrentExecutor` and bit-casts it to the `(Identity, Implementation)`
//  layout of `UnownedSerialExecutor`. Ported from swift-platform-executors.
//

struct SerialExecutorRef: BitwiseCopyable {
    var Identity: UnsafeRawPointer?
    var Implementation: UnsafeRawPointer?

    func isGeneric() -> Bool {
        return Identity == nil
    }

    func isDefaultActor() -> Bool {
        return !isGeneric() && Implementation == nil
    }

    nonisolated
    private static var WitnessTableMask: UInt {
        unsafe ~(UInt(MemoryLayout<UnsafeRawPointer>.alignment) - 1)
    }

    /// Rebuild the `any SerialExecutor` existential from the ref's identity + witness
    /// table pointers. Returns nil for the generic/default-actor executors (no concrete
    /// custom executor to recover).
    nonisolated
    func unsafeConvert() -> (any SerialExecutor)? {
        guard !isGeneric() else { return nil }
        guard !isDefaultActor() else { return nil }
        let transformed = Implementation.flatMap(UInt.init) ?? 0
        let alignedExecutor = (Identity, transformed & Self.WitnessTableMask)
        return unsafe unsafeBitCast(alignedExecutor, to: (any SerialExecutor)?.self)
    }

    /// The concrete executor the current task is running on, or nil if not in a task.
    nonisolated
    static func peek() -> (any Executor)? {
        return withUnsafeCurrentTask {
            if $0 == nil { return nil }
            let t = _task_getCurrentExecutor()
            return unsafeBitCast(t, to: SerialExecutorRef.self).unsafeConvert()
        }
    }

    @_silgen_name("swift_task_getCurrentExecutor")
    private nonisolated static func _task_getCurrentExecutor() -> UnownedSerialExecutor
}
