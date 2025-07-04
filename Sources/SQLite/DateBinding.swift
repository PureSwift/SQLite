//
//  DateBinding.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

#if canImport(Foundation)
import Foundation
#endif

public extension Binding {
    
    /**
     Date Binding Format
     
     SQLite does not have a storage class set aside for storing dates and/or times. Instead, the built-in Date And Time Functions of SQLite are capable of storing dates and times as TEXT, REAL, or INTEGER values:

     - TEXT as ISO8601 strings ("YYYY-MM-DD HH:MM:SS.SSS").
     - REAL as Julian day numbers, the number of days since noon in Greenwich on November 24, 4714 B.C. according to the proleptic Gregorian calendar.
     - INTEGER as Unix Time, the number of seconds since 1970-01-01 00:00:00 UTC.
     
     Applications can choose to store dates and times in any of these formats and freely convert between formats using the built-in date and time functions.
     */
    enum DateFormat: Equatable, Hashable, Sendable, CaseIterable {
        
        /// TEXT as ISO8601 strings ("YYYY-MM-DD HH:MM:SS.SSS")
        case text
        
        /// REAL as Julian day numbers, the number of days since noon in Greenwich on November 24, 4714 B.C. according to the proleptic Gregorian calendar.
        case real
        
        /// INTEGER as Unix Time, the number of seconds since 1970-01-01 00:00:00 UTC.
        case integer
    }
}

public extension Binding.DateFormat {
    
    var affinity: TypeAffinity {
        switch self {
        case .text:
            return .text
        case .real:
            return .real
        case .integer:
            return .integer
        }
    }
}

// MARK: - Formatting

#if canImport(Foundation)

public extension Binding {
    
    static func date(_ date: Date, type: Binding.DateFormat = .integer) -> Binding {
        type.format(date)
    }
}

public extension Binding.DateFormat {
    
    /// TEXT as ISO8601 strings ("YYYY-MM-DD HH:MM:SS.SSS")
    static func format(text date: Date) -> String {
        date.iso8601
    }
    
    /// INTEGER as Unix Time, the number of seconds since 1970-01-01 00:00:00 UTC.
    static func format(integer date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970)
    }
    
    /// REAL as Julian day numbers, the number of days since noon in Greenwich on November 24, 4714 B.C. according to the proleptic Gregorian calendar.
    static func format(real date: Date) -> Double {
        date.julian
    }
    
    func format(_ date: Date) -> Binding {
        switch self {
        case .text:
            return Self.format(text: date).binding
        case .real:
            return Self.format(real: date).binding
        case .integer:
            return Self.format(integer: date).binding
        }
    }
}

#endif
