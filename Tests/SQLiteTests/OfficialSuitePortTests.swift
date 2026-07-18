//
//  OfficialSuitePortTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//
//  Ports of representative cases from SQLite's official TCL test suite
//  (https://sqlite.org/testing.html). Each test cites the original test file
//  and case numbers (e.g. select1-1.4) from sqlite/test/*.test.
//

import Foundation
import Testing
@testable import SQLite

/// A Swift stand-in for the TCL test harness's `execsql` / `catchsql` commands.
///
/// Like `execsql`, `run(_:)` executes a script and returns all result rows
/// flattened into a single list of strings, with NULL rendered as the empty
/// string and blobs rendered as uppercase hex.
struct TCLHarness: ~Copyable {

    let connection: Connection

    init() throws(SQLiteError) {
        self.connection = try Connection(path: ":memory:")
    }

    /// Executes each statement of the script and returns the flattened results.
    ///
    /// Statements are split on `;`, so scripts must not embed semicolons in
    /// string literals — the ported tests don't.
    @discardableResult
    func run(_ script: String) throws(SQLiteError) -> [String] {
        var results = [String]()
        for sql in script.split(separator: ";") {
            let sql = sql.trimmingCharacters(in: .whitespacesAndNewlines)
            guard sql.isEmpty == false else { continue }
            let statement = try connection.prepare(sql)
            while let row = try statement.failableNext() {
                for value in row {
                    if let string = value?.string {
                        results.append(string)
                    } else if let bytes = value?.bytes {
                        results.append(bytes.map { String(format: "%02X", $0) }.joined())
                    } else {
                        results.append("") // TCL renders NULL as the empty string
                    }
                }
            }
        }
        return results
    }

    /// Like TCL's `catchsql`: expects the script to fail and returns the error message.
    func errorMessage(_ script: String) -> String? {
        do {
            _ = try run(script)
            return nil
        } catch {
            return error.message
        }
    }
}

@Suite struct OfficialSuitePortTests {

    // MARK: - select1.test

    @Test func select1() throws {
        let db = try TCLHarness()
        // select1-1.1: querying a table before it exists is an error
        let missingTable = db.errorMessage("SELECT f1 FROM test1")
        #expect(missingTable?.contains("no such table") == true)
        try db.run("CREATE TABLE test1(f1 int, f2 int); INSERT INTO test1(f1,f2) VALUES(11,22)")
        // select1-1.4
        #expect(try db.run("SELECT f1 FROM test1") == ["11"])
        // select1-1.7
        #expect(try db.run("SELECT f2 FROM test1") == ["22"])
        // select1-1.8
        #expect(try db.run("SELECT * FROM test1") == ["11", "22"])
        try db.run("INSERT INTO test1(f1,f2) VALUES(33,44)")
        // select1-1.11.1
        #expect(try db.run("SELECT * FROM test1 ORDER BY f1") == ["11", "22", "33", "44"])
        // select1-1.12
        #expect(try db.run("SELECT f1 FROM test1 WHERE f2==44") == ["33"])
        // select1-2.x aggregates
        #expect(try db.run("SELECT count(*) FROM test1") == ["2"])
        #expect(try db.run("SELECT min(f1) FROM test1") == ["11"])
        #expect(try db.run("SELECT max(f1)+1 FROM test1") == ["34"])
        #expect(try db.run("SELECT sum(f1) FROM test1") == ["44"])
        #expect(try db.run("SELECT avg(f1) FROM test1") == ["22.0"])
        // select1-4.5: ordering by a nonexistent column is an error
        let missingColumn = db.errorMessage("SELECT f1 FROM test1 ORDER BY f3")
        #expect(missingColumn?.contains("no such column") == true)
        // select1-6.9.x: DISTINCT
        try db.run("INSERT INTO test1(f1,f2) VALUES(11,22)")
        #expect(try db.run("SELECT DISTINCT f1 FROM test1 ORDER BY f1") == ["11", "33"])
        // select1-12.x: LIMIT and OFFSET
        #expect(try db.run("SELECT f1 FROM test1 ORDER BY f1 LIMIT 2 OFFSET 1") == ["11", "33"])
    }

    // MARK: - null.test

