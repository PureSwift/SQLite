//
//  Connection.swift
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

/// SQLite Database Connection
public struct Connection: ~Copyable {
    
    let handle: Handle
    
    /// Whether or not the database will return extended error codes when errors are handled.
    public var usesExtendedErrorCodes: Bool = false {
        didSet {
            try! handle.setUsesExtendedErrorCodes(usesExtendedErrorCodes).get()
        }
    }
    
    public init(
        path: String,
        isReadOnly: Bool = false
    ) throws(SQLiteError) {
        self.handle = try Handle.open(path: path).get()
    }
    
    deinit {
        handle.close()
    }
}

// MARK: - Properties

public extension Connection {
    
    static var isThreadSafe: Bool {
        sqlite3_threadsafe() != 0
    }
    
    /// Whether or not the database was opened in a read-only state.
    var isReadonly: Bool {
        handle.isReadonly
    }
    
    /// The last rowid inserted into the database via this connection.
    var lastInsertRowID: Int64 {
        handle.lastInsertRowID
    }
    
    /// The last number of changes (inserts, updates, or deletes) made to the
    /// database via this connection.
    var changes: Int32 {
        handle.changes
    }
    
    /// The total number of changes (inserts, updates, or deletes) made to the
    /// database via this connection.
    var totalChanges: Int32 {
        handle.totalChanges
    }
    
    var filename: String {
        handle.filename
    }
}

// MARK: - Methods

public extension Connection {
    
    /// Execute the statement and iterate the rows.
    func execute(
        _ statement: consuming Statement,
        limit: UInt? = nil,
        _ block: (consuming Row) throws(SQLiteError) -> ()
    ) throws(SQLiteError) {
        var index = 0
        while try statement.handle.step(connection: self.handle).get() {
            let row = Row(
                index: index,
                statement: statement,
                connection: self
            )
            // read data
            try block(row)
            // stop aggregating results
            if let limit {
                guard index < limit else {
                    return
                }
            }
            // increment index
            index += 1
        }
    }
}

// MARK: - Supporting Types

internal extension Connection {
    
    struct Handle {
                
        let pointer: OpaquePointer
    }
}

internal extension Connection.Handle {
    
    consuming func close() {
        sqlite3_close(pointer)
    }
    
    static func open(path: String, readonly: Bool = false) -> Result<Connection.Handle, SQLiteError> {
        let flags = readonly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
        var pointer: OpaquePointer?
        let errorCode = sqlite3_open_v2(
            path,
            &pointer,
            flags | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI,
            nil
        )
        guard let pointer else {
            assertionFailure("Unable to unwrap pointer")
            return .failure(.init(errorCode: .init(errorCode), message: "Unable to initialize connection.", connection: path))
        }
        let handle = Connection.Handle(pointer: pointer)
        guard errorCode == SQLITE_OK else {
            let error = handle.forceError(SQLiteError.ErrorCode(errorCode))
            return .failure(error)
        }
        return .success(handle)
    }
    
    func setUsesExtendedErrorCodes(_ usesExtendedErrorCodes: Bool) -> Result<Void, SQLiteError> {
        check(sqlite3_extended_result_codes(pointer, usesExtendedErrorCodes ? 1 : 0))
    }
    
    var errorCode: SQLiteError.ErrorCode? {
        .init(rawValue: sqlite3_errcode(pointer))
    }
    
    var errorMessage: String? {
        sqlite3_errmsg(pointer).flatMap { String(cString: $0) }
    }
    
    func check(
        _ resultCode: Int32,
        file: StaticString = #file,
        function: StaticString = #function
    ) -> Result<Void, SQLiteError>  {
        guard let errorCode = SQLiteError.ErrorCode(rawValue: resultCode) else {
            return .success(())
        }
        let error = forceError(errorCode, file: file, function: function)
        return .failure(error)
    }
    
    func forceError(
        _ errorCode: SQLiteError.ErrorCode,
        file: StaticString = #file,
        function: StaticString = #function
    ) -> SQLiteError  {
        let errorMessage = errorMessage ?? "Unknown error"
        let filename = self.filename
        let error = SQLiteError(errorCode: errorCode, message: errorMessage, connection: filename, file: file, function: function)
        return error
    }
    
    /// Whether or not the database was opened in a read-only state.
    var isReadonly: Bool {
        sqlite3_db_readonly(pointer, nil) == 1
    }
    
    /// The last rowid inserted into the database via this connection.
    var lastInsertRowID: Int64 {
        sqlite3_last_insert_rowid(pointer)
    }
    
    /// The last number of changes (inserts, updates, or deletes) made to the
    /// database via this connection.
    var changes: Int32 {
        sqlite3_changes(pointer)
    }
    
    /// The total number of changes (inserts, updates, or deletes) made to the
    /// database via this connection.
    var totalChanges: Int32 {
        sqlite3_total_changes(pointer)
    }
    
    var filename: String {
        String(cString: sqlite3_db_filename(pointer, nil))
    }
}
