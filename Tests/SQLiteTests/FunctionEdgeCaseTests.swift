//
//  FunctionEdgeCaseTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

import Foundation
import Testing
@testable import SQLite

@Suite struct FunctionEdgeCaseTests {

    // MARK: - Scalar functions

    @Test func removeFunction() throws {
        let connection = try Connection(path: ":memory:")
        try connection.createFunction("twice", argumentCount: 1) { arguments in
            .integer((arguments[0].integer ?? 0) * 2)
        }
        #expect(try connection.scalar("SELECT twice(21)")?.integer == 42)
        try connection.removeFunction("twice", argumentCount: 1)
        #expect(throws: SQLiteError.self) {
            _ = try connection.scalar("SELECT twice(21)")
        }
    }

    @Test func functionReceivesEveryArgumentType() throws {
        let connection = try Connection(path: ":memory:")
        try connection.createFunction("kind", argumentCount: 1) { arguments in
            switch arguments[0] {
            case .null: return .text("null")
            case .integer: return .text("integer")
            case .double: return .text("double")
            case .text: return .text("text")
            case .blob(let blob):
                guard case let .blob(binding) = Binding.blob(blob), let bytes = Binding.blob(binding).bytes else {
                    return .text("blob")
                }
                return .text("blob(\(bytes.count))")
            }
        }
        #expect(try connection.scalar("SELECT kind(NULL)")?.string == "null")
        #expect(try connection.scalar("SELECT kind(1)")?.string == "integer")
        #expect(try connection.scalar("SELECT kind(1.5)")?.string == "double")
        #expect(try connection.scalar("SELECT kind('x')")?.string == "text")
        #expect(try connection.scalar("SELECT kind(X'CAFE')")?.string == "blob(2)")
        // a zero-length blob argument arrives as an empty blob
        #expect(try connection.scalar("SELECT kind(X'')")?.string == "blob(0)")
    }

    @Test func functionReturnsEveryResultType() throws {
        let connection = try Connection(path: ":memory:")
        try connection.createFunction("make_null", argumentCount: 0) { _ in .null }
        try connection.createFunction("make_blob", argumentCount: 0) { _ in
            Blob(bytes: [0xAB, 0xCD]).binding
        }
        try connection.createFunction("make_zeroblob", argumentCount: 0) { _ in .blob(.zero(2)) }
        #expect(try connection.scalar("SELECT make_null() IS NULL")?.integer == 1)
        #expect(try connection.scalar("SELECT hex(make_blob())")?.string == "ABCD")
        #expect(try connection.scalar("SELECT hex(make_zeroblob())")?.string == "0000")
    }

    @Test func scalarFunctionThrowsReportsErrorToCaller() throws {
        struct DivideByZero: Error, CustomStringConvertible {
            var description: String { "cannot divide by zero" }
        }
        let connection = try Connection(path: ":memory:")
        try connection.createFunction("safe_divide", argumentCount: 2) { arguments in
            let divisor = arguments[1].integer ?? 0
            guard divisor != 0 else { throw DivideByZero() }
            return .integer((arguments[0].integer ?? 0) / divisor)
        }
        #expect(try connection.scalar("SELECT safe_divide(10, 2)")?.integer == 5)
        do {
            _ = try connection.scalar("SELECT safe_divide(10, 0)")
            Issue.record("Expected safe_divide(10, 0) to throw")
        } catch {
            #expect(error.message == "cannot divide by zero")
        }
    }

    @Test func aggregateFunctionFinalThrowsReportsErrorToCaller() throws {
        struct EmptyGroup: Error, CustomStringConvertible {
            var description: String { "group must not be empty" }
        }
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (value INTEGER)")
        try connection.createAggregateFunction(
            "require_nonempty_sum",
            argumentCount: 1,
            initialState: { (Int64(0), false) },
            step: { state, arguments in
                state.0 += arguments[0].integer ?? 0
                state.1 = true
            },
            final: { state throws in
                guard state.1 else { throw EmptyGroup() }
                return .integer(state.0)
            }
        )
        try connection.run("INSERT INTO t (value) VALUES (5)")
        #expect(try connection.scalar("SELECT require_nonempty_sum(value) FROM t")?.integer == 5)
        do {
            _ = try connection.scalar("SELECT require_nonempty_sum(value) FROM t WHERE 0")
            Issue.record("Expected require_nonempty_sum over an empty group to throw")
        } catch {
            #expect(error.message == "group must not be empty")
        }
    }

    // MARK: - Collations

    @Test func removeCollation() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (value TEXT)")
        try connection.createCollation("REVERSE") { lhs, rhs in
            rhs == lhs ? 0 : (rhs < lhs ? -1 : 1)
        }
        try connection.run("SELECT value FROM t ORDER BY value COLLATE REVERSE")
        try connection.removeCollation("REVERSE")
        #expect(throws: SQLiteError.self) {
            try connection.run("SELECT value FROM t ORDER BY value COLLATE REVERSE")
        }
    }

    @Test func collationComparesEmptyStrings() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (value TEXT)")
        for value in ["b", "", "a"] {
            try connection.run("INSERT INTO t (value) VALUES (?)", [value.binding])
        }
        try connection.createCollation("SIMPLE") { lhs, rhs in
            lhs == rhs ? 0 : (lhs < rhs ? -1 : 1)
        }
        let statement = try connection.prepare("SELECT value FROM t ORDER BY value COLLATE SIMPLE")
        var results = [String]()
        while let row = try statement.failableNext() {
            results.append(row[0]?.string ?? "?")
        }
        #expect(results == ["", "a", "b"])
    }

    // MARK: - Window functions

    @Test
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, visionOS 1.0, *)
    func windowFunctionMovingFrameUsesInverse() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (position INTEGER, value INTEGER)")
        for (position, value) in [(1, 10), (2, 20), (3, 30)] {
            try connection.run("INSERT INTO t (position, value) VALUES (?, ?)", [position.binding, value.binding])
        }
        try connection.createWindowFunction(
            "moving_sum",
            argumentCount: 1,
            initialState: { Int64(0) },
            step: { state, arguments in state += arguments[0].integer ?? 0 },
            inverse: { state, arguments in state -= arguments[0].integer ?? 0 },
            value: { state in .integer(state) },
            final: { state in .integer(state) }
        )
        // a sliding two-row frame forces xInverse to evict rows leaving the window
        let statement = try connection.prepare(
            "SELECT moving_sum(value) OVER (ORDER BY position ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) FROM t ORDER BY position"
        )
        var results = [Int64]()
        while let row = try statement.failableNext() {
            results.append(row[0]?.integer ?? -1)
        }
        #expect(results == [10, 30, 50])
    }

    @Test
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, visionOS 1.0, *)
    func windowFunctionEmptyFrameUsesInitialState() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (position INTEGER, value INTEGER)")
        for (position, value) in [(1, 10), (2, 20)] {
            try connection.run("INSERT INTO t (position, value) VALUES (?, ?)", [position.binding, value.binding])
        }
        try connection.createWindowFunction(
            "frame_sum",
            argumentCount: 1,
            initialState: { Int64(0) },
            step: { state, arguments in state += arguments[0].integer ?? 0 },
            inverse: { state, arguments in state -= arguments[0].integer ?? 0 },
            value: { state in .integer(state) },
            final: { state in .integer(state) }
        )
        // the first row's frame (the preceding row only) is empty, so xValue
        // runs without any accumulated state
        let statement = try connection.prepare(
            "SELECT frame_sum(value) OVER (ORDER BY position ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING) FROM t ORDER BY position"
        )
        var results = [Int64]()
        while let row = try statement.failableNext() {
            results.append(row[0]?.integer ?? -1)
        }
        #expect(results == [0, 10])
    }

    // MARK: - Schema default values

    @Test func createTableWithDefaultValues() throws {
        let connection = try Connection(path: ":memory:")
        let schemaChanger = SchemaChanger(connection: connection)
        try schemaChanger.create(table: "settings") { table in
            table.add(column: ColumnDefinition(
                name: "id", primaryKey: .init(autoIncrement: true), type: .INTEGER,
                nullable: true, unique: false, defaultValue: .NULL, references: nil
            ))
            table.add(column: ColumnDefinition(
                name: "count", primaryKey: nil, type: .INTEGER,
                nullable: false, unique: false, defaultValue: .integer(7), references: nil
            ))
            table.add(column: ColumnDefinition(
                name: "ratio", primaryKey: nil, type: .REAL,
                nullable: false, unique: false, defaultValue: .double(2.5), references: nil
            ))
            table.add(column: ColumnDefinition(
                name: "owner", primaryKey: nil, type: .TEXT,
                nullable: false, unique: false, defaultValue: .text("O'Brien"), references: nil
            ))
        }
        try connection.run("INSERT INTO settings DEFAULT VALUES")
        #expect(try connection.scalar("SELECT count FROM settings")?.integer == 7)
        #expect(try connection.scalar("SELECT ratio FROM settings")?.double == 2.5)
        // the single quote survives SQL escaping in the DEFAULT clause
        #expect(try connection.scalar("SELECT owner FROM settings")?.string == "O'Brien")
    }

    // MARK: - Binding accessors

    @Test func bytesAccessorOnNonBlob() {
        #expect(Binding.null.bytes == nil)
        #expect(Binding.integer(1).bytes == nil)
        #expect(Binding.text("x").bytes == nil)
    }

    // MARK: - Registration failures

    // SQLite rejects functions with more arguments than SQLITE_MAX_FUNCTION_ARG,
    // whose compile-time ceiling is 32767 (the default varies by version: 127
    // for the system library, 1000 for newer embedded builds), exercising the
    // failure path of registration.

    @Test func createFunctionWithTooManyArguments() throws {
        let connection = try Connection(path: ":memory:")
        #expect(throws: SQLiteError.self) {
            try connection.createFunction("f", argumentCount: 32768) { _ in .null }
        }
    }

    @Test func createAggregateFunctionWithTooManyArguments() throws {
        let connection = try Connection(path: ":memory:")
        #expect(throws: SQLiteError.self) {
            try connection.createAggregateFunction(
                "f",
                argumentCount: 32768,
                initialState: { Int64(0) },
                step: { _, _ in },
                final: { _ in .null }
            )
        }
    }

    @Test
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, visionOS 1.0, *)
    func createWindowFunctionWithTooManyArguments() throws {
        let connection = try Connection(path: ":memory:")
        #expect(throws: SQLiteError.self) {
            try connection.createWindowFunction(
                "f",
                argumentCount: 32768,
                initialState: { Int64(0) },
                step: { _, _ in },
                inverse: { _, _ in },
                value: { _ in .null },
                final: { _ in .null }
            )
        }
    }

    @Test func nilSQLiteValueIsNull() {
        // SQLite never passes nil argument values, but the conversion tolerates it
        guard case .null = Binding(sqliteValue: nil) else {
            Issue.record("Expected .null for a nil sqlite3_value")
            return
        }
    }

    // MARK: - Error paths

    @Test func bindBeyondParameterCount() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (value INTEGER)")
        do {
            // one parameter in the SQL, two bindings: the second bind is out of range
            _ = try Statement.prepare(
                "INSERT INTO t (value) VALUES (?)",
                bindings: [.integer(1), .integer(2)],
                connection: connection
            )
            Issue.record("Expected out-of-range bind to fail")
        } catch {
            #expect(error.errorCode.rawValue == 25) // SQLITE_RANGE
        }
    }

    @Test func columnReadsReportConnectionErrors() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (i INTEGER, n TEXT)")
        try connection.run("INSERT INTO t (i, n) VALUES (42, NULL)")
        let statement = try Statement("SELECT i, n FROM t", connection: connection)
        #expect(try statement.handle.step(connection: connection.handle).get())
        // reading a NULL column as a blob yields no pointer and reports an error
        guard case .failure = statement.handle.readBlob(at: 1, connection: connection.handle) else {
            Issue.record("Expected readBlob of NULL column to fail")
            return
        }
        // a failed statement leaves an error code on the connection, which
        // subsequent column reads surface
        #expect(throws: SQLiteError.self) {
            _ = try Statement("SELECT * FROM missing_table", connection: connection)
        }
        let handle = statement.handle
        guard case .failure = handle.readText(at: 0, connection: connection.handle),
              case .failure = handle.readInteger(at: 0, connection: connection.handle),
              case .failure = handle.readDouble(at: 0, connection: connection.handle),
              case .failure = handle.readBlobSize(at: 0, connection: connection.handle) else {
            Issue.record("Expected column reads to surface the connection's error code")
            return
        }
    }

    @Test func blobReadReportsStaleConnectionError() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (b BLOB)")
        try connection.run("INSERT INTO t (b) VALUES (X'CAFE')")
        let statement = try Statement("SELECT b FROM t", connection: connection)
        #expect(try statement.handle.step(connection: connection.handle).get())
        // the column pointer is valid, but a stale connection error still surfaces
        #expect(throws: SQLiteError.self) {
            _ = try Statement("SELECT * FROM missing_table", connection: connection)
        }
        guard case .failure = statement.handle.readBlob(at: 0, connection: connection.handle) else {
            Issue.record("Expected blob read to surface the connection's error code")
            return
        }
    }
}
