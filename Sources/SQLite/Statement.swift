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
    
    init(handle: Handle) {
        self.handle = handle
    }
    
    deinit {
        handle.finalize()
    }
}

public extension Statement {
    
    /**
     Return the number of columns in the result set returned by the prepared statement. If this routine returns 0, that means the prepared statement returns no data (for example an UPDATE). However, just because this routine returns a positive number does not mean that one or more rows of data will be returned. A SELECT statement will always have a positive sqlite3_column_count() but depending on the WHERE clause constraints and the table content, it might return no rows.
     */
    var columnCount: Int {
        handle.columnCount
    }
    
    /**
     Column Names In A Result Set
     */
    func columnName(at index: Int) -> String {
        handle.columnName(at: index)
    }
}

internal extension Statement {
    
    /// Unsafe, Copyable wrapper for C pointer
    struct Handle: Copyable {
        
        let pointer: OpaquePointer
    }
}

internal extension Statement.Handle {
    
    func finalize() {
        sqlite3_finalize(pointer)
    }
    
    var columnCount: Int {
        Int(sqlite3_column_count(pointer))
    }
    
    func columnName(at index: Int) -> String {
        String(cString: sqlite3_column_name(pointer, Int32(index)))
    }
}
