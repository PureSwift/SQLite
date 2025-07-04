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

public extension Binding.DateFormat {
    
    
}

// MARK: - Formatting

#if canImport(Foundation)

public extension Binding.DateFormat {
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    static func format(text date: Date) -> String {
        date.ISO8601Format(.iso8601)
    }
    
    static func format(integer date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970)
    }
    
    static func format(real date: Date) -> Int64 {
        // TODO: Julian date
        fatalError("Julian date not implemented")
    }
}

#endif
