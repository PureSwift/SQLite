import Foundation
import Testing
@testable import SQLite

@Suite struct SQLiteTests {
    
    @Test func filename() throws {
        let fileName = "data.sqlite"
        guard let path = path(for: fileName) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let connection = try Connection(path: path)
        #expect(connection.filename.replacingOccurrences(of: "\\", with: "/") == path)
    }
    
    #if !os(Android)
    @Test func statementError() throws {
        // a nonexistent file opened read-write can be created implicitly, so the
        // failure only surfaces once an invalid statement is prepared against it.
        let path = NSTemporaryDirectory() + "invalid.sqlite"
        let connection = try Connection(path: path, isReadOnly: false)
        let sql = "SELECT COUNT(*) FROM abcdz"
        do {
            _ = try Statement(sql, connection: connection)
        }
        catch {
            #expect(error.message == "no such table: abcdz")
            #expect(error.statement == sql)
            print(error)
            return
        }

        Issue.record("Error not thrown")
    }
    #endif

    @Test func readOnlyMissingFile() throws {
        // opening a nonexistent file read-only must fail at connection time,
        // since SQLite cannot create it under `SQLITE_OPEN_READONLY`.
        let path = NSTemporaryDirectory() + "does-not-exist-\(UUID().uuidString).sqlite"
        do {
            _ = try Connection(path: path, isReadOnly: true)
        }
        catch {
            return
        }
        Issue.record("Error not thrown")
    }
    
    @Test func getCount() throws {
        let fileName = "data.sqlite"
        guard let path = path(for: fileName) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let connection = try Connection(path: path)
        #expect(connection.filename.replacingOccurrences(of: "\\", with: "/") == path)
        let sql = "SELECT COUNT(*) FROM site_amenities"
        let statement = try Statement(sql, connection: connection)
        var count = 0
        try connection.execute(statement) { (row: consuming Row) throws(SQLiteError) -> () in
            count = try row.read(at: 0) { value in
                switch value {
                case let .integer(integer):
                    return Int(integer)
                default:
                    return 0
                }
            }
        }
        #expect(count == 6099)
    }
    
    @Test func iterateTextRows() throws {
        let fileName = "data.sqlite"
        guard let path = path(for: fileName) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let connection = try Connection(path: path)
        #expect(connection.filename.replacingOccurrences(of: "\\", with: "/") == path)
        let sql = "SELECT STATE_NM, STATE_AB FROM state_codes"
        let statement = try Statement(sql, connection: connection)
        // execute statement
        var results = [[String: String]]()
        try connection.execute(statement) { (row: consuming Row) throws(SQLiteError) -> () in
            #expect(results.count == row.index)
            var object = [String: String]()
            for (columnIndex, column) in row.columns.enumerated() {
                #expect(columnIndex == column.index)
                let string: String? = try row.read(at: columnIndex) {
                    switch $0 {
                    case let .text(string):
                        return string
                    default:
                        return nil
                    }
                }
                object[column.name] = string
            }
            results.append(object)
        }
        
        let expectedValue: [[String: String]] = [["STATE_NM": "ALABAMA", "STATE_AB": "AL"], ["STATE_NM": "ALASKA", "STATE_AB": "AK"], ["STATE_NM": "ARIZONA", "STATE_AB": "AZ"], ["STATE_AB": "AR", "STATE_NM": "ARKANSAS"], ["STATE_AB": "CA", "STATE_NM": "CALIFORNIA"], ["STATE_NM": "COLORADO", "STATE_AB": "CO"], ["STATE_AB": "CT", "STATE_NM": "CONNECTICUT"], ["STATE_AB": "DE", "STATE_NM": "DELAWARE"], ["STATE_NM": "DISTRICT OF COLUMBIA", "STATE_AB": "DC"], ["STATE_AB": "FL", "STATE_NM": "FLORIDA"], ["STATE_NM": "GEORGIA", "STATE_AB": "GA"], ["STATE_NM": "HAWAII", "STATE_AB": "HI"], ["STATE_NM": "IDAHO", "STATE_AB": "ID"], ["STATE_AB": "IL", "STATE_NM": "ILLINOIS"], ["STATE_NM": "INDIANA", "STATE_AB": "IN"], ["STATE_NM": "IOWA", "STATE_AB": "IA"], ["STATE_AB": "KS", "STATE_NM": "KANSAS"], ["STATE_NM": "KENTUCKY", "STATE_AB": "KY"], ["STATE_NM": "LOUISIANA", "STATE_AB": "LA"], ["STATE_AB": "ME", "STATE_NM": "MAINE"], ["STATE_AB": "MD", "STATE_NM": "MARYLAND"], ["STATE_AB": "MA", "STATE_NM": "MASSACHUSETTS"], ["STATE_NM": "MICHIGAN", "STATE_AB": "MI"], ["STATE_AB": "MN", "STATE_NM": "MINNESOTA"], ["STATE_NM": "MISSISSIPPI", "STATE_AB": "MS"], ["STATE_NM": "MISSOURI", "STATE_AB": "MO"], ["STATE_AB": "MT", "STATE_NM": "MONTANA"], ["STATE_NM": "NEBRASKA", "STATE_AB": "NE"], ["STATE_NM": "NEVADA", "STATE_AB": "NV"], ["STATE_AB": "NH", "STATE_NM": "NEW HAMPSHIRE"], ["STATE_AB": "NJ", "STATE_NM": "NEW JERSEY"], ["STATE_AB": "NM", "STATE_NM": "NEW MEXICO"], ["STATE_NM": "NEW YORK", "STATE_AB": "NY"], ["STATE_NM": "NORTH CAROLINA", "STATE_AB": "NC"], ["STATE_AB": "ND", "STATE_NM": "NORTH DAKOTA"], ["STATE_NM": "OHIO", "STATE_AB": "OH"], ["STATE_NM": "OKLAHOMA", "STATE_AB": "OK"], ["STATE_NM": "OREGON", "STATE_AB": "OR"], ["STATE_NM": "PENNSYLVANIA", "STATE_AB": "PA"], ["STATE_NM": "RHODE ISLAND", "STATE_AB": "RI"], ["STATE_NM": "SOUTH CAROLINA", "STATE_AB": "SC"], ["STATE_NM": "SOUTH DAKOTA", "STATE_AB": "SD"], ["STATE_NM": "TENNESSEE", "STATE_AB": "TN"], ["STATE_NM": "TEXAS", "STATE_AB": "TX"], ["STATE_AB": "UT", "STATE_NM": "UTAH"], ["STATE_AB": "VT", "STATE_NM": "VERMONT"], ["STATE_NM": "VIRGINIA", "STATE_AB": "VA"], ["STATE_NM": "WASHINGTON", "STATE_AB": "WA"], ["STATE_NM": "WEST VIRGINIA", "STATE_AB": "WV"], ["STATE_NM": "WISCONSIN", "STATE_AB": "WI"], ["STATE_NM": "WYOMING", "STATE_AB": "WY"], ["STATE_NM": "ONTARIO", "STATE_AB": "ON"]]
        
        #expect(expectedValue == results)
    }
    
