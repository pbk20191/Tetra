//
//  CodablePrimitiveTests.swift
//  
//
//  Created by pbk on 2023/01/27.
//

import XCTest
@testable import Tetra

final class CodablePrimitiveTests: XCTestCase {

    
    override func setUp() async throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() async throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


//    func testCodablePrimitive() throws {
//        let structure:CodablePrimitive = [["1":"C"], true, ["key":"value","#@!@":0.01, "ACC":10]]
//        let codableData = try JSONEncoder().encode(structure)
//        XCTAssertEqual(structure, try JSONDecoder().decode(CodablePrimitive.self, from: codableData))
//    }
    
    func testEncodeEqual() throws {
        let structure:CodablePrimitive = [["1":"C"], true, ["key":"value","#@!@":0.01, "ACC":10]]
        XCTAssertEqual(try JSONEncoder().encode(structure), try JSONSerialization.data(withJSONObject: structure.propertyObject))
        XCTAssertEqual(try PropertyListEncoder().encode(structure), try PropertyListSerialization.data(fromPropertyList: structure.propertyObject, format: .binary, options: 0))
    }
    
    func testJsonDecodeEqual() throws {
        
        let sample1 = Data("""
{
    "A": 0.0,
    "B": "C",
    "K": [true, false, 0, 0.12312, -100, {"ASdf": true}],
}

""".utf8)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: sample1) as! NSDictionary, try JSONDecoder().decode(CodablePrimitive.self, from: sample1).propertyObject as! NSDictionary)
        
    }
    

}
