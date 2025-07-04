//
//  Codable.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

public typealias SQLiteCodable = SQLiteEncodable & SQLiteDecodable

public protocol SQLiteEncodable {
    
    func encode(to row: inout Row) throws(SQLiteError)
}

public protocol SQLiteDecodable {
    
    init(row: borrowing Row) throws(SQLiteError)
}
