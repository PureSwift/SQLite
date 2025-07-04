//
//  DataBinding.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

#if canImport(Foundation)
import Foundation

extension Data: BindingConvertible {
    
    public var binding: Binding {
        guard isEmpty == false else {
            return .blob(.zero(0))
        }
        return .blob(.pointer({ body in
            withUnsafeBytes { buffer in
                body(buffer)
            }
        }))
    }
}

#endif
