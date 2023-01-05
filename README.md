# Tetra

A description of this package.
This provides some features that were only available at least iOS 15 and macOS 12.

iOS 15, macOS 12 등에서만 사용이 가능한 API를 iOS 13, iOS 10.15 등에서 사용할 수 있도록 하는 것으로 목표로 개발되었습니다.

async await URLSession download, upload
async await NSManagedContext peform
Combine <-> AsyncSequence interchanging 

## Usage
<details open>

  <summary>Publishers.(Try)MapTask</summary>
  
  
  Transform upstream value using async (throwing) closure
  
```swift
import Combine
import Tetra
        
        let cancellable = (0..<20).publisher
            .tryMapTask { _ in
                // Underlying Task is cancelled if subscription is cancelled before task completes.
                try await URLSession.shared.data(from: URL(string: "https://google.com")!)
            }.map(\.0).sink { completion in
                
            } receiveValue: { data in
                
            }

```
</details>


<details open>
  <summary>AsyncSequencePublisher</summary>
  Transform AsyncSequence to Publisher
  
```swift
import Combine
import Tetra
        
        let cancellable = AsyncStream<Int> { continuation in
            continuation.yield(0)
            continuation.yield(1)
            continuation.finish()
            // Underlying AsyncIterator and Task receive task cancellation if subscription is cancelled.
        }.asyncPublisher
            .catch{ _ in Empty().setFailureType(to: Never.self) }
            .sink { number in
                
            }

```
</details>

<details open>
  <summary>NotificationSequence</summary>
  AsyncSequence compatible with `NotificationCenter.Notifications`
  Available even in iOS 13
  
```swift
import Combine
import Tetra
import UIKit
        
        // use NotificationCenter.Notifications if available otherwise use NotficationSequence under the hood
        for await notification in NotificationCenter.default.sequence(named: UIApplication.didFinishLaunchingNotification) {
            
        }
```
</details>

<details open>
  <summary>CompatAsync(Throwing)Publisher</summary>
  AsyncSequence compatible with `Async(Throwing)Publisher`
  Available even in iOS 13
  
```swift
import Combine
import Tetra
        
        // use AsyncThrowingPublisher if available otherwise use CompatAsyncThrowingPublisher under the hood.
        for try await (data, response) in URLSession.shared.dataTaskPublisher(for: URL(string: "https://google.com")!).sequence {
            
        }
```
</details>

<details open>
  <summary>RefreshableScrollView</summary>
  Compatible pull to refresh feature in all version for iOS
  
```swift
import SwiftUI
import Tetra
        
struct ContentView: View {
    
    var body: some View {
        RefreshableScrollView {
            
        }
        .refreshControl {
            await fetchData()
        }
    }
}

```
</details>

