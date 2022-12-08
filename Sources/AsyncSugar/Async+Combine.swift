//
//  File.swift
//  
//
//  Created by pbk on 2022/09/16.
//

import Foundation
import Combine

public extension AsyncSequence {
    
    var omittedPublisher:AnyPublisher<Element,Never> {
        Just(self).flatMap(maxPublishers: .max(1)) { source in
            let subject = PassthroughSubject<Element,Never>()
            let task = Task {
                await withTaskCancellationHandler {
                    var iterator = source.makeAsyncIterator()
                    while let i = try? await iterator.next() {
                        subject.send(i)
                    }
                    subject.send(completion: .finished)
                } onCancel: {
//                    print("asyncSequence cancelled")
                }
            }
            return subject.handleEvents(receiveCancel: task.cancel)
        }.eraseToAnyPublisher()
    }
    
    var publisher:AnyPublisher<Element,Error> {
        if #available(iOS 14.0, tvOS 14.0, macCatalyst 14.0, watchOS 7.0, macOS 11.0, *) {
            return Just(self).flatMap(maxPublishers: .max(1)) { source in
                let subject = PassthroughSubject<Element,Error>()
                let task = Task {
                    await withTaskCancellationHandler {
                        do {
                            for try await i in source {
                                subject.send(i)
                            }
                            subject.send(completion: .finished)
                        } catch {
                            subject.send(completion: .failure(error))
                        }
                    } onCancel: {
//                        print("asyncSequence cancelled")
                    }
                }
                return subject.handleEvents(receiveCancel: task.cancel)
            }.eraseToAnyPublisher()
        } else {
            return Just(self).setFailureType(to: Error.self).flatMap(maxPublishers: .max(1)) { source in
                let subject = PassthroughSubject<Element,Error>()
                let task = Task {
                    await withTaskCancellationHandler {
                        do {
                            for try await i in source {
                                subject.send(i)
                            }
                            subject.send(completion: .finished)
                        } catch {
                            subject.send(completion: .failure(error))
                        }
                    } onCancel: {
                        print("asyncSequence cancelled")
                    }

                }
                    
                return subject.handleEvents(receiveCancel: task.cancel)
            }.eraseToAnyPublisher()
        }

    }
}
