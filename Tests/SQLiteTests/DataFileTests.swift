//
//  DataFileTests.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

import Foundation
import Testing
@testable import SQLite

@Suite struct DataFileTests {

    @Test func locations() throws {
        let file = try loadDataFile()
        let values = try file.fetchLocations()
        #expect(values.first?.id == "001")
        #expect(values.first?.name == "TA Ashland")
        #expect(values.first?.directions == "I-95 & Rt. 54, Exit 92")
        #expect(values.count == 350)
    }

    @Test func amenities() throws {
        let file = try loadDataFile()
        let values = try file.fetchAmenities()
        #expect(values.count == 218)
        #expect(values.first?.id == "A & W")
        #expect(values.first?.image == "aw.png")
        #expect(values.first?.descriptionText == "A&W All American Food")
    }

    @Test func siteAmenities() throws {
        let file = try loadDataFile()
        let values = try file.fetchSiteAmenities()
        #expect(values.first?.id == "001")
        #expect(values.first?.image == "cat.png")
        #expect(values.first?.fOrA == "A")
        #expect(values.count == 6099)
    }

    @Test func restaurants() throws {
        let file = try loadDataFile()
        let values = try file.fetchRestaurants()
        #expect(values.first?.id == "1")
        #expect(values.first?.image == "pizzahut.jpg")
        #expect(values.first?.name == "Pizza Hut")
        #expect(values.count == 30)
    }

    @Test func configuration() throws {
        let file = try loadDataFile()
        let configuration = try file.fetchConfiguration()
        #expect(configuration.count == 25)
        #expect(configuration.databaseVersion == "1.6218")
        #expect(configuration.activeDatabaseVersion == "1.6217")
        #expect(configuration.showDirections == true)
        #expect(configuration.privacyPolicy?.description == "http://www.ta-petro.com/privacy-policy")
        #expect(configuration["ludistance"] == "02/22/11 11:00:00")
        #expect(configuration.lastUpdatedDistance != nil)
    }

    @Test func states() throws {
        let file = try loadDataFile()
        let values = try file.fetchStates()
        #expect(values.first?.id == "AL")
        #expect(values.first?.name == "ALABAMA")
        #expect(values.count == 52)
    }

    @Test func interstates() throws {
        let file = try loadDataFile()
        let values = try file.fetchInterstates()
        #expect(values.first(where: { $0.id == "292" })?.interstate == "US-93")
        #expect(values.count == 370)
    }

    @Test func prompts() throws {
        let file = try loadDataFile()
        let values = try file.fetchPrompts()
        #expect(values.first?.type == "tye")
        #expect(values.first?.value == "00")
        #expect(values.first?.text == "2000")
        #expect(values.count == 336)
    }

    @Test func locationIDFilter() throws {
        let file = try loadDataFile()
        guard let site = try file.location(id: "001") else {
            Issue.record("Not found")
            return
        }
        #expect(site.name == "TA Ashland")
    }

    @Test func locationSearchFilter() throws {
        let file = try loadDataFile()
        let locations = try file.filterLocations(
            searchText: "Petro Carnesville",
            states: ["GA"],
            sites: ["377"]
        )
        #expect(locations.count == 1)
        #expect(locations.first?.name == "Petro Carnesville")
        #expect(locations.first?.id == "377")
        #expect(locations.first?.state == "GA")
    }

    @Test func locationAmenitiesFilter() throws {
        let file = try loadDataFile()
        let locations = try file.filterLocations(
            interstates: [],
            amenities: ["def25g.png"]
        )
        #expect(locations.count == 15)
        #expect(locations.first?.id == "259")
        #expect(locations.first?.state == "ND")
    }

    @Test func locationInterstateFilter() throws {
        let file = try loadDataFile()
        let locations = try file.filterLocations(
            interstates: ["I-15"],
            amenities: []
        )
        #expect(locations.count == 4)
    }
}

private extension DataFileTests {

    /// Load data file
    func loadDataFile() throws -> DataFile {
        guard let path = path(for: "data.sqlite") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try DataFile(path: path)
    }
}
