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

final class TetraFoundationExtTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDeinit1() async throws {
        try await testExample()
        try await Task.sleep(nanoseconds: 1000000000)
    }
    
    func testExample() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
//        let loopPub = Timer.TimerPublisher(interval: 0.2, runLoop: .main, mode: .default)
//        let kt = loopPub.print().sink { _ in
//
//        }
//        var timerBag = AnyCancellable(loopPub.connect())
//        try await Task.sleep(nanoseconds: 3000000000)
//        print("timer cancel1")
//        timerBag.cancel()
//        timerBag = AnyCancellable(loopPub.connect())
//        try await Task.sleep(nanoseconds: 3000000000)
//        print("timer cancel2")
//        timerBag = AnyCancellable{}
//
//        try await Task.sleep(nanoseconds: 1000000000)
//        kt.cancel()
//        try await Task.sleep(nanoseconds: 1000000000)
//        DispatchTimeInterval.milliseconds(200)
        var someBag:Set<AnyCancellable> = []
        let dispatchPublisher =
//        DispatchTimePublisher(interval: 0.05, queue: .init(label: "serial", attributes: [.concurrent]))
        DispatchTimerClassicPublisher(interval: 0.05, queue: .global())
 //       Timer.TimerPublisher(interval: 0.05, runLoop: .main, mode: .default)
//        SchedulerTimerPublisher(DispatchQueue.global(), interval:  .milliseconds(50))
        AnyCancellable(dispatchPublisher.connect()).store(in: &someBag)
        try await Task.sleep(nanoseconds: 100000)
        let connector = dispatchPublisher.autoconnect()
        let queue = DispatchQueue.global(qos:.background)
        connector.print("1").sink { time in
            print("1 S", time)
        }.store(in: &someBag)
        try await Task.sleep(nanoseconds: 10000)
        connector.print("2").sink { time in
            print("2 S", time)
        }.store(in: &someBag)
        try await Task.sleep(nanoseconds: 10000)
        connector.print("3").sink { time in
            print("3 S", time)
        }.store(in: &someBag)
        try await Task.sleep(nanoseconds: 10000)
        connector.print("4").sink { time in
            print("4 S", time)
        }.store(in: &someBag)
//        AnyCancellable(dispatchPublisher.connect()).store(in: &someBag)
        try await Task.sleep(nanoseconds: 1000000000)
        
        try await Task.sleep(nanoseconds: 1000)
    }

    func testDispatchSource() async throws {
        let source = DispatchSource.makeTimerSource()
        source.schedule(deadline: .now(), repeating: .milliseconds(200))
        source.setEventHandler{ print(DispatchTime.now()) }
        source.setRegistrationHandler{ print("register")}
        source.setCancelHandler{ print("cancel") }
        source.resume()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        source.cancel()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        source.activate()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        source.cancel()
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    func testRunLooperTimer() async throws {
        var token:AnyCancellable? = nil
        let timer =
//        Timer.TimerPublisher(interval: 0.05, runLoop: .main, mode: .default)
        SchedulerTimePublisher(DispatchQueue.global(), interval: .milliseconds(50))
        var someBag:Set<AnyCancellable> = []
        timer.print().sink { _ in
            
        }.store(in: &someBag)
        token = AnyCancellable(timer.connect())
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print(#line)
        token = nil
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print(#line)
        token = AnyCancellable(timer.connect())
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print(#line)
        token = nil
        try await Task.sleep(nanoseconds: 1_000_000_000)
        print(#line)
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
