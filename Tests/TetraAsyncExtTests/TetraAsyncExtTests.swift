import XCTest
import Foundation
import Dispatch
import Combine
@testable import TetraAsyncExt

final class TetraAsyncExtTests: XCTestCase {
    
    func testExample() async throws {
        
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
    }
    
    func testCancelledDownload() async throws {
        let result = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await perfomDownload(on: .shared, from: URL(string: "https://www.shutterstock.com/image-photo/red-apple-isolated-on-white-260nw-1727544364.jpg")!)
        }.result
        XCTAssertThrowsError(try result.get())
    }
    
    func testCancellDuringDownload() async throws {
        let cancelTask2 = Task {
            try await perfomDownload(on: .shared, from: URL(string: "https://www.shutterstock.com/image-photo/red-apple-isolated-on-white-260nw-1727544364.jpg")!)
        }
        Task{
            try await Task.sleep(nanoseconds: 50_000_000)
            cancelTask2.cancel()
        }
        let result2 = await cancelTask2.result
        XCTAssertThrowsError(try result2.get())
    }
    
    func testNotificationSequence() async throws {
        let name = Notification.Name(UUID().uuidString)
        let object = NSObject()
        let sequence = NotificationCenter.default.sequence(named: name, object: object)
        let task = Task {
            var count = 0
            for await _ in sequence {
                count += 1
            }
            return count
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        NotificationCenter.default.post(name: name, object: nil)
        try await Task.sleep(nanoseconds: 1_000_000)
        NotificationCenter.default.post(name: name, object: object)
        try await Task.sleep(nanoseconds: 1_000_000)
        NotificationCenter.default.post(name: name, object: NSObject())
        try await Task.sleep(nanoseconds: 1_000_000)
        NotificationCenter.default.post(name: name, object: object, userInfo: ["":""])
        try await Task.sleep(nanoseconds: 1_000_000)
        task.cancel()
        NotificationCenter.default.post(name: name, object: object, userInfo: ["":""])
        let count = await task.value
        XCTAssertEqual(count, 2)
    }
    

    
//    @available(iOS 16.0, macOS 12.0, *)
//    func testExampleAsync() async throws {
//        let a = (0..<100).publisher.print().sequence
//        let task = Task {
//
//            var it = a.makeAsyncIterator()
//            while let _ = await it.next() {
//                if Task.isCancelled {
//                    return it
//                } else {
//                    try? await Task.sleep(nanoseconds: 100_000_000)
//                }
//            }
//            return it
//        }
//        try await Task.sleep(nanoseconds: 250_000_000)
//        task.cancel()
//        let it = await task.value
//
//        await Task {
//            await withTaskGroup(of: Void.self) { group in
//                (0..<10).forEach{ _ in
//                    group.addTask {
//                        var newI = it
//                        while let _ = await newI.next() {
//                            try? await Task.sleep(nanoseconds: 100_000_000)
//                        }
//                        print("group task done")
//                    }
//                }
//                try? await Task.sleep(nanoseconds: 10_000_000)
//                group.cancelAll()
//            }
//            print("task finished")
//        }.value
//
//    }
    

}
