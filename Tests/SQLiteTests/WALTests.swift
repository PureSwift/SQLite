//
//  WALTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

import Foundation
import Testing
@testable import SQLite

@Suite struct WALTests {

    @Test func enableWALModeOnFileBackedConnection() throws {
        let path = NSTemporaryDirectory() + "wal-\(UUID().uuidString).sqlite"
        defer {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: path + "-wal")
            try? FileManager.default.removeItem(atPath: path + "-shm")
        }
        let connection = try Connection(path: path)
        let applied = try connection.setJournalMode(.wal)
        #expect(applied == .wal)
        let current = try connection.journalMode
        #expect(current == .wal)
    }

    @Test func inMemoryDatabaseCannotEnterWALMode() throws {
        // WAL mode is unsupported for in-memory databases; SQLite silently keeps "memory" instead
        let connection = try Connection(path: ":memory:")
        let applied = try connection.setJournalMode(.wal)
        #expect(applied == .memory)
    }

    @Test func checkpointReportsFrameCounts() throws {
        let path = NSTemporaryDirectory() + "wal-checkpoint-\(UUID().uuidString).sqlite"
        defer {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: path + "-wal")
            try? FileManager.default.removeItem(atPath: path + "-shm")
        }
        let connection = try Connection(path: path)
        _ = try connection.setJournalMode(.wal)
        try connection.run("CREATE TABLE t (value INTEGER)")
        try connection.run("INSERT INTO t (value) VALUES (1)")

        let (logFrameCount, checkpointedFrameCount) = try connection.walCheckpoint(mode: .truncate)
        #expect(logFrameCount >= 0)
        #expect(checkpointedFrameCount >= 0)
        #expect(checkpointedFrameCount <= logFrameCount)
    }

    @Test func setWALAutoCheckpointDoesNotThrow() throws {
        let connection = try Connection(path: ":memory:")
        try connection.setWALAutoCheckpoint(pageCount: 1000)
        try connection.setWALAutoCheckpoint(pageCount: 0) // disables auto-checkpointing
    }
}
