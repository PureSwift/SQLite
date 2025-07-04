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
    
    let handle: OpaquePointer
    
    init(handle: OpaquePointer) {
        self.handle = handle
    }
    
    deinit {
        sqlite3_close(handle)
    }
}

public extension Connection {
    
    static var isThreadSafe: Bool {
        sqlite3_threadsafe() != 0
    }
}
