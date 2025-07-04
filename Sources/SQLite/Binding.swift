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

// MARK: - Protocol

public protocol BindingConvertible {
    
    var binding: Binding { get }
}

extension Optional where Wrapped: BindingConvertible {
    
    public var binding: Binding {
        switch self {
        case .none:
            return .null
        case .some(let wrapped):
            return wrapped.binding
        }
    }
}

extension Int64: BindingConvertible {
    
    public var binding: Binding {
        .integer(self)
    }
}

extension Double: BindingConvertible {
    
    public var binding: Binding {
        .double(self)
    }
}

extension String: BindingConvertible {
    
    public var binding: Binding {
        .text(self)
    }
}

extension UnsafeRawBufferPointer: BindingConvertible {
    
    public var binding: Binding {
        let count = self.count
        guard let baseAddress = baseAddress, count > 0 else {
            return .blob(.zero(0))
        }
        return .blob(.pointer(baseAddress, Int32(count)))
    }
}

extension Bool: BindingConvertible {
    
    public var binding: Binding {
        .bool(self)
    }
}

extension Float: BindingConvertible {
    
    public var binding: Binding {
        .float(self)
    }
}

extension Int: BindingConvertible {
    
    public var binding: Binding {
        .integer(self)
    }
}
