//
//  Convenience.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

public extension Connection {

    /// Prepare, bind, and execute a statement to completion, discarding any rows.
    func run(_ sql: String, _ bindings: [Binding?] = []) throws(SQLiteError) {
        let statement = try prepare(sql, bindings)
        while try statement.failableNext() != nil {}
    }

    /// Run a statement and return the first column of its first row, if any.
    func scalar(_ sql: String, _ bindings: [Binding?] = []) throws(SQLiteError) -> Binding? {
        let statement = try prepare(sql, bindings)
        guard let row = try statement.failableNext() else {
            return nil
        }
        return row.first ?? nil
    }

    /// Run `body` inside a `BEGIN`/`COMMIT` transaction, rolling back if it throws.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try run("BEGIN")
        do {
            let result = try body()
            try run("COMMIT")
            return result
        } catch {
            try? run("ROLLBACK")
            throw error
        }
    }
}