    @Test func nullHandling() throws {
        let db = try TCLHarness()
        // the table from null.test's setup, rows 1-7
        try db.run("""
            CREATE TABLE t1(a int, b int, c int);
            INSERT INTO t1 VALUES(1,0,0);
            INSERT INTO t1 VALUES(2,0,1);
            INSERT INTO t1 VALUES(3,1,0);
            INSERT INTO t1 VALUES(4,1,1);
            INSERT INTO t1 VALUES(5,null,0);
            INSERT INTO t1 VALUES(6,null,1);
            INSERT INTO t1 VALUES(7,null,null)
            """)
        // null-1.4: count(*) counts NULL rows, count(column) does not
        #expect(try db.run("SELECT count(*), count(b) FROM t1") == ["7", "4"])
        // null-2.1: NULLs are excluded by any comparison
        #expect(try db.run("SELECT a FROM t1 WHERE b < 10 ORDER BY a") == ["1", "2", "3", "4"])
        #expect(try db.run("SELECT a FROM t1 WHERE b IS NULL ORDER BY a") == ["5", "6", "7"])
        // null-3.x: three-valued logic
        #expect(try db.run("SELECT null AND 0") == ["0"])
        #expect(try db.run("SELECT null AND 1") == [""])
        #expect(try db.run("SELECT null OR 1") == ["1"])
        #expect(try db.run("SELECT null OR 0") == [""])
        // null-4.1: NULL never equals NULL
        #expect(try db.run("SELECT 1 WHERE NULL = NULL") == [])
        #expect(try db.run("SELECT NULL IS NULL") == ["1"])
        // null-5.x: DISTINCT treats NULLs as equal
        #expect(try db.run("SELECT count(DISTINCT b) FROM t1") == ["2"])
        // null-6.x: NULLs sort first by default
        #expect(try db.run("SELECT b FROM t1 ORDER BY b LIMIT 3") == ["", "", ""])
    }

    // MARK: - types.test

