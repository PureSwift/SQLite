//
//  StatementColumnView.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

/// SQLite Query Results Column
public struct Column: Equatable, Hashable, Sendable {
    
    public let row: Int
    
    public let index: Int
    
    public let name: String
}

extension Column: Identifiable {
    
    public var id: Int {
        index
    }
}

public extension Column {
    
    enum ValueType: Equatable, Hashable, Sendable, CaseIterable {
        
        case null
        case blob
        case double
        case integer
        case text
    }
}

public extension Column {
    
    @available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, visionOS 1.1, *)
    enum Value: ~Escapable {
        
        case null
        case blob(RawSpan)
        case double(Double)
        case integer(Int64)
        case text(String)
    }
}

@available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, visionOS 1.1, *)
public extension Column.Value {
    
    var type: Column.ValueType {
        switch self {
        case .null:
            return .null
        case .blob:
            return .blob
        case .double:
            return .double
        case .integer:
            return .integer
        case .text:
            return .text
        }
    }
}

@available(macOS 10.14.4, iOS 12.2, watchOS 5.2, tvOS 12.2, visionOS 1.1, *)
public extension Row {
    
    /// Reads the value at the specified column index.
    func read<T>(
        at index: Int,
        _ block: (consuming Column.Value) -> T
    ) throws(SQLiteError) -> T {
        // read type
        let type = try readType(at: index)
        // read value
        let index = Int32(index)
        let value: Column.Value
        switch type {
        case .null:
            value = .null
        case .double:
            let double = try statement.readDouble(at: index, connection: connection).get()
            value = .double(double)
        case .integer:
            let integer = try statement.readInteger(at: index, connection: connection).get()
            value = .integer(integer)
        case .text:
            let string = try statement.readText(at: index, connection: connection).get()
            value = .text(string)
        case .blob:
            // TODO: Read binary data
            fatalError()
        }
        // convert value
        return block(value)
    }
}
