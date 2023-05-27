//
//  JsonWrapperTests.swift
//  
//
//  Created by pbk on 2023/01/31.
//

import XCTest
@testable import Tetra

final class JsonWrapperTests: XCTestCase {

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

    func testMappingPerformance() throws {
        let json1 = try Data(contentsOf: Bundle.module.url(forResource: "JsonSample1", withExtension: "json").unsafelyUnwrapped)
        let json2 = try Data(contentsOf: Bundle.module.url(forResource: "JsonSample2", withExtension: ".json").unsafelyUnwrapped)
        let json3 = try Data(contentsOf: Bundle.module.url(forResource: "JsonSample3", withExtension: ".json").unsafelyUnwrapped)
        measure {

            do {
//                let _ = try JSONSerialization.jsonObject(with: json3)
                let _ = try JsonWrapper.init(from: json3)
//                let _ = try JSONDecoder().decode([[String:String]].self, from: json3)
            } catch {
                print(error)
                XCTFail(error.localizedDescription)
            }

        }
        
    }
    
    func testNumeric() throws {
        
        let sample = Data("""
{"a": 0.0, "b": 1, "K":true}
""".utf8)
        
        XCTAssertEqual(try JsonWrapper(from: sample), ["a": 0.0, "b": 1, "K":true])
    }
    
    func testDecoder() throws {
        let json3 = try Data(contentsOf: Bundle.module.url(forResource: "JsonSample3", withExtension: ".json").unsafelyUnwrapped)
        let model = try JSONDecoder().decode([[String:String]].self, from: json3)
        let jsonWrapper = try JsonWrapper.init(from: json3)
        let model2 = try JsonWrapperDecoder().decode([[String:String]].self, from: jsonWrapper)
        XCTAssertEqual(model, model2)
    }

}
