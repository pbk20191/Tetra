//
//  File.swift
//  
//
//  Created by pbk on 2022/09/16.
//

import Foundation
import Combine

internal struct AsyncSequencePublisher<Source:AsyncSequence>: Publisher {

    public typealias Output = Source.Element
    public typealias Failure = Error
    
    public let source:Source
    
    @inlinable
    public init(source: Source) {
        self.source = source
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Source.Element == S.Input {
        Just(source).setFailureType(to: Error.self).flatMap(maxPublishers: .max(1)) { sequence in
            let subject = PassthroughSubject<Output,Error>()
            let task = Task {
                do {
                    for try await i in sequence {
                        subject.send(i)
                    }
                    subject.send(completion: .finished)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }
            return subject.handleEvents(receiveCancel: task.cancel)
        }.subscribe(subscriber)
    }
    
}
