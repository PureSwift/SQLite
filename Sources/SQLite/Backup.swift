//
//  Backup.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
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

/// Copies the contents of one database connection to another, optionally in incremental steps.
///
/// See: <https://www.sqlite.org/backup.html>
public struct Backup: ~Copyable {

    let handle: Handle

    /// Initializes a backup of `source` into `destination`.
    ///
    /// - Parameters:
    ///   - source: Connection to copy from.
    ///   - sourceDatabase: Name of the attached database to copy from (`"main"` by default).
    ///   - destination: Connection to copy into.
    ///   - destinationDatabase: Name of the attached database to copy into (`"main"` by default).
    public init(
        source: borrowing Connection,
        sourceDatabase: String = "main",
        destination: borrowing Connection,
        destinationDatabase: String = "main"
    ) throws(SQLiteError) {
        self.handle = try Handle.open(
            source: source.handle,
            sourceDatabase: sourceDatabase,
            destination: destination.handle,
            destinationDatabase: destinationDatabase
        ).get()
    }

    deinit {
        handle.finish()
    }
}

public extension Backup {

    /// The number of pages still to be copied as of the most recent call to `step(pageCount:)`.
    var remainingPageCount: Int32 {
        handle.remainingPageCount
    }

    /// The total number of pages in the source database as of the most recent call to `step(pageCount:)`.
    var totalPageCount: Int32 {
        handle.totalPageCount
    }

    /// Copies up to `pageCount` pages from the source to the destination database.
    ///
    /// - Parameter pageCount: The number of pages to copy, or a negative value to copy every remaining page.
    /// - Returns: `true` if there are more pages left to copy, `false` if the backup is complete.
    mutating func step(pageCount: Int32 = -1) throws(SQLiteError) -> Bool {
        try handle.step(pageCount: pageCount).get()
    }
}

// MARK: - Supporting Types

internal extension Backup {

    struct Handle {

        let pointer: OpaquePointer

        let destination: Connection.Handle
    }
}

internal extension Backup.Handle {

    static func open(
        source: Connection.Handle,
        sourceDatabase: String,
        destination: Connection.Handle,
        destinationDatabase: String
    ) -> Result<Backup.Handle, SQLiteError> {
        guard let pointer = sqlite3_backup_init(
            destination.pointer,
            destinationDatabase,
            source.pointer,
            sourceDatabase
        ) else {
            return .failure(destination.forceError(destination.errorCode ?? .init(SQLITE_ERROR)))
        }
        return .success(Backup.Handle(pointer: pointer, destination: destination))
    }

    consuming func finish() {
        sqlite3_backup_finish(pointer)
    }

    var remainingPageCount: Int32 {
        sqlite3_backup_remaining(pointer)
    }

    var totalPageCount: Int32 {
        sqlite3_backup_pagecount(pointer)
    }

    func step(pageCount: Int32) -> Result<Bool, SQLiteError> {
        let resultCode = sqlite3_backup_step(pointer, pageCount)
        if resultCode == SQLITE_DONE {
            return .success(false)
        }
        if resultCode == SQLITE_OK {
            return .success(true)
        }
        return .failure(destination.forceError(SQLiteError.ErrorCode(resultCode)))
    }
}
