//
//  DataFile.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/4/25.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SQLite

/// Sites data file
public struct DataFile: ~Copyable {

    // MARK: - Properties

    public let path: String

    internal let connection: SQLite.Connection

    // MARK: - Initialization

    public init(path: String) throws(SQLiteError) {
        self.path = path
        self.connection = try SQLite.Connection(path: path, isReadOnly: true)
    }
}

// MARK: - Querying

internal extension DataFile {

    /// Run a query and decode every row via `make`.
    func fetch<Entity>(
        _ sql: String,
        _ bindings: [Binding?] = [],
        _ make: ([String: Binding?]) -> Entity
    ) throws(SQLiteError) -> [Entity] {
        let statement = try connection.prepare(sql, bindings)
        return try statement.rowDictionaries().map(make)
    }

    /// A comma-separated list of `count` bind placeholders, for use in an `IN (...)` clause.
    func placeholders(_ count: Int) -> String {
        Array(repeating: "?", count: count).joined(separator: ", ")
    }
}

internal extension Dictionary where Key == String, Value == Binding? {

    func string(_ column: String) -> String? {
        (self[column] ?? nil)?.string
    }
}

// MARK: - Location

public extension DataFile {

    struct Location: Equatable, Hashable, Identifiable, Sendable {

        public let id: String

        public var locationID: String

        public var name: String

        public var state: String

        public var city: String

        public var zipCode: String

        public var directions: String?
    }
}

internal extension DataFile.Location {

    init(row: [String: Binding?]) {
        self.id = row.string("site_id") ?? ""
        self.locationID = row.string("location_id") ?? ""
        self.name = row.string("location") ?? ""
        self.state = row.string("state") ?? ""
        self.city = row.string("city") ?? ""
        self.zipCode = row.string("zipcode") ?? ""
        self.directions = row.string("directions")
    }
}

public extension DataFile {

    /// Fetch all locations, ordered by site ID.
    func fetchLocations() throws(SQLiteError) -> [Location] {
        try fetch("SELECT * FROM locations ORDER BY site_id ASC", [], Location.init)
    }

    /// Fetch a single location by its site ID.
    func location(id: Location.ID) throws(SQLiteError) -> Location? {
        try fetch("SELECT * FROM locations WHERE site_id = ?", [id.binding], Location.init).first
    }

    /// Filter locations by name, state, and / or site ID.
    func filterLocations(
        searchText: String? = nil,
        states: [String] = [],
        sites: [Location.ID] = []
    ) throws(SQLiteError) -> [Location] {
        var conditions = [String]()
        var bindings = [Binding?]()
        if let searchText, searchText.isEmpty == false {
            conditions.append("location LIKE ?")
            bindings.append(("%" + searchText + "%").binding)
        }
        if states.isEmpty == false {
            conditions.append("state IN (\(placeholders(states.count)))")
            bindings += states.map { $0.binding }
        }
        if sites.isEmpty == false {
            conditions.append("site_id IN (\(placeholders(sites.count)))")
            bindings += sites.map { $0.binding }
        }
        var sql = "SELECT * FROM locations"
        if conditions.isEmpty == false {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY site_id ASC"
        return try fetch(sql, bindings, Location.init)
    }

    /// Filter locations by interstate and / or amenity, in addition to name / state.
    func filterLocations(
        searchText: String? = nil,
        states: [String] = [],
        interstates: [String] = [],
        amenities: [String] = []
    ) throws(SQLiteError) -> [Location] {
        var sites = Set<Location.ID>()
        if interstates.isEmpty == false {
            try filterInterstates(interstates: interstates).forEach { sites.insert($0.id) }
        }
        if amenities.isEmpty == false {
            try filterSiteAmenities(images: amenities).forEach { sites.insert($0.id) }
        }
        return try filterLocations(searchText: searchText, states: states, sites: sites.sorted())
    }
}

// MARK: - Amenity

public extension DataFile {

    struct Amenity: Equatable, Hashable, Identifiable, Sendable {

        public let id: String

        public var image: String

        public var descriptionText: String
    }
}

internal extension DataFile.Amenity {

    init(row: [String: Binding?]) {
        self.id = row.string("amen_name") ?? ""
        self.image = row.string("iname") ?? ""
        self.descriptionText = row.string("description") ?? ""
    }
}

public extension DataFile {

    /// Fetch all amenities, ordered by name.
    func fetchAmenities() throws(SQLiteError) -> [Amenity] {
        try fetch("SELECT * FROM amenity_master ORDER BY amen_name ASC", [], Amenity.init)
    }
}

// MARK: - Amenity.Site

public extension DataFile.Amenity {

    /// An amenity present at a specific site.
    struct Site: Equatable, Hashable, Identifiable, Sendable {

        public let id: String

        public var fOrA: String

        public var image: String

        public var order: String
    }
}

internal extension DataFile.Amenity.Site {

    init(row: [String: Binding?]) {
        self.id = row.string("site_id") ?? ""
        self.fOrA = row.string("f_or_A") ?? ""
        self.image = row.string("iname") ?? ""
        self.order = row.string("aorder") ?? ""
    }
}

public extension DataFile {

    /// Fetch all site amenities, ordered by site ID.
    func fetchSiteAmenities() throws(SQLiteError) -> [Amenity.Site] {
        try fetch("SELECT * FROM site_amenities ORDER BY site_id ASC", [], Amenity.Site.init)
    }

