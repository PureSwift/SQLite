//
//  ConnectionLocation.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

#if canImport(Foundation)
import Foundation

public extension Connection {
    
    init(path location: Connection.Location, isReadOnly: Bool = false) throws(SQLiteError) {
        try self.init(
            path: location.description,
            isReadOnly: isReadOnly
        )
    }
}

public extension Connection {
    
    /// The location of a SQLite database.
    enum Location: Equatable, Hashable, Sendable {

        /// An in-memory database (equivalent to `.uri(":memory:")`).
        ///
        /// See: <https://www.sqlite.org/inmemorydb.html#sharedmemdb>
        case inMemory

        /// A temporary, file-backed database (equivalent to `.uri("")`).
        ///
        /// See: <https://www.sqlite.org/inmemorydb.html#temp_db>
        case temporary

        /// A database located at the given URI filename (or path).
        ///
        /// See: <https://www.sqlite.org/uri.html>
        ///
        /// - Parameter filename: A URI filename
        /// - Parameter parameters: optional query parameters
        case uri(String, parameters: [URIQueryParameter] = [])
    }
}

extension Connection.Location: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .inMemory:
            return ":memory:"
        case .temporary:
            return ""
        case let .uri(URI, parameters):
            assert(URI.isEmpty == false)
            guard parameters.count > 0,
                  var components = URLComponents(string: URI) else {
                return URI
            }
            components.queryItems =
            (components.queryItems ?? []) + parameters.map(\.queryItem)
            if components.scheme == nil {
                components.scheme = "file"
            }
            return components.description
        }
    }
}

#endif
