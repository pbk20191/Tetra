import Testing
import Darwin
@testable import TetraRunLoopConcurrency

@Suite struct KQueueSelectorTests {
    @Test func wakeupMakesKqueueReadable() {
        let fd = KQueueSelector.makeKQueue(); defer { close(fd) }
        KQueueSelector.wakeup(fileDescriptor: fd)
        let fired = KQueueSelector.drainEvents(fileDescriptor: fd)   // consumes the EVFILT_USER
        #expect(!fired.continuous && !fired.suspending && !fired.wall) // user wake reports no timer domain
    }
    @Test func suspendingTimerFires() {
        let fd = KQueueSelector.makeKQueue(); defer { close(fd) }
        let now = KQueueSelector.now(index: .suspending)
        KQueueSelector.armTimer(fileDescriptor: fd, index: .suspending, target: now, leeway: 0, now: now) // due immediately
        var pollFd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        #expect(poll(&pollFd, 1, 500) == 1)                          // becomes readable within 500ms
        #expect(KQueueSelector.drainEvents(fileDescriptor: fd).suspending)
    }
}
