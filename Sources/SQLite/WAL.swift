//
//  WAL.swift
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

public extension Connection {

    /// Enables or disables [write-ahead logging](https://www.sqlite.org/wal.html) for this connection.
    ///
    /// There is no dedicated C API for changing the journal mode; this issues `PRAGMA journal_mode`
    /// and reports back the mode SQLite actually applied (WAL mode cannot be entered for in-memory
    /// or temporary databases, for example).
    @discardableResult
    func setJournalMode(_ mode: JournalMode) throws(SQLiteError) -> JournalMode {
        guard let rawValue = try scalar("PRAGMA journal_mode = \(mode.rawValue)")?.string,
              let appliedMode = JournalMode(rawValue: rawValue.lowercased()) else {
            return try journalMode
        }
        return appliedMode
    }

    /// The connection's current journal mode.
    var journalMode: JournalMode {
        get throws(SQLiteError) {
            guard let rawValue = try scalar("PRAGMA journal_mode")?.string,
                  let mode = JournalMode(rawValue: rawValue.lowercased()) else {
                return .delete
            }
            return mode
        }
    }

    /// Checkpoints the write-ahead log, copying its contents back into the main database file.
    ///
    /// - Parameters:
    ///   - mode: How aggressively to checkpoint; see `Connection.CheckpointMode`.
    ///   - database: Name of the attached database to checkpoint, or `nil` for all attached databases.
    /// - Returns: The WAL's size in frames, and how many of those frames were checkpointed.
    @discardableResult
    func walCheckpoint(
        mode: CheckpointMode = .passive,
        database: String? = nil
    ) throws(SQLiteError) -> (logFrameCount: Int32, checkpointedFrameCount: Int32) {
        try handle.walCheckpoint(mode: mode, database: database).get()
    }

    /// Configures the WAL auto-checkpoint threshold: the write-ahead log is checkpointed automatically
    /// once it grows past `pageCount` pages. Pass `0` to disable automatic checkpointing.
    func setWALAutoCheckpoint(pageCount: Int32) throws(SQLiteError) {
        try handle.setWALAutoCheckpoint(pageCount: pageCount).get()
    }
}

// MARK: - Supporting Types

public extension Connection {

    /// A SQLite [journal mode](https://www.sqlite.org/pragma.html#pragma_journal_mode).
    enum JournalMode: String, Equatable, Hashable, Sendable {

        case delete
        case truncate
        case persist
        case memory
        case wal
        case off
    }

    /// A [checkpoint mode](https://www.sqlite.org/c3ref/wal_checkpoint_v2.html) for `walCheckpoint(mode:database:)`.
    enum CheckpointMode: Int32, Equatable, Hashable, Sendable {

        /// Checkpoints as many frames as possible without blocking readers or writers.
        case passive = 0 // SQLITE_CHECKPOINT_PASSIVE

        /// Blocks until all writers are done, then checkpoints.
        case full = 1 // SQLITE_CHECKPOINT_FULL

        /// Like `.full`, but also blocks until all readers are done, so the log can be reset.
        case restart = 2 // SQLITE_CHECKPOINT_RESTART

        /// Like `.restart`, and additionally truncates the WAL file to zero bytes on completion.
        case truncate = 3 // SQLITE_CHECKPOINT_TRUNCATE
    }
}

internal extension Connection.Handle {

    func walCheckpoint(
        mode: Connection.CheckpointMode,
        database: String?
    ) -> Result<(logFrameCount: Int32, checkpointedFrameCount: Int32), SQLiteError> {
        var logFrameCount: Int32 = 0
        var checkpointedFrameCount: Int32 = 0
        let resultCode = sqlite3_wal_checkpoint_v2(
            pointer,
            database,
            mode.rawValue,
            &logFrameCount,
            &checkpointedFrameCount
        )
        return check(resultCode).map { (logFrameCount, checkpointedFrameCount) }
    }

    func setWALAutoCheckpoint(pageCount: Int32) -> Result<Void, SQLiteError> {
        let resultCode = sqlite3_wal_autocheckpoint(pointer, pageCount)
        return check(resultCode)
    }
}
