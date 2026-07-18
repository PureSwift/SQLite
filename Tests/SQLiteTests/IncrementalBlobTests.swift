//
//  IncrementalBlobTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

import Testing
@testable import SQLite

@Suite struct IncrementalBlobTests {

    @Test func readWholeBlob() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (id INTEGER PRIMARY KEY, value BLOB)")
        try connection.run("INSERT INTO t (id, value) VALUES (1, ?)", [Blob(bytes: [0xCA, 0xFE, 0xF0, 0x0D]).binding])
        let blob = try IncrementalBlob(connection: connection, table: "t", column: "value", row: 1)
        #expect(blob.byteCount == 4)
        #expect(try blob.read(count: 4) == [0xCA, 0xFE, 0xF0, 0x0D])
    }

    @Test func readPartialRange() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (id INTEGER PRIMARY KEY, value BLOB)")
        try connection.run("INSERT INTO t (id, value) VALUES (1, ?)", [Blob(bytes: [0, 1, 2, 3, 4, 5]).binding])
        let blob = try IncrementalBlob(connection: connection, table: "t", column: "value", row: 1)
        #expect(try blob.read(at: 2, count: 3) == [2, 3, 4])
    }

    @Test func writeUpdatesUnderlyingColumn() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (id INTEGER PRIMARY KEY, value BLOB)")
        // reserve a fixed-size placeholder; incremental writes never change a BLOB's length
        try connection.run("INSERT INTO t (id, value) VALUES (1, ?)", [.blob(.zero(4))])
        let blob = try IncrementalBlob(connection: connection, table: "t", column: "value", row: 1, writable: true)
        try blob.write([0xDE, 0xAD, 0xBE, 0xEF])
        #expect(try connection.scalar("SELECT hex(value) FROM t")?.string == "DEADBEEF")
    }

    @Test func writeToReadOnlyHandleFails() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (id INTEGER PRIMARY KEY, value BLOB)")
        try connection.run("INSERT INTO t (id, value) VALUES (1, ?)", [.blob(.zero(4))])
        let blob = try IncrementalBlob(connection: connection, table: "t", column: "value", row: 1, writable: false)
        #expect(throws: SQLiteError.self) {
            try blob.write([0xDE, 0xAD, 0xBE, 0xEF])
        }
    }

    @Test func reopenPointsAtDifferentRow() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (id INTEGER PRIMARY KEY, value BLOB)")
        try connection.run("INSERT INTO t (id, value) VALUES (1, ?)", [Blob(bytes: [1, 1, 1, 1]).binding])
        try connection.run("INSERT INTO t (id, value) VALUES (2, ?)", [Blob(bytes: [2, 2, 2, 2]).binding])
        var blob = try IncrementalBlob(connection: connection, table: "t", column: "value", row: 1)
        #expect(try blob.read(count: 4) == [1, 1, 1, 1])
        try blob.reopen(row: 2)
        #expect(try blob.read(count: 4) == [2, 2, 2, 2])
    }

    @Test func openOnMissingRowFails() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (id INTEGER PRIMARY KEY, value BLOB)")
        #expect(throws: SQLiteError.self) {
            _ = try IncrementalBlob(connection: connection, table: "t", column: "value", row: 999)
        }
    }
}
