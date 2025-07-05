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
        #expect(connection.filename == path)
    }
    
    @Test func statementError() throws {
        let path = "/tmp/invalid.sqlite"
        let connection = try Connection(path: path, isReadOnly: true)
        let sql = "SELECT COUNT(*) FROM abcdz"
        do {
            _ = try Statement(sql, connection: connection)
        }
        catch {
            #expect(error.message == "Unable to initialize statement.")
            #expect(error.statement == sql)
            print(error)
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
        #expect(connection.filename == path)
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
        #expect(count == 5932)
    }
    
    @Test func iterateTextRows() throws {
        let fileName = "data.sqlite"
        guard let path = path(for: fileName) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let connection = try Connection(path: path)
        #expect(connection.filename == path)
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
        #expect(connection.filename == path)
        let sql = "SELECT * FROM locations WHERE location LIKE ? AND state = ? AND site_id = ?"
        var statement = try Statement(sql, connection: connection)
        // bind values
        try statement.bind(.text("%Petro Carnesville%"), at: 1, connection: connection)
        try statement.bind(.text("GA"), at: 2, connection: connection)
        try statement.bind(.text("377"), at: 3, connection: connection)
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

