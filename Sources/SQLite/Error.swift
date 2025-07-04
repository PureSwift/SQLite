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

/// SQLite Error
public struct SQLiteError: Error {
    
    public let errorCode: ErrorCode
    
    public let message: String
    
    public let connection: String
    
    public let file: StaticString
    
    public let function: StaticString
    
    internal init(
        errorCode: ErrorCode,
        message: String,
        connection: String,
        file: StaticString = #file,
        function: StaticString = #function
    ) {
        self.errorCode = errorCode
        self.message = message
        self.file = file
        self.function = function
        self.connection = connection
    }
}

// MARK: - Supporting Types

public extension SQLiteError {
    
    /// Represents a SQLite specific [error code](https://sqlite.org/rescode.html)
    ///
    /// - rawValue: SQLite [error code](https://sqlite.org/rescode.html#primary_result_code_list)
    struct ErrorCode: RawRepresentable, Equatable, Hashable, Sendable {
        
        public let rawValue: CInt
        
        public init?(rawValue: CInt) {
            guard Self.isValid(rawValue) else {
                return nil
            }
            self.init(rawValue)
        }
        
        internal init(_ raw: CInt) {
            assert(Self.isValid(raw))
            self.rawValue = raw
        }
    }
}

internal extension SQLiteError.ErrorCode {
    
    static let successCodes: Set<SQLiteError.ErrorCode.RawValue> = [SQLITE_OK, SQLITE_ROW, SQLITE_DONE]
    
    static func isValid(_ rawValue: RawValue) -> Bool {
        Self.successCodes.contains(rawValue) == false
    }
}
