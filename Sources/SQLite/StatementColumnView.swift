//
//  StatementColumnView.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

public extension Statement {
    
    func withColumns<T>(
        _ connection: borrowing Connection,
        limit: UInt? = nil,
        _ block: (borrowing Column) throws(SQLiteError) -> (T)
    ) throws(SQLiteError) -> [T] {
        let statement = handle
        let connection = connection.handle
        let column = Column(
            statement: statement,
            connection: connection
        )
        var results = [T]()
        if let limit {
            results.reserveCapacity(Int(limit))
        }
        while try handle.step(connection: connection).get() {
            let result = try block(column)
            results.append(result)
            // stop aggregating results
            if let limit {
                guard results.count <= limit else {
                    return results
                }
            }
        }
        return results
    }
    
    struct Column {
        
        let statement: Statement.Handle
        
        let connection: Connection.Handle
    }
}

// MARK: - RandomAccessCollection

extension Statement.Column: RandomAccessCollection {
    
    public typealias Element = String
    
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
        return statement.columnName(at: Int32(position))
    }
    
    public func index(after i: Int) -> Int {
        i + 1
    }
}
