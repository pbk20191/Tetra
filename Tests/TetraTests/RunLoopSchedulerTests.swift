//
//  RunLoopSchedulerTests.swift
//  
//
//  Created by pbk on 2023/01/27.
//

import XCTest
@testable import Tetra

final class RunLoopSchedulerTests: XCTestCase {

    func testBlockingInitializerPerformance() {
        measure {
            let _ = RunLoopScheduler(sync: ())
        }
    }

    func testRunLoopBasic() async {
        let scheduler = await RunLoopScheduler(async: (), config: .init(qos: .background))
        await withUnsafeContinuation{ continuation in
            scheduler.schedule {
                XCTAssertEqual(CFRunLoopGetCurrent(), scheduler.cfRunLoop)
                continuation.resume()
            }
        }
        await withUnsafeContinuation{ continuation in
            let date = Date().addingTimeInterval(0.5)
            scheduler.schedule(after: .init(date)) {
                XCTAssertEqual(
                    date.timeIntervalSinceReferenceDate,
                    Date().timeIntervalSinceReferenceDate,
                    accuracy: 0.05
                )
                XCTAssertEqual(CFRunLoopGetCurrent(), scheduler.cfRunLoop)
                
                continuation.resume()
            }
        }
    }
    
    func testRunLoopNotificationQueue() async {
        let scheduler = await RunLoopScheduler(async: (), config: .init(qos: .background))
        let name = Notification.Name(UUID().uuidString)
        let object = NSObject()
        let expect1 = expectation(forNotification: name, object: object, notificationCenter: .default) { notification in
            XCTAssertTrue(notification.userInfo?["A"] as? String == "B")
            return true
        }
        
        await withUnsafeContinuation{ continuation in
            scheduler.schedule {

                continuation.resume()
                NotificationQueue.default
                    .enqueue(.init(name: name, object: object, userInfo: ["A":"B"]), postingStyle: .whenIdle, coalesceMask: [.onName, .onSender], forModes: nil)
                NotificationQueue.default
                    .enqueue(.init(name: name, object: object, userInfo: ["A":"1"]), postingStyle: .whenIdle, coalesceMask: [.onName, .onSender], forModes: nil)
                NotificationQueue.default
                    .enqueue(.init(name: name, object: object, userInfo: ["A":"2"]), postingStyle: .whenIdle, coalesceMask: [.onName, .onSender], forModes: nil)
                NotificationQueue.default
                    .enqueue(.init(name: name, object: object, userInfo: ["A":"3"]), postingStyle: .whenIdle, coalesceMask: [.onName, .onSender], forModes: nil)

            }
        }
        await withUnsafeContinuation{
            wait(for: [expect1], timeout: 1)
            $0.resume()
        }
        let expect2 = expectation(forNotification: name, object: object, notificationCenter: .default) {
            XCTAssertTrue($0.userInfo?["A"] as? String == "C")
            return true
        }
        await withUnsafeContinuation{ continuation in
            scheduler.schedule {
                NotificationQueue.default
                    .enqueue(.init(name: name, object: object, userInfo: ["A":"C"]), postingStyle: .whenIdle, coalesceMask: [.onName, .onSender], forModes: nil)
                continuation.resume()
            }
        }
        await withUnsafeContinuation{
            wait(for: [expect2], timeout: 1)
            $0.resume()
        }
    }

}
