//
//  ValueAccessTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

import Foundation
import Testing
@testable import SQLite

@Suite struct ValueAccessTests {

    // MARK: - Binding construction

    @Test func boolBinding() {
        #expect(Binding.bool(true).integer == 1)
        #expect(Binding.bool(false).integer == 0)
        #expect(true.binding.integer == 1)
        #expect(false.binding.integer == 0)
    }

    @Test func floatBinding() {
        #expect(Binding.float(1.5).double == 1.5)
        #expect(Float(2.5).binding.double == 2.5)
    }

    @Test func optionalBinding() {
        let none: String? = nil
        guard case .null = none.binding else {
            Issue.record("Expected .null binding")
            return
        }
        let some: String? = "value"
        #expect(some.binding.string == "value")
    }

    @Test func rawRepresentableBinding() {
        enum Color: String {
            case red
        }
        #expect(Color.red.binding.string == "red")
        enum Level: Int {
            case high = 3
        }
        #expect(Level.high.binding.integer == 3)
    }

    @Test func sequenceBinding() {
        #expect([1, 2, 3].binding.compactMap(\.integer) == [1, 2, 3])
    }

    @Test func fixedWidthIntegerBinding() {
        #expect(UInt8(7).binding.integer == 7)
        #expect(Int16(-300).binding.integer == -300)
        #expect(UInt32(70_000).binding.integer == 70_000)
    }

    // MARK: - Binding conversion accessors

    @Test func integerAccessor() {
        #expect(Binding.integer(42).integer == 42)
        #expect(Binding.double(3.9).integer == 3)
        #expect(Binding.text("42").integer == 42)
        #expect(Binding.text("not a number").integer == nil)
        #expect(Binding.null.integer == nil)
        #expect(Blob(bytes: [1]).binding.integer == nil)
    }

    @Test func doubleAccessor() {
        #expect(Binding.integer(3).double == 3.0)
        #expect(Binding.double(2.5).double == 2.5)
        #expect(Binding.text("2.5").double == 2.5)
        #expect(Binding.text("not a number").double == nil)
        #expect(Binding.null.double == nil)
        #expect(Blob(bytes: [1]).binding.double == nil)
    }

    @Test func stringAccessor() {
        #expect(Binding.integer(5).string == "5")
        #expect(Binding.double(2.5).string == "2.5")
        #expect(Binding.text("value").string == "value")
        #expect(Binding.null.string == nil)
        #expect(Blob(bytes: [1]).binding.string == nil)
    }

    // MARK: - Column

    @Test func columnID() {
        let column = Column(row: 0, index: 3, name: "value")
        #expect(column.id == 3)
    }

    @Test func columnValueTypes() {
        #expect(Column.Value.null.type == .null)
        #expect(Column.Value.double(1.5).type == .double)
        #expect(Column.Value.integer(42).type == .integer)
        #expect(Column.Value.text("value").type == .text)
        let bytes: [UInt8] = [1, 2, 3]
        bytes.withUnsafeBytes { buffer in
            #expect(Column.Value.blob(buffer).type == .blob)
        }
    }

    // MARK: - Row reading

    @Test func readEveryValueType() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (n, d, i, s, b, empty)")
        try connection.run(
            "INSERT INTO t (n, d, i, s, b, empty) VALUES (NULL, 1.5, 42, 'text', X'DEAD', X'')"
        )
        let statement = try Statement("SELECT n, d, i, s, b, empty FROM t", connection: connection)
        try connection.execute(statement) { (row: consuming Row) throws(SQLiteError) -> () in
            #expect(try row.readType(at: 0) == .null)
            #expect(try row.read(at: 0) { $0.type } == .null)
            let double: Double? = try row.read(at: 1) { value in
                guard case let .double(double) = value else { return nil }
                return double
            }
            #expect(double == 1.5)
            let integer: Int64? = try row.read(at: 2) { value in
                guard case let .integer(integer) = value else { return nil }
                return integer
            }
            #expect(integer == 42)
            let text: String? = try row.read(at: 3) { value in
                guard case let .text(text) = value else { return nil }
                return text
            }
            #expect(text == "text")
            let blobBytes: [UInt8]? = try row.read(at: 4) { value in
                guard case let .blob(buffer) = value else { return nil }
                return [UInt8](buffer)
            }
            #expect(blobBytes == [0xDE, 0xAD])
            // a zero-length blob reads as an empty buffer
            let emptyCount: Int? = try row.read(at: 5) { value in
                guard case let .blob(buffer) = value else { return nil }
                return buffer.count
            }
            #expect(emptyCount == 0)
        }
    }

    @Test func rowAccessors() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (a INTEGER, b TEXT)")
        try connection.run("INSERT INTO t (a, b) VALUES (1, 'x')")
        let statement = try Statement("SELECT a, b FROM t", connection: connection)
        try connection.execute(statement) { (row: consuming Row) throws(SQLiteError) -> () in
            #expect(row.id == row.index)
            #expect(row.isEmpty == false)
            #expect(row.count == 2)
            #expect(row.startIndex == 0)
            #expect(row.endIndex == 2)
            let columns = row.columns
            #expect(columns.isEmpty == false)
            #expect(columns.count == 2)
            #expect(columns.map(\.name) == ["a", "b"])
            #expect(columns[0].id == 0)
        }
    }
}
