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
    
    enum Value: ~Escapable {
        
        case null
        case blob(UnsafeRawBufferPointer)
        case double(Double)
        case integer(Int64)
        case text(String)
    }
}

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

public extension Row {
    
    /// Reads the value at the specified column index.
    func read<T>(
        at index: Column.ID,
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
            let size = try statement.readBlobSize(at: index, connection: connection).get()
            let bufferPointer: UnsafeRawBufferPointer
            if size > 0 {
                let pointer = try statement.readBlob(at: index, connection: connection).get()
                bufferPointer = UnsafeRawBufferPointer(start: pointer, count: Int(size))
            } else {
                bufferPointer = UnsafeRawBufferPointer(start: nil, count: 0)
            }
            value = .blob(bufferPointer)
        }
        // convert value
        return block(value)
    }
}
