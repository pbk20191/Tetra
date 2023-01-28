//
//  CodablePrimitiveTests.swift
//  
//
//  Created by pbk on 2023/01/27.
//

import XCTest
@testable import Tetra

final class CodablePrimitiveTests: XCTestCase {


//    func testCodablePrimitive() throws {
//        let structure:CodablePrimitive = [["1":"C"], true, ["key":"value","#@!@":0.01, "ACC":10]]
//        let codableData = try JSONEncoder().encode(structure)
//        XCTAssertEqual(structure, try JSONDecoder().decode(CodablePrimitive.self, from: codableData))
//    }
    
    func testEncodeEqual() throws {
        let structure:CodablePrimitive = [["1":"C"], true, ["key":"value","#@!@":0.01, "ACC":10]]
        
        XCTAssertEqual(
            try JSONEncoder().encode(structure),
            try JSONSerialization.data(withJSONObject: structure.propertyObject)
        )
        
        XCTAssertEqual(
            try PropertyListEncoder().encode(structure),
            try PropertyListSerialization.data(fromPropertyList: structure.propertyObject, format: .binary, options: 0)
        )
    }
    
    func testJsonDecodeEqual() throws {
        
        let sample1 = Data("""
{
    "A": 0.0,
    "B": "C",
    "K": [true, false, 0, 0.12312, -100, {"ASdf": true}],
}

""".utf8)
        
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: sample1) as! NSDictionary,
            try JSONDecoder().decode(CodablePrimitive.self, from: sample1).propertyObject as! NSDictionary
        )
        
        

    }
    
    
    func testJSonNullDecode() throws {
        let sample = Data("""
{
    "A": 0.0,
    "B": "C",
    "K": [true, false, 0, 0.12312, -100, {"ASdf": true}],
    "T": null
}

""".utf8)
        try XCTExpectFailure("CodablePrimitive ignore nulls") {
            XCTAssertEqual(
                try JSONSerialization.jsonObject(with: sample) as! NSDictionary,
                try JSONDecoder().decode(CodablePrimitive.self, from: sample).propertyObject as! NSDictionary
            )
        }
    }

    
    func testPlistDateDecode() throws {
        let sample = Data(
        """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>A</key>
    <true/>
    <key>AO</key>
    <real>-10.01</real>
    <key>C</key>
    <integer>1</integer>
    <key>K</key>
    <false/>
    <key>Q</key>
    <date>2023-01-28T04:52:37Z</date>
    <key>V</key>
    <integer>0</integer>
</dict>
</plist>

""".utf8)
        try XCTExpectFailure("CodablePrimitive does not support Date") {

            let _ = try PropertyListDecoder().decode(CodablePrimitive.self, from: sample)
        }
        
        
    }
    
    func testPlistDecode() throws {
        let sample = Data(
        """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>A</key>
    <true/>
    <key>AO</key>
    <real>-10.01</real>
    <key>C</key>
    <integer>1</integer>
    <key>K</key>
    <false/>
    <key>V</key>
    <integer>0</integer>
</dict>
</plist>

""".utf8)
        XCTAssertEqual(
            try PropertyListSerialization.propertyList(from: sample, format: nil) as! NSDictionary,
            try PropertyListDecoder().decode(CodablePrimitive.self, from: sample).propertyObject as! NSDictionary
        )
    }
    
}
