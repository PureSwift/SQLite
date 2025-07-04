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
            return iso8601DateFormatter.string(from: self)
        }
    }
}

@available(macOS 10.12, *)
nonisolated(unsafe) let iso8601DateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

#endif
