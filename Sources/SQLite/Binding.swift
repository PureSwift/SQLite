//
//  Binding.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

/// SQLite Binding
public enum Binding: Sendable {
    
    case null
    case blob(Blob)
    case double(Double)
    case integer(Int64)
    case text(String)
}

public extension Binding {
    
    /// SQLite Binding Blob
    enum Blob: Sendable {
        
        /// Binds a BLOB of length N that is filled with zeroes.
        case zero(Int32)
        
        /// Data pointer
        case pointer(@Sendable ((UnsafeRawBufferPointer) -> (Result<Void, SQLiteError>)) -> (Result<Void, SQLiteError>))
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

extension Optional: BindingConvertible where Wrapped: BindingConvertible {
    
    public var binding: Binding {
        switch self {
        case .none:
            return .null
        case .some(let wrapped):
            return wrapped.binding
        }
    }
}

extension Sequence where Element: BindingConvertible {
    
    public var binding: [Binding] {
        map { $0.binding }
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

// MARK: - Conversion

internal extension Binding {
    
    static func integerCast<T: FixedWidthInteger>(_ value: T) -> Binding {
        .integer(numericCast(value) as Int64)
    }
}

extension FixedWidthInteger {

    public var binding: Binding {
        .integerCast(self)
    }
}

public extension Binding {
    
    /// Returns the integer value of the data, performing conversions where possible.
    ///
    /// If the data has `REAL` or `TEXT` affinity, an attempt is made to interpret the value as an integer. `BLOB`
    /// and `NULL` values always return `nil`.
    var integer: Int64? {
        switch self {
        case .integer(let integer):
            return integer
        case .double(let double):
            return Int64(double)
        case .text(let string):
            return Int64(string)
        case .blob, .null:
            return nil
        }
    }

    /// Returns the real number value of the data, performing conversions where possible.
    ///
    /// If the data has `INTEGER` or `TEXT` affinity, an attempt is made to interpret the value as a `Double`. `BLOB`
    /// and `NULL` values always return `nil`.
    var double: Double? {
        switch self {
        case .integer(let integer):
            return Double(integer)
        case .double(let double):
            return double
        case .text(let string):
            return Double(string)
        case .blob, .null:
            return nil
        }
    }

    /// Returns the textual value of the data, performing conversions where possible.
    ///
    /// If the data has `INTEGER` or `REAL` affinity, the value is converted to text. `BLOB` and `NULL` values always
    /// return `nil`.
    var string: String? {
        switch self {
        case .integer(let integer):
            return String(integer)
        case .double(let double):
            return String(double)
        case .text(let string):
            return string
        case .blob, .null:
            return nil
        }
    }
}
