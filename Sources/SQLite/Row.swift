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

public extension Row {
    
    var columns: Columns {
        Columns(
            row: index,
            statement: statement,
            connection: connection
        )
    }
    
    struct Columns {
        
        let row: Int
        
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
