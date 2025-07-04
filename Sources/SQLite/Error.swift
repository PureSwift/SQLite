//
//  Error.swift
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

public struct SQLiteError: Error {
    
    public let errorCode: CInt
}

internal extension CInt {
    
    func value() -> Result<Void, SQLiteError> {
        guard self == SQLITE_OK else {
            return .failure(SQLiteError(errorCode: self))
        }
        return .success(())
    }
}
