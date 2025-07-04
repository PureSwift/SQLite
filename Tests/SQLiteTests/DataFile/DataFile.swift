//
//  DataFile.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

import SQLite

/// Sites Data file
public struct DataFile: ~Copyable {
    
    // MARK: - Properties
    
    public let path: String
    
    internal let connection: SQLite.Connection
    
    // MARK: - Initialization
    
    public init(path: String) throws(SQLiteError) {
        self.path = path
        self.connection = try SQLite.Connection(path: path)
    }
}