    @Test func filterLocations() throws {
        let fileName = "data.sqlite"
        guard let path = path(for: fileName) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let connection = try Connection(path: path)
        #expect(connection.filename.replacingOccurrences(of: "\\", with: "/") == path)
        let sql = "SELECT * FROM locations WHERE location LIKE ? AND state = ? AND site_id = ?"
        let bindings = [
            "%Petro Carnesville%",
            "GA",
            "377"
        ].binding
        let statement = try Statement.prepare(sql, bindings: bindings, connection: connection)
        // execute statement
        var results = [[String: String]]()
        try connection.execute(statement) { (row: consuming Row) throws(SQLiteError) -> () in
            #expect(results.count == row.index)
            var object = [String: String]()
            for (columnIndex, column) in row.columns.enumerated() {
                #expect(columnIndex == column.index)
                let string: String? = try row.read(at: columnIndex) {
                    switch $0 {
                    case let .text(string):
                        return string
                    default:
                        return "\($0.type)"
                    }
                }
                object[column.name] = string
            }
            results.append(object)
        }
        #expect(results.count == 1)
        let expectedValue: [[String: String]] = [["preferred_parking": "N", "gas": "", "tot_dispensors": "12", "resspaces": "20", "tripak": "Y", "phonefax": "7063351984", "barber": "", "zipcode": "30521", "mailaddress": "10200 Old Federal Rd.", "permitservices": "", "travelstore": "", "longitude": "-83.3199", "mainfaxnumber": "706-335-1982", "mailaddress3": "", "shower_cost": "17", "laundry": "", "state": "GA", "reeferservices": "", "qsr": "", "chiropractor": "", "mobile_shower": "Y", "cbshop": "", "dieselongas": "", "latitude": "34.3481", "weighscales": "", "mainphonenumber": "706-335-1984", "satpumps": "", "prontopass": "", "lodging": "", "servicebays": "5", "speedzone": "", "restaurants": "", "directions": "I-85, Exit 160", "city": "Carnesville", "rvdump": "", "propane": "", "parkingspaces": "221", "location": "Petro Carnesville", "lounge": "", "roadservice": "", "servicecenter": "", "site_id": "377", "shower_ip": "10.200.77.120", "privateshowers": "18", "truckwash": "", "wireless": "", "location_id": "6377", "company": "P"]]
        #expect(expectedValue == results)
    }

