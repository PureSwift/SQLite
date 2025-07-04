//
//  Row.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

/// SQLite Database Row
public struct Row: ~Copyable {
    
    // Results Index
    public let index: Int
    
    internal let statement: Statement.Handle
    
    internal let connection: Connection.Handle
    
    internal init(
        index: Int,
        statement: borrowing Statement,
        connection: borrowing Connection
    ) {
        self.index = index
        self.statement = statement.handle
        self.connection = connection.handle
    }
}

extension Row {
    
    public typealias ID = Int
    
    public var id: Int {
        index
    }
}

public extension Row {
    
    /// `Sequence` view for convenience.
    var columns: Columns {
        Columns(
            row: index,
            statement: statement,
            connection: connection
        )
    }
    
    var isEmpty: Bool {
        count == 0
    }
    
    var count: Int {
        Int(statement.columnCount)
    }
    
    var startIndex: Int { 0 }
    
    var endIndex: Int { count }
    
    /// Read the data type.
    func readType(at index: Column.ID) throws(SQLiteError) -> Column.ValueType {
        try statement.readType(at: Int32(index), connection: connection).get()
    }
}

// MARK: - Supporting Types

public extension Row {
    
    struct Columns {
        
        public let row: Row.ID
        
        internal let statement: Statement.Handle
        
        internal let connection: Connection.Handle
    }
}

extension Row.Columns: RandomAccessCollection {
    
    public typealias Element = Column
    
    public typealias Index = Int

    public var isEmpty: Bool {
        count == 0
    }
    
    public var count: Int {
        Int(statement.columnCount)
    }
    
    public var startIndex: Int { 0 }
    
    public var endIndex: Int { count }
    
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < count, "Index out of bounds")
        let name = statement.columnName(at: Int32(position))
        return Column(row: row, index: position, name: name)
    }
    
    public func index(after i: Int) -> Int {
        i + 1
    }
}
