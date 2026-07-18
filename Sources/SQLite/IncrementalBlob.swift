//
//  IncrementalBlob.swift
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

/// Streams a single BLOB value's bytes in and out without loading the whole value into memory at once.
///
/// The target column must have been populated (e.g. via `.blob(.zero(_:))`) before opening a handle to it;
/// incremental I/O never changes the BLOB's length, only its content.
public struct IncrementalBlob: ~Copyable {

    let handle: Handle

    /// Opens an incremental I/O handle onto a BLOB value.
    ///
    /// - Parameters:
    ///   - table: Name of the table containing the BLOB.
    ///   - column: Name of the column containing the BLOB.
    ///   - row: `rowid` of the row containing the BLOB.
    ///   - database: Name of the attached database containing the table (`"main"` by default).
    ///   - writable: Whether the handle should permit writes in addition to reads.
    public init(
        connection: borrowing Connection,
        table: String,
        column: String,
        row: Int64,
        database: String = "main",
        writable: Bool = false
    ) throws(SQLiteError) {
        self.handle = try Handle.open(
            connection: connection.handle,
            database: database,
            table: table,
            column: column,
            row: row,
            writable: writable
        ).get()
    }

    deinit {
        handle.close()
    }
}

public extension IncrementalBlob {

    /// The size, in bytes, of the BLOB this handle was opened onto.
    var byteCount: Int32 {
        handle.byteCount
    }

    /// Reads `count` bytes starting at `offset` from the BLOB.
    func read(at offset: Int32 = 0, count: Int32) throws(SQLiteError) -> [UInt8] {
        try handle.read(at: offset, count: count).get()
    }

    /// Writes `bytes` into the BLOB starting at `offset`.
    ///
    /// The write must not extend past the BLOB's existing length; use a `.blob(.zero(_:))` binding
    /// of the desired final size to reserve space beforehand.
    func write(_ bytes: [UInt8], at offset: Int32 = 0) throws(SQLiteError) {
        try handle.write(bytes, at: offset).get()
    }

    /// Re-points this handle at a different row, avoiding the overhead of closing and reopening it.
    mutating func reopen(row: Int64) throws(SQLiteError) {
        try handle.reopen(row: row).get()
    }
}

// MARK: - Supporting Types

internal extension IncrementalBlob {

    struct Handle {

        let pointer: OpaquePointer

        let connection: Connection.Handle
    }
}

internal extension IncrementalBlob.Handle {

    static func open(
        connection: Connection.Handle,
        database: String,
        table: String,
        column: String,
        row: Int64,
        writable: Bool
    ) -> Result<IncrementalBlob.Handle, SQLiteError> {
        var pointer: OpaquePointer?
        let resultCode = sqlite3_blob_open(
            connection.pointer,
            database,
            table,
            column,
            row,
            writable ? 1 : 0,
            &pointer
        )
        guard let pointer else {
            return .failure(connection.forceError(SQLiteError.ErrorCode(resultCode)))
        }
        let handle = IncrementalBlob.Handle(pointer: pointer, connection: connection)
        guard resultCode == SQLITE_OK else {
            return .failure(connection.forceError(SQLiteError.ErrorCode(resultCode)))
        }
        return .success(handle)
    }

    consuming func close() {
        sqlite3_blob_close(pointer)
    }

    var byteCount: Int32 {
        sqlite3_blob_bytes(pointer)
    }

    func read(at offset: Int32, count: Int32) -> Result<[UInt8], SQLiteError> {
        var buffer = [UInt8](repeating: 0, count: Int(count))
        let resultCode = buffer.withUnsafeMutableBytes { rawBuffer in
            sqlite3_blob_read(pointer, rawBuffer.baseAddress, count, offset)
        }
        return connection.check(resultCode).map { buffer }
    }

    func write(_ bytes: [UInt8], at offset: Int32) -> Result<Void, SQLiteError> {
        let resultCode = bytes.withUnsafeBytes { rawBuffer in
            sqlite3_blob_write(pointer, rawBuffer.baseAddress, Int32(bytes.count), offset)
        }
        return connection.check(resultCode)
    }

    func reopen(row: Int64) -> Result<Void, SQLiteError> {
        connection.check(sqlite3_blob_reopen(pointer, row))
    }
}