    @Test func storageClassesAndAffinity() throws {
        let db = try TCLHarness()
        // types-1.x: typeof() literals
        #expect(try db.run("SELECT typeof(1)") == ["integer"])
        #expect(try db.run("SELECT typeof(1.0)") == ["real"])
        #expect(try db.run("SELECT typeof('x')") == ["text"])
        #expect(try db.run("SELECT typeof(NULL)") == ["null"])
        #expect(try db.run("SELECT typeof(X'AB')") == ["blob"])
        // types-1.1.x: column affinity converts well-formed literals on insert
        try db.run("""
            CREATE TABLE t1(i INTEGER, r REAL, t TEXT, n NUMERIC);
            INSERT INTO t1 VALUES('500', 500, 500, '500.0')
            """)
        #expect(try db.run("SELECT typeof(i), typeof(r), typeof(t), typeof(n) FROM t1")
            == ["integer", "real", "text", "integer"])
        // text that is not a well-formed number is stored as text despite affinity
        try db.run("DELETE FROM t1; INSERT INTO t1 VALUES('abc', 'abc', 'abc', 'abc')")
        #expect(try db.run("SELECT typeof(i), typeof(r), typeof(t), typeof(n) FROM t1")
            == ["text", "text", "text", "text"])
        // types-2.1.x: integer range round-trip including 64-bit boundaries
        try db.run("CREATE TABLE t2(x INTEGER)")
        for value in ["0", "1", "-1", "9223372036854775807", "-9223372036854775808"] {
            try db.run("DELETE FROM t2; INSERT INTO t2 VALUES(\(value))")
            #expect(try db.run("SELECT x FROM t2") == [value])
        }
    }

    // MARK: - expr.test

    @Test func expressions() throws {
        let db = try TCLHarness()
        // expr-1.x: arithmetic operators and precedence
        #expect(try db.run("SELECT 1+2.3") == ["3.3"])
        #expect(try db.run("SELECT 6/4") == ["1"]) // integer division truncates
        #expect(try db.run("SELECT 6.0/4") == ["1.5"])
        #expect(try db.run("SELECT 5%3") == ["2"])
        #expect(try db.run("SELECT 2+3*4") == ["14"])
        // expr-1.x: bitwise operators
        #expect(try db.run("SELECT 4<<1, 4>>1, 6&3, 6|3, ~0") == ["8", "2", "2", "7", "-1"])
        // expr-4.x: string concatenation
        #expect(try db.run("SELECT 'a' || 'b'") == ["ab"])
        // expr-5.x: LIKE is case-insensitive for ASCII, GLOB is case-sensitive
        #expect(try db.run("SELECT 'abc' LIKE 'ABC'") == ["1"])
        #expect(try db.run("SELECT 'abc' LIKE 'ab%'") == ["1"])
        #expect(try db.run("SELECT 'abc' GLOB 'ABC'") == ["0"])
        #expect(try db.run("SELECT 'abc' GLOB 'ab*'") == ["1"])
        // expr-8.x: CASE expressions
        #expect(try db.run("SELECT CASE WHEN 1>0 THEN 'yes' ELSE 'no' END") == ["yes"])
        #expect(try db.run("SELECT CASE 2 WHEN 1 THEN 'one' WHEN 2 THEN 'two' END") == ["two"])
        // expr-10.x: CAST
        #expect(try db.run("SELECT CAST('123abc' AS INTEGER)") == ["123"])
        #expect(try db.run("SELECT CAST(4.6 AS INTEGER)") == ["4"]) // truncates toward zero
        #expect(try db.run("SELECT typeof(CAST(1 AS TEXT))") == ["text"])
        // expr-11.x: BETWEEN and IN
        #expect(try db.run("SELECT 5 BETWEEN 1 AND 10") == ["1"])
        #expect(try db.run("SELECT 3 IN (1,2,3)") == ["1"])
    }

    // MARK: - insert.test / delete.test / update.test

    @Test func insertDeleteUpdate() throws {
        let db = try TCLHarness()
        // insert-1.1: inserting into a nonexistent table is an error
        let missingTable = db.errorMessage("INSERT INTO test1 VALUES(1)")
        #expect(missingTable?.contains("no such table") == true)
        try db.run("CREATE TABLE test1(one int, two text)")
        // insert-1.3-ish: column order can be permuted
        try db.run("INSERT INTO test1(two, one) VALUES('hello', 1)")
        #expect(try db.run("SELECT one, two FROM test1") == ["1", "hello"])
        // insert-2.x: INSERT INTO ... SELECT
        try db.run("""
            CREATE TABLE test2(one int, two text);
            INSERT INTO test2 SELECT one+1, two FROM test1
            """)
        #expect(try db.run("SELECT one, two FROM test2") == ["2", "hello"])
        // too many values is an error
        let tooManyValues = db.errorMessage("INSERT INTO test1 VALUES(1, 'x', 3)")
        #expect(tooManyValues?.contains("values") == true)
        // delete-3.x: DELETE with a WHERE clause
        try db.run("""
            CREATE TABLE t3(a int);
            INSERT INTO t3 VALUES(1);
            INSERT INTO t3 VALUES(2);
            INSERT INTO t3 VALUES(3);
            INSERT INTO t3 VALUES(4)
            """)
        try db.run("DELETE FROM t3 WHERE a % 2 == 0")
        #expect(try db.run("SELECT a FROM t3 ORDER BY a") == ["1", "3"])
        // update-3.x: UPDATE with expressions and WHERE
        try db.run("UPDATE t3 SET a = a * 10 WHERE a > 1")
        #expect(try db.run("SELECT a FROM t3 ORDER BY a") == ["1", "30"])
        // delete-1.x: DELETE without WHERE empties the table
        try db.run("DELETE FROM t3")
        #expect(try db.run("SELECT count(*) FROM t3") == ["0"])
    }

    // MARK: - collate1.test

    @Test func builtInCollations() throws {
        let db = try TCLHarness()
        try db.run("""
            CREATE TABLE t1(a TEXT COLLATE NOCASE);
            INSERT INTO t1 VALUES('aaa');
            INSERT INTO t1 VALUES('BBB');
            INSERT INTO t1 VALUES('ccc')
            """)
        // collate1-1.x: NOCASE ignores ASCII case in ordering and comparison
        #expect(try db.run("SELECT a FROM t1 ORDER BY a") == ["aaa", "BBB", "ccc"])
        #expect(try db.run("SELECT a FROM t1 WHERE a = 'AAA'") == ["aaa"])
        // BINARY is case-sensitive: uppercase sorts before lowercase
        #expect(try db.run("SELECT a FROM t1 ORDER BY a COLLATE BINARY") == ["BBB", "aaa", "ccc"])
        #expect(try db.run("SELECT a FROM t1 WHERE a = 'AAA' COLLATE BINARY") == [])
    }
}
