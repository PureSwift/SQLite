//
//  DataFileTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

import Foundation
import Testing
@testable import SQLite

@Suite struct DataFileTests {
    
    @Test func locations() throws {
        
    }
}

private extension DataFileTests {
    
    /// Load data file
    func loadDataFile() throws -> DataFile {
        guard let path = path(for: "data.sqlite") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try DataFile(path: path)
    }
}
