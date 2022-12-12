//
//  TetraFoundationExtTests.swift
//  
//
//  Created by pbk on 2022/12/09.
//

import XCTest
@testable import TetraFoundationExt
import Combine
import Dispatch
import os

final class TetraFoundationExtTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testExample() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.

    }
    
    func testUnfairLockPrecondition() throws {
        if #available(iOS 16.0, tvOS 16.0, macCatalyst 16.0, macOS 13.0, watchOS 9.0, *) {
            let lock = OSAllocatedUnfairLock()
            lock.withLock {
                lock.precondition(.owner)
            }
            lock.precondition(.notOwner)
        } else {
            let lock = UnfairLock()
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

//    func testDispatchTimer() async throws {
//        var someBag:Set<AnyCancellable> = []
//        let dispatchPublisher =
//        DispatchTimePublisher(interval: 0.05)
// //       Timer.TimerPublisher(interval: 0.05, runLoop: .main, mode: .default)
////        SchedulerTimerPublisher(DispatchQueue.global(), interval:  .milliseconds(50))
//        AnyCancellable(dispatchPublisher.connect()).store(in: &someBag)
//        try await Task.sleep(nanoseconds: 100000)
//        let connector = dispatchPublisher.autoconnect()
//        connector.print("1").sink { time in
//            print("1 S", time)
//        }.store(in: &someBag)
//        try await Task.sleep(nanoseconds: 10000)
//        connector.print("2").sink { time in
//            print("2 S", time)
//        }.store(in: &someBag)
//        try await Task.sleep(nanoseconds: 10000)
//        connector.print("3").sink { time in
//            print("3 S", time)
//        }.store(in: &someBag)
//        try await Task.sleep(nanoseconds: 10000)
//        connector.print("4").sink { time in
//            print("4 S", time)
//        }.store(in: &someBag)
////        AnyCancellable(dispatchPublisher.connect()).store(in: &someBag)
//        try await Task.sleep(nanoseconds: 1000000000)
//        
//        try await Task.sleep(nanoseconds: 1000)
//    }
//    

    
}
