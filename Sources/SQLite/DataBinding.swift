//
//  DataBinding.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

#if canImport(Foundation)
import Foundation

extension Data {
    
    public func withBinding<Result>(_ body: (_ buffer: Binding) -> Result) -> Result {
        return withUnsafeBytes { buffer in
            body(buffer.binding)
        }
    }
}

#endif

@available(macOS 10.14.4, *)
extension RawSpan {
    /*
    public func withBinding<E, Result>(_ body: (_ buffer: Binding) throws(E) -> Result) throws(E) -> Result where E : Error, Result : ~Copyable {
        return try withUnsafeBytes { buffer in
            try body(buffer.binding)
        }
    }
    */
    public func withBinding<Result>(_ body: (_ buffer: Binding) -> Result) -> Result where Result : ~Copyable {
        return withUnsafeBytes { buffer in
            body(buffer.binding)
        }
    }
}
