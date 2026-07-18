//
//  LocationAndAffinityTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

import Foundation
import Testing
@testable import SQLite

@Suite struct LocationAndAffinityTests {

    // MARK: - Connection.Location

    @Test func locationDescriptions() {
        #expect(Connection.Location.inMemory.description == ":memory:")
        #expect(Connection.Location.temporary.description == "")
        #expect(Connection.Location.uri("/tmp/db.sqlite").description == "/tmp/db.sqlite")
        #expect(Connection.Location.uri("/tmp/db.sqlite", parameters: []).description == "/tmp/db.sqlite")
    }

    @Test func locationURIWithParameters() {
        let description = Connection.Location.uri(
            "/tmp/db.sqlite",
            parameters: [.mode(.readOnly), .cache(.shared)]
        ).description
        // a scheme-less URI gains the file: scheme when parameters are appended
        #expect(description.hasPrefix("file:"))
        #expect(description.contains("mode=ro"))
        #expect(description.contains("cache=shared"))
        // existing query items are preserved
        let merged = Connection.Location.uri(
            "file:/tmp/db.sqlite?foo=1",
            parameters: [.immutable(true)]
        ).description
        #expect(merged.contains("foo=1"))
        #expect(merged.contains("immutable=1"))
    }

    @Test func locationEquality() {
        #expect(Connection.Location.inMemory == .inMemory)
        #expect(Connection.Location.inMemory != .temporary)
        #expect(Connection.Location.uri("/a") == .uri("/a", parameters: []))
        let locations: Set<Connection.Location> = [.inMemory, .temporary, .uri("/a"), .uri("/a")]
        #expect(locations.count == 3)
    }

    @Test func openInMemoryLocation() throws {
        let connection = try Connection(path: .inMemory)
        try connection.run("CREATE TABLE t (value INTEGER)")
        try connection.run("INSERT INTO t (value) VALUES (?)", [42.binding])
        #expect(try connection.scalar("SELECT value FROM t")?.integer == 42)
    }

    @Test func openTemporaryLocation() throws {
        let connection = try Connection(path: .temporary)
        try connection.run("CREATE TABLE t (value INTEGER)")
        #expect(try connection.scalar("SELECT COUNT(*) FROM t")?.integer == 0)
    }

    // MARK: - URIQueryParameter

    @Test func uriQueryParameterItems() {
        #expect(URIQueryParameter.cache(.shared).queryItem == URLQueryItem(name: "cache", value: "shared"))
        #expect(URIQueryParameter.cache(.private).queryItem == URLQueryItem(name: "cache", value: "private"))
        #expect(URIQueryParameter.immutable(true).queryItem == URLQueryItem(name: "immutable", value: "1"))
        #expect(URIQueryParameter.immutable(false).queryItem == URLQueryItem(name: "immutable", value: "0"))
        #expect(URIQueryParameter.modeOf("/tmp/base.sqlite").queryItem == URLQueryItem(name: "modeOf", value: "/tmp/base.sqlite"))
        #expect(URIQueryParameter.mode(.memory).queryItem == URLQueryItem(name: "mode", value: "memory"))
        #expect(URIQueryParameter.nolock(true).queryItem == URLQueryItem(name: "nolock", value: "1"))
        #expect(URIQueryParameter.nolock(false).queryItem == URLQueryItem(name: "nolock", value: "0"))
        #expect(URIQueryParameter.powersafeOverwrite(true).queryItem == URLQueryItem(name: "psow", value: "1"))
        #expect(URIQueryParameter.powersafeOverwrite(false).queryItem == URLQueryItem(name: "psow", value: "0"))
        #expect(URIQueryParameter.vfs("unix-none").queryItem == URLQueryItem(name: "vfs", value: "unix-none"))
    }

    @Test func uriQueryParameterDescription() {
        #expect(URIQueryParameter.mode(.readWriteCreate).description == URLQueryItem(name: "mode", value: "rwc").description)
    }

    @Test func fileModeRawValues() {
        #expect(URIQueryParameter.FileMode.readOnly.rawValue == "ro")
        #expect(URIQueryParameter.FileMode.readWrite.rawValue == "rw")
        #expect(URIQueryParameter.FileMode.readWriteCreate.rawValue == "rwc")
        #expect(URIQueryParameter.FileMode.memory.rawValue == "memory")
        #expect(URIQueryParameter.FileMode.allCases.count == 4)
        #expect(URIQueryParameter.CacheMode.allCases.map(\.rawValue) == ["shared", "private"])
    }

    // MARK: - TypeAffinity

    @Test func typeAffinityFromDeclaredType() throws {
        guard #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) else { return }
        // Rule 1: INT anywhere in the declared type
        #expect(TypeAffinity("INTEGER") == .integer)
        #expect(TypeAffinity("TINYINT") == .integer)
        #expect(TypeAffinity("int") == .integer)
        // rule order: CHARINT matches rules 1 and 2, rule 1 wins
        #expect(TypeAffinity("CHARINT") == .integer)
        // Rule 2: CHAR, CLOB, or TEXT
        #expect(TypeAffinity("VARCHAR(255)") == .text)
        #expect(TypeAffinity("CLOB") == .text)
        #expect(TypeAffinity("text") == .text)
        // Rule 3: BLOB (case-insensitive, like every other rule)
        #expect(TypeAffinity("BLOB") == .blob)
        #expect(TypeAffinity("blob") == .blob)
        // Rule 4: REAL, FLOA, or DOUB
        #expect(TypeAffinity("REAL") == .real)
        #expect(TypeAffinity("FLOAT") == .real)
        #expect(TypeAffinity("DOUBLE PRECISION") == .real)
        // Rule 5: everything else
        #expect(TypeAffinity("DECIMAL(10,5)") == .numeric)
        #expect(TypeAffinity("DATETIME") == .numeric)
        #expect(TypeAffinity("") == .numeric)
    }

    @Test func typeAffinityRules() {
        #expect(TypeAffinity.integer.rule == 1)
        #expect(TypeAffinity.text.rule == 2)
        #expect(TypeAffinity.blob.rule == 3)
        #expect(TypeAffinity.real.rule == 4)
        #expect(TypeAffinity.numeric.rule == 5)
    }

    @Test func typeAffinityDescription() {
        for affinity in TypeAffinity.allCases {
            #expect(affinity.description == affinity.rawValue)
        }
    }
}
