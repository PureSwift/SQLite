//
//  Binding.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

/// SQLite Binding
public enum Binding: Equatable, Hashable {
    
    case null
    case blob(Blob)
    case double(Double)
    case integer(Int64)
    case text(String)
}

public extension Binding {
    
    /// SQLite Binding Blob
    enum Blob: Equatable, Hashable {
        
        /// Binds a BLOB of length N that is filled with zeroes.
        case zero(Int32)
        
        /// Data pointer
        case pointer(UnsafeRawPointer, Int32)
    }
}

// MARK: - Data Types

public extension Binding {
    
    static func bool(_ value: Bool) -> Binding {
        // SQLite does not have a separate Boolean storage class. Instead, Boolean values are stored as integers 0 (false) and 1 (true).
        let intValue: Int64 = value ? 1 : 0
        return .integer(intValue)
    }
    
    static func float(_ value: Float) -> Binding {
        .double(Double(value))
    }
    
    static func integer(_ value: Int) -> Binding {
        .integer(Int64(value))
    }
}
