//
//  Statement.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
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

/// SQLite Statement
public struct Statement: ~Copyable {
    
    let handle: Handle
    
    deinit {
        handle.finalize()
    }
}

public extension Statement {
    
    /**
     Return the number of columns in the result set returned by the prepared statement. If this routine returns 0, that means the prepared statement returns no data (for example an UPDATE). However, just because this routine returns a positive number does not mean that one or more rows of data will be returned. A SELECT statement will always have a positive sqlite3_column_count() but depending on the WHERE clause constraints and the table content, it might return no rows.
     */
    var columnCount: Int {
        Int(handle.columnCount)
    }
    
    /**
     Column Names In A Result Set
     */
    func columnName(at index: Int) -> String {
        handle.columnName(at: Int32(index))
    }
    
    /// Bind data at the specified index.
    func bind(_ binding: Binding, at index: Int, connection: borrowing Connection) throws(SQLiteError) {
        let index = Int32(index)
        return try handle.bind(binding, at: index, connection: connection.handle).get()
    }
}

internal extension Statement {
    
    /// Unsafe, Copyable wrapper for C pointer
    struct Handle: Copyable {
        
        let pointer: OpaquePointer
    }
}

internal extension Statement.Handle {
    
    consuming func finalize() {
        sqlite3_finalize(pointer)
    }
    
    var columnCount: Int32 {
        sqlite3_column_count(pointer)
    }
    
    func columnName(at index: Int32) -> String {
        String(cString: sqlite3_column_name(pointer, index))
    }
    
    func bindNull(at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_null(pointer, index))
    }
    
    /// Binds a BLOB of length N that is filled with zeroes. A zeroblob uses a fixed amount of memory (just an integer to hold its size) while it is being processed.
    /// Zeroblobs are intended to serve as placeholders for BLOBs whose content is later written using incremental BLOB I/O routines.
    ///
    /// A negative value for the zeroblob results in a zero-length BLOB.
    func bindZeroBlob(at index: Int32, count: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_zeroblob(pointer, index, count))
    }
    
    func bindBlob(_ rawBytes: UnsafeRawPointer, count: Int32, at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_blob(pointer, index, rawBytes, count, SQLITE_TRANSIENT))
    }
    
    func bindDouble(_ value: Double, at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_double(pointer, index, value))
    }
    
    func bindInt(_ value: Int64, at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_int64(pointer, index, value))
    }
    
    func bindText(_ value: String, at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_text(pointer, index, value, -1, SQLITE_TRANSIENT))
    }
    
    func bind(_ binding: Binding, at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        switch binding {
        case .null:
            return bindNull(at: index, connection: connection)
        case let .integer(value):
            return bindInt(value, at: index, connection: connection)
        case let .double(value):
            return bindDouble(value, at: index, connection: connection)
        case let .text(value):
            return bindText(value, at: index, connection: connection)
        case let .blob(.zero(count)):
            return bindZeroBlob(at: index, count: count, connection: connection)
        case let .blob(.pointer(block)):
            return block { buffer in
                bindBlob(buffer.baseAddress!, count: Int32(buffer.count), at: index, connection: connection)
            }
        }
    }
    
    func prepare() {
        
    }
}
