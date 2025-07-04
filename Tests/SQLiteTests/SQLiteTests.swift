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
