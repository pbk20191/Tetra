import XCTest
import Foundation
import Dispatch
//import AsyncAlgorithms
//import Atomics
import Combine
@testable import AsyncCompat

final class AsyncCompatTests: XCTestCase {
    func testExample() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        
//        var errorPointer:Unmanaged<CFError>? = nil
//        let secAccessControl = SecAccessControlCreateWithFlags(
//            kCFAllocatorDefault,
//            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
//            .and,
//            &errorPointer
//        )
//        let result:Result<SecAccessControl,CFError>
//        if let error = errorPointer?.takeRetainedValue() {
//            result = .failure(error)
//        } else {
//            result = .success(secAccessControl!)
//        }
//        try? await Task.sleep(nanoseconds: 100000)
//        print(result)
//        let someObject:CodablePrimitive = [
//            "SDF": 0,
//            "zzzz": true,
//            "axczx32": "SDFSDf",
//            "ZCXZQ@#$": 102.123
//        ]
//        let data = try PropertyListEncoder().encode(someObject)
//        let new = try PropertyListDecoder().decode(CodablePrimitive.self, from: data)
//        print(someObject.propertyObject)
        
    }
    
    @available(iOS 16.0, macOS 12.0, *)
    func testExampleAsync() async throws {
        let a = (0..<100).publisher.print().values
        let task = Task {
            
            print(Thread.current.threadDictionary)
            var it = a.makeAsyncIterator()
            while let _ = await it.next() {
                if Task.isCancelled {
                    return it
                } else {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            return it
        }
        try await Task.sleep(nanoseconds: 250_000_000)
        task.cancel()
        let it = await task.value

        await Task {
            await withTaskGroup(of: Void.self) { group in
                (0..<10).forEach{ _ in
                    group.addTask {
                        var newI = it
                        while let _ = await newI.next() {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                        }
                        print("group task done")
                    }
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
                group.cancelAll()
            }
            print("task finished")
        }.value

    }
    
    @available(iOS 16.0, *)
    func testAsyncToPublisher() async throws {
//
//        let startTime = ContinuousClock.now
//        let source = (0..<100).async.map{
//            try await Task.sleep(nanoseconds: 500_000_000)
//            return $0
//        }
//        let sample2 = (0..<100).publisher
//            .zip(Timer.publish(every: 0.5, on: .main, in: .default).autoconnect()) { item, time in
//                item
//            }
//            .eraseToAnyPublisher()
////        AsyncThrowingSequencePublisher3(source: sample2.asyncStream)
//        let task = Task {
////
////            try await withThrowingCancellation {
////                do {
////                    let _:Void = try await withUnsafeThrowingContinuation { continuation in
////                        DispatchQueue.global().schedule(after: .init(.now() + 6)) {
////                            continuation.resume(throwing: URLError(URLError.cancelled))
////                        }
////                    }
////                } catch {
////                    print("\(error)\(ContinuousClock.now - startTime)" )
////                }
////
////            }
//            for await i in (0..<100).publisher.print().values {
//                //try? await Task.sleep(nanoseconds: 1_000_000_000)
//            }
//        }
//
//        do {
//            try await Task.sleep(nanoseconds: 1_000)
//           // task.cancel()
//            try await withTaskCancellationHandler {
//             //   task.cancel()
//            } operation: {
//                try await task.value
//            }
//        } catch {
//            print(error)
//        }
//
////        try? await Task.sleep(until: ContinuousClock.now.advanced(by: .seconds(3)), clock: .continuous)
    }

}
