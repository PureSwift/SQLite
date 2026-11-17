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
    ///
    /// Inside another transaction, `body` runs in a savepoint instead: if it throws,
    /// only its own changes are undone, and the ones it makes are kept only if the
    /// enclosing transaction commits. So a caller can group operations that each use
    /// a transaction of their own into one that's all or nothing.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        guard isAutocommit else {
            return try savepoint(body)
        }
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

    /// Run `body` inside a savepoint, rolling back to it if it throws.
    ///
    /// Outside a transaction, a savepoint starts one and commits it when released.
    func savepoint<T>(_ body: () throws -> T) throws -> T {
        // A savepoint's name refers to the innermost one, so nested calls can share it.
        try run("SAVEPOINT \"transaction\"")
        do {
            let result = try body()
            try run("RELEASE \"transaction\"")
            return result
        } catch {
            try? run("ROLLBACK TO \"transaction\"")
            try? run("RELEASE \"transaction\"")
            throw error
        }
    }
}
