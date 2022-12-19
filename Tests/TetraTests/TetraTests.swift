//
//  TetraTests.swift
//  
//
//  Created by iquest1127 on 2022/12/19.
//

import XCTest
import os
@testable import Tetra
import Combine

final class TetraTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
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
    
    func testUnfairLockPrecondition() throws {
        if #available(iOS 16.0, tvOS 16.0, macCatalyst 16.0, macOS 13.0, watchOS 9.0, *) {
            let lock = OSAllocatedUnfairLock()
            lock.withLock {
                lock.precondition(.owner)
            }
            lock.precondition(.notOwner)
        } else {
            
            let lock = ManagedUnfairLock()
            lock.withLock {
                lock.precondition(.owner)
            }
            lock.precondition(.notOwner)
        }
    }

    func testAnyEncodable() throws {
        struct AnyErasedEncodable: Encodable {
            let value:Encodable
            func encode(to encoder: Encoder) throws {
                try value.encode(to: encoder)
            }
        }
        let targetURL = FileManager.default.temporaryDirectory

        XCTAssertEqual(try JSONEncoder().encode(AnyEncodable(targetURL)), try JSONEncoder().encode(targetURL))
        XCTAssertNotEqual(try JSONEncoder().encode(AnyErasedEncodable(value: targetURL)), try JSONEncoder().encode(targetURL))
    }
    
    func testCodablePrimitive() throws {
        let structure:CodablePrimitive = [["1":"C"], true, ["key":"value","#@!@":0.0]]
        XCTAssertEqual(try JSONEncoder().encode(structure), try JSONSerialization.data(withJSONObject: structure.propertyObject))
    }
    
    func testSchedulers() async throws {
        let publisher = SchedulerTimePublisher(scheduler: DispatchQueue.global(), interval: .milliseconds(50)).makeConnectable()
        let autoConnect = publisher.autoconnect()
        var bag = Set<AnyCancellable>()
       autoConnect
            .print("1")
            .sink { _ in
                
            }.store(in: &bag)
        autoConnect
             .print("2")
             .sink { _ in
                 
             }.store(in: &bag)
        
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
    }
    
}
