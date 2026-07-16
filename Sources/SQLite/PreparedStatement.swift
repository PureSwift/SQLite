//
//  PreparedStatement.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

#if SQLITE_SWIFT_STANDALONE
import sqlite3
#elseif SQLITE_SWIFT_SQLCIPHER
import SQLCipher
#elseif os(Linux)
import SwiftToolchainCSQLite
#else
import SQLite3
#endif

/// A reference-typed cursor over a prepared statement, for callers that need to hold
/// a statement and pull rows from it across multiple call sites rather than within a
/// single `Connection.execute` closure. Finalizes itself on deinit, like `Statement`.
public final class PreparedStatement {

    let statement: Statement.Handle

    let connection: Connection.Handle

    init(statement: Statement.Handle, connection: Connection.Handle) {
        self.statement = statement
        self.connection = connection
    }

    deinit {
        statement.finalize()
    }
}

public extension Connection {

    /// Prepare a statement and bind the given values, returning a cursor that can be
    /// stepped through with `failableNext()` across multiple call sites.
    func prepare(_ sql: String, _ bindings: [Binding?] = []) throws(SQLiteError) -> PreparedStatement {
        let handle = try Statement.Handle.prepare(sql, connection: self.handle).get()
        for (index, binding) in bindings.enumerated() {
            try handle.bind(binding ?? .null, at: Int32(index + 1), connection: self.handle).get()
        }
        return PreparedStatement(statement: handle, connection: self.handle)
    }
}

public extension PreparedStatement {

    var columnNames: [String] {
        (0 ..< statement.columnCount).map { statement.columnName(at: $0) }
    }

    /// Steps to the next row, if any, returning its values as `Binding?` (`nil` for `NULL`).
    func failableNext() throws(SQLiteError) -> [Binding?]? {
        guard try statement.step(connection: connection).get() else {
            return nil
        }
        let count = statement.columnCount
        var values = [Binding?]()
        values.reserveCapacity(Int(count))
        for index in 0 ..< count {
            let type = try statement.readType(at: index, connection: connection).get()
            switch type {
            case .null:
                values.append(nil)
            case .integer:
                values.append(.integer(try statement.readInteger(at: index, connection: connection).get()))
            case .double:
                values.append(.double(try statement.readDouble(at: index, connection: connection).get()))
            case .text:
                values.append(.text(try statement.readText(at: index, connection: connection).get()))
            case .blob:
                let size = try statement.readBlobSize(at: index, connection: connection).get()
                let bytes: [UInt8]
                if size > 0 {
                    let pointer = try statement.readBlob(at: index, connection: connection).get()
                    bytes = [UInt8](UnsafeRawBufferPointer(start: pointer, count: Int(size)))
                } else {
                    bytes = []
                }
                values.append(.blob(.pointer { block in bytes.withUnsafeBytes(block) }))
            }
        }
        return values
    }

    /// Iterate all remaining rows as dictionaries keyed by column name.
    func rowDictionaries() throws(SQLiteError) -> [[String: Binding?]] {
        let names = columnNames
        var results = [[String: Binding?]]()
        while let row = try failableNext() {
            var dictionary = [String: Binding?](minimumCapacity: names.count)
            for (index, name) in names.enumerated() {
                dictionary[name] = row[index]
            }
            results.append(dictionary)
        }
        return results
    }
}
