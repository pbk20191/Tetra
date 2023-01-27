//
//  AnyErasedEncodable.swift
//  
//
//  Created by pbk on 2023/01/27.
//

import Foundation


struct AnyErasedEncodable: Encodable {
    
    let value:Encodable
    
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
    
}