    /// Filter site amenities by site ID and / or amenity image name.
    func filterSiteAmenities(
        sites: [String] = [],
        images: [String] = []
    ) throws(SQLiteError) -> [Amenity.Site] {
        var conditions = [String]()
        var bindings = [Binding?]()
        if sites.isEmpty == false {
            conditions.append("site_id IN (\(placeholders(sites.count)))")
            bindings += sites.map { $0.binding }
        }
        if images.isEmpty == false {
            conditions.append("iname IN (\(placeholders(images.count)))")
            bindings += images.map { $0.binding }
        }
        var sql = "SELECT * FROM site_amenities"
        if conditions.isEmpty == false {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY site_id ASC"
        return try fetch(sql, bindings, Amenity.Site.init)
    }
}

// MARK: - Restaurant

public extension DataFile {

    struct Restaurant: Equatable, Hashable, Identifiable, Sendable {

        public let id: String

        public var name: String

        public var image: String
    }
}

internal extension DataFile.Restaurant {

    init(row: [String: Binding?]) {
        self.id = row.string("qsr_code") ?? ""
        self.name = row.string("qsr_name") ?? ""
        self.image = row.string("qsr_imagename") ?? ""
    }
}

public extension DataFile {

    /// Fetch all quick-service restaurants, ordered by code.
    func fetchRestaurants() throws(SQLiteError) -> [Restaurant] {
        try fetch("SELECT * FROM qsr_xref ORDER BY qsr_code ASC", [], Restaurant.init)
    }
}

// MARK: - State

public extension DataFile {

    struct State: Equatable, Hashable, Identifiable, Sendable {

        public let id: String

        public var name: String
    }
}

internal extension DataFile.State {

    init(row: [String: Binding?]) {
        self.id = row.string("STATE_AB") ?? ""
        self.name = row.string("STATE_NM") ?? ""
    }
}

public extension DataFile {

    /// Fetch all states, ordered by name.
    func fetchStates() throws(SQLiteError) -> [State] {
        try fetch("SELECT * FROM state_codes ORDER BY STATE_NM ASC", [], State.init)
    }
}

// MARK: - Interstate

public extension DataFile {

    struct Interstate: Equatable, Hashable, Identifiable, Sendable {

        public let id: String

        public var interstate: String
    }
}

internal extension DataFile.Interstate {

    init(row: [String: Binding?]) {
        self.id = row.string("site_id") ?? ""
        self.interstate = row.string("istate") ?? ""
    }
}

public extension DataFile {

    /// Fetch all interstate associations, ordered by site ID.
    func fetchInterstates() throws(SQLiteError) -> [Interstate] {
        try fetch("SELECT * FROM interstates ORDER BY site_id ASC", [], Interstate.init)
    }

    /// Filter interstate associations by site ID and / or interstate name.
    func filterInterstates(
        sites: [String] = [],
        interstates: [String] = []
    ) throws(SQLiteError) -> [Interstate] {
        var conditions = [String]()
        var bindings = [Binding?]()
        if sites.isEmpty == false {
            conditions.append("site_id IN (\(placeholders(sites.count)))")
            bindings += sites.map { $0.binding }
        }
        if interstates.isEmpty == false {
            conditions.append("istate IN (\(placeholders(interstates.count)))")
            bindings += interstates.map { $0.binding }
        }
        var sql = "SELECT * FROM interstates"
        if conditions.isEmpty == false {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY site_id ASC"
        return try fetch(sql, bindings, Interstate.init)
    }
}

// MARK: - Prompt

public extension DataFile {

    struct Prompt: Equatable, Hashable, Sendable {

        public var type: String

        public var value: String

        public var text: String
    }
}

extension DataFile.Prompt: Identifiable {

    public var id: String {
        value
    }
}

internal extension DataFile.Prompt {

    init(row: [String: Binding?]) {
        self.type = row.string("p_type") ?? ""
        self.value = row.string("p_value") ?? ""
        self.text = row.string("p_text") ?? ""
    }
}

public extension DataFile {

    /// Fetch all prompts, ordered by value.
    func fetchPrompts() throws(SQLiteError) -> [Prompt] {
        try fetch("SELECT * FROM prompts ORDER BY p_value ASC", [], Prompt.init)
    }
}

// MARK: - Configuration

public extension DataFile {

    /// Key / value configuration entries.
    struct Configuration: Equatable, Hashable, Sendable {

        internal let values: [String: String]

        internal init(values: [String: String]) {
            self.values = values
        }

        public var count: Int {
            values.count
        }

        public subscript(key: String) -> String? {
            values[key]
        }
    }
}

public extension DataFile {

    /// Fetch the configuration key / value table.
    func fetchConfiguration() throws(SQLiteError) -> Configuration {
        let statement = try connection.prepare("SELECT key, cvalue FROM config")
        var values = [String: String]()
        while let row = try statement.failableNext() {
            guard let key = row[0]?.string else { continue }
            values[key] = row[1]?.string ?? ""
        }
        return Configuration(values: values)
    }
}

public extension DataFile.Configuration {

    var databaseVersion: String? {
        self["dbver"]
    }

    var activeDatabaseVersion: String? {
        self["activedbver"]
    }

    var lastUpdatedDistance: String? {
        self["ludistance"]
    }

    var showDirections: Bool? {
        self["showdirections"].map { $0 == "Y" }
    }

    var privacyPolicy: URL? {
        self["privacypolicy"].flatMap { URL(string: $0) }
    }
}
