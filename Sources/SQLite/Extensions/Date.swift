//
//  Date.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

#if canImport(Foundation)
import Foundation

internal extension Date {
    
    /// Julian day numbers, the number of days since noon in Greenwich on November 24, 4714 B.C. according to the proleptic Gregorian calendar.
    var julian: Double {
        timeIntervalSince1970 / 86400.0 + 2440587.5
    }
    
    /// ISO8601 string ("YYYY-MM-DDTHH:MM:SSZ")
    var iso8601: String {
        if #available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
            return self.ISO8601Format()
        } else {
            return Date.iso8601DateFormatter.string(from: self)
        }
    }
}

internal extension Date {
    
    static var iso8601DateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
    
    /// Matches dates from the `datetime()` function
    ///
    /// > Note: Because `ISO8601DateFormatter` isn't `Sendable`, we have to do the MUCH less efficient thing of creating
    /// > a new formatter every time we want to use it instead of just caching one :(
    static var dateTimeFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFullDate,
            .withDashSeparatorInDate,
            .withSpaceBetweenDateAndTime,
            .withTime,
            .withColonSeparatorInTime
        ]
        return formatter
    }

    /// Matches dates from the `date()` function
    ///
    /// > Note: Because `ISO8601DateFormatter` isn't `Sendable`, we have to do the MUCH less efficient thing of creating
    /// > a new formatter every time we want to use it instead of just caching one :(
    static var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFullDate,
            .withDashSeparatorInDate
        ]
        return formatter
    }
}

#endif