    @Test func customFunction() throws {
        let connection = try Connection(path: ":memory:")
        try connection.createFunction("double_it", argumentCount: 1, deterministic: true) { arguments in
            .integer((arguments[0].integer ?? 0) * 2)
        }
        let statement = try Statement.prepare("SELECT double_it(21)", bindings: [], connection: connection)
        var result: Int64 = 0
        try connection.execute(statement) { (row: consuming Row) throws(SQLiteError) -> () in
            result = try row.read(at: 0) { value in
                switch value {
                case let .integer(integer):
                    return integer
                default:
                    return 0
                }
            }
        }
        #expect(result == 42)
    }

    @Test func schemaAndConvenience() throws {
        let connection = try Connection(path: ":memory:")
        let schemaChanger = SchemaChanger(connection: connection)
        try schemaChanger.create(table: "people") { table in
            table.add(column: ColumnDefinition(
                name: "id",
                primaryKey: .init(autoIncrement: false),
                type: .TEXT,
                nullable: false,
                unique: true,
                defaultValue: .NULL,
                references: nil
            ))
            table.add(column: ColumnDefinition(
                name: "name",
                primaryKey: nil,
                type: .TEXT,
                nullable: true,
                unique: false,
                defaultValue: .NULL,
                references: nil
            ))
            table.add(column: ColumnDefinition(
                name: "photo",
                primaryKey: nil,
                type: .BLOB,
                nullable: true,
                unique: false,
                defaultValue: .NULL,
                references: nil
            ))
        }

        try connection.transaction {
            let bindings1: [Binding?] = ["1".binding, "Alice".binding, Blob(bytes: [1, 2, 3]).binding]
            try connection.run("INSERT INTO people (id, name, photo) VALUES (?, ?, ?)", bindings1)
            let bindings2: [Binding?] = ["2".binding, "Bob".binding, nil]
            try connection.run("INSERT INTO people (id, name, photo) VALUES (?, ?, ?)", bindings2)
        }

        let count = try connection.scalar("SELECT COUNT(*) FROM people")
        #expect(count?.integer == 2)

        let statement = try connection.prepare("SELECT id, name, photo FROM people ORDER BY id")
        var rows = [[String: Binding?]]()
        while let row = try statement.failableNext() {
            var dictionary = [String: Binding?]()
            for (index, name) in statement.columnNames.enumerated() {
                dictionary[name] = row[index]
            }
            rows.append(dictionary)
        }
        #expect(rows.count == 2)
        #expect((rows[0]["name"] ?? nil)?.string == "Alice")
        #expect((rows[0]["photo"] ?? nil)?.bytes == [1, 2, 3])
        #expect((rows[1]["photo"] ?? nil) == nil)
    }
    
    // MARK: - Blob

    @Test func blobBytesRoundTrip() {
        let blob = Blob(bytes: [42, 43, 44])
        #expect(blob.bytes == [42, 43, 44])
        #expect(blob.binding.bytes == [42, 43, 44])
    }

    @Test func blobEquality() {
        let blob1 = Blob(bytes: [42, 42, 42])
        let blob2 = Blob(bytes: [42, 42, 42])
        let blob3 = Blob(bytes: [42, 42, 43])
        #expect(Blob(bytes: []) == Blob(bytes: []))
        #expect(blob1 == blob2)
        #expect(blob1 != blob3)
    }

    // MARK: - prepare / run / scalar

