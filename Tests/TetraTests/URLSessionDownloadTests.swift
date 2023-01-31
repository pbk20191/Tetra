//
//  URLSessionDownloadTests.swift
//  
//
//  Created by pbk on 2023/01/27.
//

import XCTest
@testable import Tetra

final class URLSessionDownloadTests: XCTestCase {

    func testDefaultDownload() async throws {
        let (fileURL, response) = try await performDownload(on: .shared, from: URL(string: "https://www.shutterstock.com/image-photo/red-apple-isolated-on-white-260nw-1727544364.jpg")!)
        let httpResponse = response as! HTTPURLResponse
        addTeardownBlock {
            XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL))
        }
        let image = CGImage(jpegDataProviderSource: .init(url: fileURL as CFURL).unsafelyUnwrapped, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        XCTAssertNotNil(image)
        XCTAssertEqual(httpResponse.statusCode, 200)
    }
    
    func testCancelledDownload() async throws {
        let result = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await performDownload(on: .shared, from: URL(string: "https://www.shutterstock.com/image-photo/red-apple-isolated-on-white-260nw-1727544364.jpg")!)
        }.result
        XCTAssertThrowsError(try result.get()) {
            let urlError = $0 as! URLError
            XCTAssertEqual(urlError.code, .cancelled)
        }
    }
    
    func testCancellDuringDownload() async throws {
        let cancelTask2 = Task {
            try await performDownload(on: .shared, from: URL(string: "https://www.shutterstock.com/image-photo/red-apple-isolated-on-white-260nw-1727544364.jpg")!)
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        cancelTask2.cancel()
        let result = await cancelTask2.result
        XCTAssertThrowsError(try result.get()) {
            let urlError = $0 as! URLError
            XCTAssertEqual(urlError.code, .cancelled)
        }
    }


}
