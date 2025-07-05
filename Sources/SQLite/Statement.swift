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
    
    public init(_ sql: String, connection: borrowing Connection) throws(SQLiteError) {
        self.handle = try Handle.prepare(sql, connection: connection.handle).get()
    }
    
    deinit {
        handle.finalize()
    }
}

public extension Statement {
    
    var sql: String {
        handle.sql
    }
    
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
}

public extension Statement {
    
    static func prepare(_ sql: String, bindings: [Binding], connection: borrowing Connection) throws(SQLiteError) -> Statement {
        var statement = try Statement(sql, connection: connection)
        for (index, binding) in bindings.enumerated() {
            try statement.bind(binding, at: index + 1, connection: connection)
        }
        return statement
    }
}

internal extension Statement {
    
    /// Bind data at the specified index.
    mutating func bind(_ binding: Binding, at index: Int, connection: borrowing Connection) throws(SQLiteError) {
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
    
    static func prepare(
        _ sql: String,
        connection: Connection.Handle,
    ) -> Result<Statement.Handle, SQLiteError> {
        var pointer: OpaquePointer?
        let errorCode = sqlite3_prepare_v2(connection.pointer, sql, -1, &pointer, nil)
        guard let pointer else {
            return .failure(SQLiteError(errorCode: SQLiteError.ErrorCode(errorCode), message: "Unable to initialize statement.", connection: connection.filename, statement: sql))
        }
        let handle = Statement.Handle(pointer: pointer)
        guard errorCode == SQLITE_OK else {
            let error = connection.forceError(SQLiteError.ErrorCode(errorCode))
            return .failure(error)
        }
        return .success(handle)
    }
    
    var sql: String {
        String(cString: sqlite3_sql(pointer))
    }
    
    var columnCount: Int32 {
        sqlite3_column_count(pointer)
    }
    
    func columnName(at index: Int32) -> String {
        String(cString: sqlite3_column_name(pointer, index))
    }
    
    func bindNull(at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_null(pointer, index), statement: sql)
    }
    
    /// Binds a BLOB of length N that is filled with zeroes. A zeroblob uses a fixed amount of memory (just an integer to hold its size) while it is being processed.
    /// Zeroblobs are intended to serve as placeholders for BLOBs whose content is later written using incremental BLOB I/O routines.
    ///
    /// A negative value for the zeroblob results in a zero-length BLOB.
    func bindZeroBlob(at index: Int32, count: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_zeroblob(pointer, index, count), statement: sql)
    }
    
    func bindBlob(_ rawBytes: UnsafeRawPointer, count: Int32, at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_blob(pointer, index, rawBytes, count, SQLITE_TRANSIENT), statement: sql)
    }
    
    func bindDouble(_ value: Double, at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_double(pointer, index, value), statement: sql)
    }
    
    func bindInt(_ value: Int64, at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_int64(pointer, index, value), statement: sql)
    }
    
    func bindText(_ value: String, at index: Int32, connection: Connection.Handle) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_bind_text(pointer, index, value, -1, SQLITE_TRANSIENT), statement: sql)
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
    
    func step(connection: Connection.Handle) -> Result<Bool, SQLiteError> {
        // peform step
        let resultCode = sqlite3_step(pointer)
        // check for error
        if let errorCode = SQLiteError.ErrorCode(rawValue: resultCode) {
            let error = connection.forceError(errorCode, statement: sql)
            return .failure(error)
        }
        // return if done
        let hasMoreData = resultCode == SQLITE_ROW
        return .success(hasMoreData)
    }
    
    func readText(at index: Int32, connection: Connection.Handle) -> Result<String, SQLiteError> {
        let string = sqlite3_column_text(pointer, index).flatMap { String(cString: $0) }
        // check for errors
        if let errorCode = connection.errorCode {
            let error = connection.forceError(errorCode, statement: sql)
            return .failure(error)
        }
        return .success(string ?? "")
    }
    
    func readInteger(at index: Int32, connection: Connection.Handle) -> Result<Int64, SQLiteError> {
        let value = sqlite3_column_int64(pointer, index)
        // check for errors
        if let errorCode = connection.errorCode {
            let error = connection.forceError(errorCode, statement: sql)
            return .failure(error)
        }
        return .success(value)
    }
    
    func readDouble(at index: Int32, connection: Connection.Handle) -> Result<Double, SQLiteError> {
        let value = sqlite3_column_double(pointer, index)
        // check for errors
        if let errorCode = connection.errorCode {
            let error = connection.forceError(errorCode, statement: sql)
            return .failure(error)
        }
        return .success(value)
    }
    
    func readBlob(at index: Int32, connection: Connection.Handle) -> Result<UnsafeRawPointer, SQLiteError> {
        guard let value = sqlite3_column_blob(pointer, index) else {
            let error = connection.forceError(connection.errorCode ?? .init(SQLITE_ERROR), statement: sql)
            return .failure(error)
        }
        // check for errors
        if let errorCode = connection.errorCode {
            let error = connection.forceError(errorCode, statement: sql)
            return .failure(error)
        }
        return .success(value)
    }
    
    func readBlobSize(at index: Int32, connection: Connection.Handle) -> Result<Int32, SQLiteError> {
        let value = sqlite3_column_bytes(pointer, index)
        // check for errors
        if let errorCode = connection.errorCode {
            let error = connection.forceError(errorCode, statement: sql)
            return .failure(error)
        }
        return .success(value)
    }
    
    func readType(at index: Int32, connection: Connection.Handle) -> Result<Column.ValueType, SQLiteError> {
        let type = sqlite3_column_type(pointer, index)
        switch type {
        case SQLITE_INTEGER:
            return .success(.integer)
        case SQLITE_FLOAT:
            return .success(.double)
        case SQLITE_TEXT:
            return .success(.text)
        case SQLITE_BLOB:
            return .success(.blob)
        case SQLITE_NULL:
            return .success(.null)
        default:
            let error = connection.forceError(connection.errorCode ?? .init(SQLITE_ERROR), statement: sql)
            return .failure(error)
        }
    }
}
