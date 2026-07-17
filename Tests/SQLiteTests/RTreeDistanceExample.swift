//
//  RTreeDistanceExample.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

import Foundation
import Testing
@testable import SQLite

/// Example: nearest-location search combining an R*Tree spatial index with a custom
/// SQL distance function.
///
/// The R*Tree virtual table gives a fast, index-backed bounding-box prefilter (cheap
/// comparisons on coordinate ranges), and the registered `distance` function then
/// computes the exact great-circle distance to reject bounding-box corners that fall
/// outside the search radius and to sort the results.
@Suite struct RTreeDistanceExample {

    @Test func nearestLocations() throws {
        // Load the real site coordinates from the bundled database.
        guard let path = path(for: "data.sqlite") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let locations = try DataFile(path: path).fetchLocations()

        // Build an in-memory spatial database:
        //  - `location`       holds the site rows
        //  - `location_index` is an R*Tree mapping each site to a (degenerate) bounding box
        let database = try Connection(path: ":memory:")
        try database.run("CREATE TABLE location (id INTEGER PRIMARY KEY, name TEXT, lat REAL, lon REAL)")
        try database.run("CREATE VIRTUAL TABLE location_index USING rtree(id, minLat, maxLat, minLon, maxLon)")

        // Register a `distance(lat1, lon1, lat2, lon2)` function returning kilometres.
        try database.createFunction("distance", argumentCount: 4, deterministic: true) { arguments in
            guard let lat1 = arguments[0].double,
                  let lon1 = arguments[1].double,
                  let lat2 = arguments[2].double,
                  let lon2 = arguments[3].double else {
                return .null
            }
            return .double(haversineDistance(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2))
        }

        // Load the sites. Each point is stored as a zero-area rectangle (min == max).
        try database.transaction {
            for (index, location) in locations.enumerated() {
                let id = Int64(index + 1)
                try database.run(
                    "INSERT INTO location (id, name, lat, lon) VALUES (?, ?, ?, ?)",
                    [id.binding, location.name.binding, location.latitude.binding, location.longitude.binding]
                )
                try database.run(
                    "INSERT INTO location_index (id, minLat, maxLat, minLon, maxLon) VALUES (?, ?, ?, ?, ?)",
                    [id.binding, location.latitude.binding, location.latitude.binding, location.longitude.binding, location.longitude.binding]
                )
            }
        }

        // Search: all sites within 100 km of Richmond, VA, nearest first.
        let queryLatitude = 37.5407
        let queryLongitude = -77.4360
        let radius = 100.0

        // Convert the radius into a latitude/longitude bounding box for the R*Tree prefilter.
        let latitudeDelta = radius / 111.0
        let longitudeDelta = radius / (111.0 * cos(queryLatitude * .pi / 180))

        let sql = """
        SELECT location.name, distance(?, ?, location.lat, location.lon) AS km
        FROM location_index
        JOIN location ON location.id = location_index.id
        WHERE location_index.minLat >= ? AND location_index.maxLat <= ?
          AND location_index.minLon >= ? AND location_index.maxLon <= ?
          AND km <= ?
        ORDER BY km ASC
        """
        let bindings: [Binding?] = [
            queryLatitude.binding, queryLongitude.binding,
            (queryLatitude - latitudeDelta).binding, (queryLatitude + latitudeDelta).binding,
            (queryLongitude - longitudeDelta).binding, (queryLongitude + longitudeDelta).binding,
            radius.binding
        ]

        let statement = try database.prepare(sql, bindings)
        var results = [(name: String, km: Double)]()
        while let row = try statement.failableNext() {
            guard let name = row[0]?.string, let km = row[1]?.double else { continue }
            results.append((name, km))
        }

        // Four sites lie within 100 km, returned nearest-first.
        #expect(results.map(\.name) == [
            "TA Richmond",
            "TA Ashland",
            "TA Express Stony Creek",
            "TA Express Warfield"
        ])
        #expect(results.first?.km ?? 0 < 25)
        // returned nearest-first (distances ascending)
        let distances = results.map(\.km)
        #expect(distances == distances.sorted())
    }
}

/// Great-circle distance between two coordinates, in kilometres.
private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let earthRadius = 6371.0 // km
    let phi1 = lat1 * .pi / 180
    let phi2 = lat2 * .pi / 180
    let deltaPhi = (lat2 - lat1) * .pi / 180
    let deltaLambda = (lon2 - lon1) * .pi / 180
    let a = sin(deltaPhi / 2) * sin(deltaPhi / 2)
        + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
    return 2 * earthRadius * asin(min(1, sqrt(a)))
}