    @Test func preparePreparesAndReturnsStatements() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE users (id INTEGER, admin INTEGER)")
        _ = try connection.prepare("SELECT * FROM users WHERE admin = 0")
        _ = try connection.prepare("SELECT * FROM users WHERE admin = ?", [0.binding])
    }

    @Test func runPreparesRunsAndReturnsStatements() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE users (id INTEGER, admin INTEGER)")
        try connection.run("SELECT * FROM users WHERE admin = 0")
        try connection.run("SELECT * FROM users WHERE admin = ?", [0.binding])
    }

    @Test func scalarPreparesRunsAndReturnsScalarValues() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE users (id INTEGER, admin INTEGER)")
        #expect(try connection.scalar("SELECT count(*) FROM users WHERE admin = 0")?.integer == 0)
        #expect(try connection.scalar("SELECT count(*) FROM users WHERE admin = ?", [0.binding])?.integer == 0)
    }

    // MARK: - transaction

    @Test func transactionBeginsAndCommitsTransactions() throws {
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE users (email TEXT)")

        try connection.transaction {
            try connection.run("INSERT INTO users (email) VALUES (?)", ["alice@example.com".binding])
        }

        #expect(try connection.scalar("SELECT count(*) FROM users")?.integer == 1)
    }

    @Test func transactionRollsBackIfBodyThrows() throws {
        struct TestError: Error {}
        let connection = try Connection(path: ":memory:")
        try connection.run("CREATE TABLE users (email TEXT)")

        do {
            try connection.transaction {
                try connection.run("INSERT INTO users (email) VALUES (?)", ["alice@example.com".binding])
                throw TestError()
            }
            Issue.record("expected error")
        } catch is TestError {
            // expected
        }

        #expect(try connection.scalar("SELECT count(*) FROM users")?.integer == 0)
    }

    // MARK: - createFunction

    @Test func createFunctionWithArguments() throws {
        let connection = try Connection(path: ":memory:")
        try connection.createFunction("hello", argumentCount: 1) { arguments in
            guard case let .text(value) = arguments[0] else {
                return .null
            }
            return .text("Hello, \(value)!")
        }
        #expect(try connection.scalar("SELECT hello('world')")?.string == "Hello, world!")
        #expect(try connection.scalar("SELECT hello(NULL)") == nil)
    }

    @Test func createFunctionCreatesQuotableFunction() throws {
        let connection = try Connection(path: ":memory:")
        try connection.createFunction("hello world", argumentCount: 1) { arguments in
            guard case let .text(value) = arguments[0] else {
                return .null
            }
            return .text("Hello, \(value)!")
        }
        #expect(try connection.scalar("SELECT \"hello world\"('world')")?.string == "Hello, world!")
        #expect(try connection.scalar("SELECT \"hello world\"(NULL)") == nil)
    }

    // MARK: - SchemaChanger

    @Test func createTableWithForeignKeyReference() throws {
        let connection = try Connection(path: ":memory:")
        let schemaChanger = SchemaChanger(connection: connection)

        try schemaChanger.create(table: "foo") { table in
            table.add(column: ColumnDefinition(
                name: "id", primaryKey: .init(autoIncrement: true), type: .INTEGER,
                nullable: true, unique: false, defaultValue: .NULL, references: nil
            ))
        }
        try schemaChanger.create(table: "bars") { table in
            table.add(column: ColumnDefinition(
                name: "id", primaryKey: .init(autoIncrement: true), type: .INTEGER,
                nullable: true, unique: false, defaultValue: .NULL, references: nil
            ))
            table.add(column: ColumnDefinition(
                name: "foo_id", primaryKey: nil, type: .INTEGER,
                nullable: false, unique: false, defaultValue: .NULL,
                references: .init(fromColumn: "foo_id", toTable: "foo", toColumn: "id")
            ))
        }

        // verify the foreign key was actually declared, via SQLite's own introspection pragma
        let statement = try connection.prepare("PRAGMA foreign_key_list(bars)")
        let rows = try statement.rowDictionaries()
        #expect(rows.count == 1)
        let row = rows.first
        #expect((row?["table"] ?? nil)?.string == "foo")
        #expect((row?["to"] ?? nil)?.string == "id")
        #expect((row?["from"] ?? nil)?.string == "foo_id")
    }

    @Test func createTableIfNotExists() throws {
        let connection = try Connection(path: ":memory:")
        let schemaChanger = SchemaChanger(connection: connection)

        try schemaChanger.create(table: "foo") { table in
            table.add(column: ColumnDefinition(
                name: "id", primaryKey: .init(autoIncrement: true), type: .INTEGER,
                nullable: true, unique: false, defaultValue: .NULL, references: nil
            ))
        }

        // recreating with ifNotExists: true is a no-op, not an error
        try schemaChanger.create(table: "foo", ifNotExists: true) { table in
            table.add(column: ColumnDefinition(
                name: "id", primaryKey: .init(autoIncrement: true), type: .INTEGER,
                nullable: true, unique: false, defaultValue: .NULL, references: nil
            ))
        }

        // recreating with ifNotExists: false throws, since the table already exists
        do {
            try schemaChanger.create(table: "foo", ifNotExists: false) { table in
                table.add(column: ColumnDefinition(
                    name: "id", primaryKey: .init(autoIncrement: true), type: .INTEGER,
                    nullable: true, unique: false, defaultValue: .NULL, references: nil
                ))
            }
            Issue.record("expected error")
        } catch {
            // expected
        }
    }
}

// MARK: - Supporting Functions

/// Load test file
func path(for file: String) -> String? {
    Bundle.module.path(forResource: "TestFiles/" + file, ofType: nil)
}

/// Read the specified test file and load data.
func data(for file: String) throws -> Data {
    guard let path = path(for: file) else {
        throw CocoaError(.fileNoSuchFile)
    }
    let url = URL(fileURLWithPath: path)
    return try Data(contentsOf: url, options: [.mappedIfSafe])
}

