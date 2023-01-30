//
//  DecodingTypeError.swift
//  
//
//  Created by pbk on 2023/01/30.
//

import Foundation

/// `DecodingError.typeMismatch` wrapper type to unwind stack of decoding
@usableFromInline
struct DecodingTypeError {
 
    @usableFromInline
    let expectedType:Any.Type
    @usableFromInline
    let context:DecodingError.Context
    
    @usableFromInline
    internal init(expectedType: Any.Type, context: DecodingError.Context) {
        self.expectedType = expectedType
        self.context = context
    }
    
}

extension DecodingTypeError: LocalizedError {
    
    @usableFromInline
    var decodingError:DecodingError {
        .typeMismatch(expectedType, context)
    }
    
    @usableFromInline
    var localizedDescription:String {
        decodingError.localizedDescription
    }
    
    @usableFromInline
    var errorDescription: String? {
        decodingError.errorDescription
    }
    
    @usableFromInline
    var failureReason: String? {
        decodingError.failureReason
    }
    
    @usableFromInline
    var helpAnchor: String? {
        decodingError.helpAnchor
    }
    
    @usableFromInline
    var recoverySuggestion: String? {
        decodingError.recoverySuggestion
    }
    
}
