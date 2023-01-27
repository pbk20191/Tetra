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

}
