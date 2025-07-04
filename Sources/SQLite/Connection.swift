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
    
    public init(path: String) throws(SQLiteError) {
        self.handle = try Handle(path: path)
    }
    
    deinit {
        handle.close()
    }
}

public extension Connection {
    
    static var isThreadSafe: Bool {
        sqlite3_threadsafe() != 0
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
    
    init(path: String) throws(SQLiteError) {
        fatalError()
    }
}
