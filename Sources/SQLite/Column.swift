//
//  StatementColumnView.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

/// SQLite Query Results Column
public struct Column: Equatable, Hashable, Sendable {
    
    public let row: Int
    
    public let index: Int
    
    public let name: String
}
