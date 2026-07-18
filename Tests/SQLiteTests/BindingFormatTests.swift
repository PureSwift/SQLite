//
//  BindingFormatTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

import Foundation
import Testing
@testable import SQLite

@Suite struct BindingFormatTests {

    // MARK: - UUID

    @Test func uuidFormatAffinity() {
        #expect(Binding.UUIDFormat.text.affinity == .text)
        #expect(Binding.UUIDFormat.blob.affinity == .blob)
    }

    @Test func uuidTextFormat() throws {
        let uuid = try #require(UUID(uuidString: "0F6EF7B2-4D3A-4C0F-9C7B-2C5D0E1A2B3C"))
        #expect(Binding.UUIDFormat.format(text: uuid) == uuid.uuidString)
        guard case let .text(string) = Binding.uuid(uuid, type: .text) else {
            Issue.record("Expected .text binding")
            return
        }
        #expect(string == uuid.uuidString)
    }

    @Test func uuidBlobFormat() throws {
        let uuid = try #require(UUID(uuidString: "0F6EF7B2-4D3A-4C0F-9C7B-2C5D0E1A2B3C"))
        let expectedBytes = withUnsafeBytes(of: uuid.uuid) { [UInt8]($0) }
        #expect(Binding.uuid(uuid).bytes == expectedBytes) // .blob is the default format
        #expect(Binding.uuid(uuid, type: .blob).bytes == expectedBytes)
        #expect(Binding.blob(Binding.UUIDFormat.format(blob: uuid)).bytes == expectedBytes)
    }

    @Test func uuidRoundTrip() throws {
        let uuid = UUID()
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (id BLOB, name TEXT)")
        try connection.run("INSERT INTO t (id, name) VALUES (?, ?)", [.uuid(uuid, type: .blob), .uuid(uuid, type: .text)])
        let statement = try connection.prepare("SELECT id, name FROM t")
        let row = try #require(try statement.failableNext())
        #expect(row[0]?.bytes == withUnsafeBytes(of: uuid.uuid) { [UInt8]($0) })
        #expect(row[1]?.string == uuid.uuidString)
    }

    // MARK: - Date extension

    @Test func julianDay() {
        #expect(Date(timeIntervalSince1970: 0).julian == 2440587.5)
        // one day later is exactly one Julian day later
        #expect(Date(timeIntervalSince1970: 86400).julian == 2440588.5)
    }

    @Test func iso8601String() {
        #expect(Date(timeIntervalSince1970: 0).iso8601 == "1970-01-01T00:00:00Z")
    }

    #if canImport(Foundation) && !canImport(FoundationEssentials)
    @Test func iso8601Formatters() {
        let epoch = Date(timeIntervalSince1970: 0)
        #expect(Date.iso8601DateFormatter.string(from: epoch) == "1970-01-01T00:00:00Z")
        #expect(Date.dateTimeFormatter.string(from: epoch) == "1970-01-01 00:00:00")
        #expect(Date.dateFormatter.string(from: epoch) == "1970-01-01")
        // matches the output of SQLite's datetime() and date() functions
        #expect(Date.dateTimeFormatter.date(from: "1970-01-01 00:00:00") == epoch)
        #expect(Date.dateFormatter.date(from: "1970-01-01") == epoch)
    }
    #endif

    // MARK: - Date binding

    @Test func dateFormatAffinity() {
        #expect(Binding.DateFormat.text.affinity == .text)
        #expect(Binding.DateFormat.real.affinity == .real)
        #expect(Binding.DateFormat.integer.affinity == .integer)
    }

    @Test func dateFormats() {
        let epoch = Date(timeIntervalSince1970: 0)
        #expect(Binding.DateFormat.format(text: epoch) == "1970-01-01T00:00:00Z")
        #expect(Binding.DateFormat.format(integer: epoch) == 0)
        #expect(Binding.DateFormat.format(real: epoch) == 2440587.5)
        #expect(Binding.date(epoch).integer == 0) // .integer is the default format
        #expect(Binding.date(epoch, type: .integer).integer == 0)
        #expect(Binding.date(epoch, type: .real).double == 2440587.5)
        #expect(Binding.date(epoch, type: .text).string == "1970-01-01T00:00:00Z")
    }

    @Test func dateRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (unix INTEGER, julian REAL, iso TEXT)")
        try connection.run(
            "INSERT INTO t (unix, julian, iso) VALUES (?, ?, ?)",
            [.date(date, type: .integer), .date(date, type: .real), .date(date, type: .text)]
        )
        #expect(try connection.scalar("SELECT unix FROM t")?.integer == 1_000_000)
        #expect(try connection.scalar("SELECT julian FROM t")?.double == date.julian)
        #expect(try connection.scalar("SELECT iso FROM t")?.string == date.iso8601)
        // SQLite's own date functions agree with the stored representations
        #expect(try connection.scalar("SELECT unixepoch(iso) FROM t")?.integer == 1_000_000)
    }

    // MARK: - Data binding

    @Test func emptyDataBindsZeroBlob() {
        let binding = Data().binding
        guard case .blob(.zero(0)) = binding else {
            Issue.record("Expected .blob(.zero(0)), got \(binding)")
            return
        }
        #expect(binding.bytes == [])
    }

    @Test func dataBindsBlobBytes() {
        #expect(Data([1, 2, 3]).binding.bytes == [1, 2, 3])
    }

    @Test func dataRoundTrip() throws {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE t (payload BLOB, empty BLOB)")
        try connection.run("INSERT INTO t (payload, empty) VALUES (?, ?)", [data.binding, Data().binding])
        let statement = try connection.prepare("SELECT payload, empty FROM t")
        let row = try #require(try statement.failableNext())
        #expect(row[0]?.bytes == [0xDE, 0xAD, 0xBE, 0xEF])
        #expect(try connection.scalar("SELECT length(empty) FROM t")?.integer == 0)
    }
}
