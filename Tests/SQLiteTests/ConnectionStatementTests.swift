//
//  ConnectionStatementTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

import Foundation
import Testing
@testable import SQLite

@Suite struct ConnectionStatementTests {

    // MARK: - Connection properties

    @Test func threadSafety() {
        // the connection is opened with SQLITE_OPEN_FULLMUTEX
        #expect(Connection.isThreadSafe)
    }

    @Test func readOnlyState() throws {
        let path = NSTemporaryDirectory() + "readonly-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }
        do {
            let connection = try Connection(path: path)
            #expect(connection.isReadonly == false)
            try connection.run("CREATE TABLE t (value INTEGER)")
        }
        let connection = try Connection(path: path, isReadOnly: true)
        let isReadonly = connection.isReadonly
        #expect(isReadonly)
    }

    @Test func changeCounters() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (id INTEGER PRIMARY KEY, value TEXT)")
        try connection.run("INSERT INTO t (value) VALUES ('a')")
        #expect(connection.lastInsertRowID == 1)
        #expect(connection.changes == 1)
        try connection.run("INSERT INTO t (value) VALUES ('b')")
        try connection.run("INSERT INTO t (value) VALUES ('c')")
        #expect(connection.lastInsertRowID == 3)
        try connection.run("UPDATE t SET value = 'z'")
        #expect(connection.changes == 3)
        #expect(connection.totalChanges == 6)
    }

    @Test func extendedErrorCodes() throws {
        var connection = try Connection(path: ":memory:")
        connection.usesExtendedErrorCodes = true
        let isEnabled = connection.usesExtendedErrorCodes
        #expect(isEnabled)
        try connection.run("CREATE TABLE t (id INTEGER PRIMARY KEY, value TEXT UNIQUE)")
        try connection.run("INSERT INTO t (value) VALUES ('a')")
        do {
            try connection.run("INSERT INTO t (value) VALUES ('a')")
            Issue.record("Expected unique constraint violation")
        } catch {
            // SQLITE_CONSTRAINT_UNIQUE (2067) rather than the primary SQLITE_CONSTRAINT (19)
            #expect(error.errorCode.rawValue == 2067)
        }
        connection.usesExtendedErrorCodes = false
        let isDisabled = connection.usesExtendedErrorCodes == false
        #expect(isDisabled)
    }

    // MARK: - execute

    @Test func executeStopsAtLimit() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (value INTEGER)")
        for value in 1...5 {
            try connection.run("INSERT INTO t (value) VALUES (?)", [value.binding])
        }
        var unlimited = 0
        try connection.execute(try Statement("SELECT value FROM t", connection: connection)) { row in
            unlimited += 1
        }
        #expect(unlimited == 5)
        // the limit check runs after the block, so limit N yields N + 1 rows
        var limited = 0
        try connection.execute(try Statement("SELECT value FROM t", connection: connection), limit: 2) { row in
            limited += 1
        }
        #expect(limited == 3)
    }

    // MARK: - Statement

    @Test func statementProperties() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (a INTEGER, b TEXT)")
        let sql = "SELECT a, b FROM t"
        let statement = try Statement(sql, connection: connection)
        #expect(statement.sql == sql)
        #expect(statement.columnCount == 2)
        #expect(statement.columnName(at: 0) == "a")
        #expect(statement.columnName(at: 1) == "b")
        let update = try Statement("DELETE FROM t", connection: connection)
        #expect(update.columnCount == 0)
    }

    @Test func prepareWithBindings() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (i INTEGER, d REAL, s TEXT, b BLOB, z BLOB, n TEXT)")
        // every Binding case: integer, double, text, pointer blob, zero blob, null
        let statement = try Statement.prepare(
            "INSERT INTO t (i, d, s, b, z, n) VALUES (?, ?, ?, ?, ?, ?)",
            bindings: [
                .integer(42),
                .double(1.5),
                .text("value"),
                Blob(bytes: [0xCA, 0xFE]).binding,
                .blob(.zero(4)),
                .null
            ],
            connection: connection
        )
        try connection.execute(statement) { _ in }
        #expect(try connection.scalar("SELECT i FROM t")?.integer == 42)
        #expect(try connection.scalar("SELECT d FROM t")?.double == 1.5)
        #expect(try connection.scalar("SELECT s FROM t")?.string == "value")
        #expect(try connection.scalar("SELECT hex(b) FROM t")?.string == "CAFE")
        #expect(try connection.scalar("SELECT hex(z) FROM t")?.string == "00000000")
        #expect(try connection.scalar("SELECT n IS NULL FROM t")?.integer == 1)
    }

    @Test func stepError() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (value TEXT UNIQUE)")
        try connection.run("INSERT INTO t (value) VALUES ('a')")
        do {
            // fails at step, not prepare
            try connection.run("INSERT INTO t (value) VALUES ('a')")
            Issue.record("Expected unique constraint violation")
        } catch {
            #expect(error.errorCode.rawValue == 19) // SQLITE_CONSTRAINT
            #expect(error.statement == "INSERT INTO t (value) VALUES ('a')")
        }
    }

    @Test func writeToReadOnlyConnection() throws {
        let path = NSTemporaryDirectory() + "readonly-write-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }
        do {
            let connection = try Connection(path: path)
            try connection.run("CREATE TABLE t (value INTEGER)")
        }
        let connection = try Connection(path: path, isReadOnly: true)
        #expect(throws: SQLiteError.self) {
            try connection.run("INSERT INTO t (value) VALUES (1)")
        }
    }
}
