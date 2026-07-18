//
//  BackupTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

import Testing
@testable import SQLite

@Suite struct BackupTests {

    @Test func backupCopiesAllPagesInOneStep() throws {
        let source = try Connection(path: ":memory:")
        try source.run("CREATE TABLE t (value TEXT)")
        try source.run("INSERT INTO t (value) VALUES ('a')")
        try source.run("INSERT INTO t (value) VALUES ('b')")

        let destination = try Connection(path: ":memory:")
        var backup = try Backup(source: source, destination: destination)
        #expect(try backup.step() == false) // a negative page count copies everything in one call
        #expect(backup.remainingPageCount == 0)

        #expect(try destination.scalar("SELECT COUNT(*) FROM t")?.integer == 2)
    }

    @Test func backupCopiesIncrementally() throws {
        let source = try Connection(path: ":memory:")
        try source.run("CREATE TABLE t (value INTEGER)")
        for value in 1...50 {
            try source.run("INSERT INTO t (value) VALUES (?)", [value.binding])
        }

        let destination = try Connection(path: ":memory:")
        var backup = try Backup(source: source, destination: destination)
        var stepCount = 0
        while try backup.step(pageCount: 1) {
            stepCount += 1
        }
        // more than one page was required to copy the whole database
        #expect(stepCount > 0)
        #expect(backup.totalPageCount > 0)
        #expect(backup.remainingPageCount == 0)
        let sourceSum = try source.scalar("SELECT SUM(value) FROM t")?.integer
        let destinationSum = try destination.scalar("SELECT SUM(value) FROM t")?.integer
        #expect(destinationSum == sourceSum)
    }
}
