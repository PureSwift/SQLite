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
    
    @Test func openError() throws {
        let path = "/tmp/invalid.sqlite"
        let connection = try Connection(path: path, isReadOnly: true)
        
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
        // compile statement
        while try statement.handle.step(connection: connection.handle).get() {
            print("stepped")
            statement.withColumns {
                for column in $0 {
                    print(column)
                }
            }
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
