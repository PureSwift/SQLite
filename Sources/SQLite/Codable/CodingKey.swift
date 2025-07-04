//
//  CodingKey.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

protocol SQLiteCodingKey {
    
    /// The string of the column.
    var stringValue: String { get }

    /// The string value of the desired column.
    init?(stringValue: String)
}
