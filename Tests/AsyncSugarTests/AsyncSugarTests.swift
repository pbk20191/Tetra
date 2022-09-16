import XCTest
import Foundation
import Dispatch
@testable import AsyncSugar

final class AsyncSugarTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        
    }
    
    @available(iOS 16.0, *)
    func testExampleAsync() async throws {
        
        let startTime = ContinuousClock.now
        let task = Task {
            
            try await withThrowingCancellation {
                do {
                    let _:Void = try await withUnsafeThrowingContinuation { continuation in
                        DispatchQueue.global().schedule(after: .init(.now() + 6)) {
                            continuation.resume(throwing: URLError(URLError.cancelled))
                        }
                    }
                } catch {
                    print("\(error)\(ContinuousClock.now - startTime)" )
                }
                
            }
        
        }
        
        do {
            try await Task.sleep(nanoseconds: 1_000)
            task.cancel()
            try await withTaskCancellationHandler {
                task.cancel()
            } operation: {
                try await task.value
            }
        } catch {
            print(error)
        }
        
//        try? await Task.sleep(until: ContinuousClock.now.advanced(by: .seconds(3)), clock: .continuous)
    }
    

}
