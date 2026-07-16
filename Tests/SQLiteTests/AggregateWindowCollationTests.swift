//
//  AggregateWindowCollationTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/16/26.
//

import Testing
@testable import SQLite

@Suite struct AggregateWindowCollationTests {

    @Test func aggregateFunctionSumsPerGroup() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (grp TEXT, value INTEGER)")
        try connection.run("INSERT INTO t (grp, value) VALUES (?, ?)", ["a".binding, 1.binding])
        try connection.run("INSERT INTO t (grp, value) VALUES (?, ?)", ["a".binding, 2.binding])
        try connection.run("INSERT INTO t (grp, value) VALUES (?, ?)", ["b".binding, 10.binding])

        try connection.createAggregateFunction(
            "my_sum",
            argumentCount: 1,
            initialState: { Int64(0) },
            step: { state, arguments in
                state += arguments[0].integer ?? 0
            },
            final: { state in .integer(state) }
        )

        let statement = try connection.prepare("SELECT grp, my_sum(value) FROM t GROUP BY grp ORDER BY grp")
        var results = [String: Int64]()
        while let row = try statement.failableNext() {
            results[row[0]?.string ?? ""] = row[1]?.integer
        }
        #expect(results == ["a": 3, "b": 10])
    }

    @Test func aggregateFunctionOnEmptyGroupUsesInitialState() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (value INTEGER)")

        try connection.createAggregateFunction(
            "my_sum",
            argumentCount: 1,
            initialState: { Int64(0) },
            step: { state, arguments in
                state += arguments[0].integer ?? 0
            },
            final: { state in .integer(state) }
        )

        #expect(try connection.scalar("SELECT my_sum(value) FROM t")?.integer == 0)
    }

    @Test func windowFunctionComputesRunningTotal() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (position INTEGER, value INTEGER)")
        for (position, value) in [(1, 10), (2, 20), (3, 30)] {
            try connection.run("INSERT INTO t (position, value) VALUES (?, ?)", [Int64(position).binding, Int64(value).binding])
        }

        try connection.createWindowFunction(
            "running_sum",
            argumentCount: 1,
            initialState: { Int64(0) },
            step: { state, arguments in state += arguments[0].integer ?? 0 },
            inverse: { state, arguments in state -= arguments[0].integer ?? 0 },
            value: { state in .integer(state) },
            final: { state in .integer(state) }
        )

        let statement = try connection.prepare(
            "SELECT position, running_sum(value) OVER (ORDER BY position ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) FROM t ORDER BY position"
        )
        var results = [Int64]()
        while let row = try statement.failableNext() {
            results.append(row[1]?.integer ?? -1)
        }
        #expect(results == [10, 30, 60])
    }

    @Test func createCollationReversesOrdering() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (value TEXT)")
        try connection.run("INSERT INTO t (value) VALUES (?)", ["a".binding])
        try connection.run("INSERT INTO t (value) VALUES (?)", ["b".binding])
        try connection.run("INSERT INTO t (value) VALUES (?)", ["c".binding])

        try connection.createCollation("REVERSE") { lhs, rhs in
            rhs == lhs ? 0 : (rhs < lhs ? -1 : 1)
        }

        let statement = try connection.prepare("SELECT value FROM t ORDER BY value COLLATE REVERSE")
        var results = [String]()
        while let row = try statement.failableNext() {
            results.append(row[0]?.string ?? "")
        }
        #expect(results == ["c", "b", "a"])
    }
}
