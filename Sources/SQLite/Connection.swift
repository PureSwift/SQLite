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

public struct Connection: ~Copyable {
    
    let handle: Handle
    
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

public extension Connection {
    
    static var isThreadSafe: Bool {
        sqlite3_threadsafe() != 0
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
        guard errorCode == SQLITE_OK else {
            return .failure(SQLiteError(errorCode: errorCode))
        }
        guard let pointer else {
            assertionFailure("Unable to unwrap pointer")
            return .failure(.init(errorCode: SQLITE_ERROR))
        }
        let handle = Connection.Handle(pointer: pointer)
        return .success(handle)
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
