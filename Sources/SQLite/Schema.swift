//
//  Schema.swift
//  SQLite
//
//  Created by Alsey Coleman Miller on 7/17/26.
//

/// Executes schema (DDL) changes against a connection.
public struct SchemaChanger {

    let connection: Connection.Handle

    public init(connection: borrowing Connection) {
        self.connection = connection.handle
    }
}

public extension SchemaChanger {

    /// Create a table by describing its columns in `body`, then execute the `CREATE TABLE`.
    func create(table name: String, ifNotExists: Bool = true, _ body: (inout CreateTableDefinition) -> Void) throws(SQLiteError) {
        var definition = CreateTableDefinition(name: name)
        body(&definition)
        let sql = definition.sql(ifNotExists: ifNotExists)
        let statement = try Statement.Handle.prepare(sql, connection: connection).get()
        _ = try statement.step(connection: connection).get()
        statement.finalize()
    }
}

public extension SchemaChanger {

    struct CreateTableDefinition {

        let name: String

        var columns: [ColumnDefinition] = []

        init(name: String) {
            self.name = name
        }

        public mutating func add(column: ColumnDefinition) {
            columns.append(column)
        }
    }
}

extension SchemaChanger.CreateTableDefinition {

    func sql(ifNotExists: Bool) -> String {
        let columnDefinitions = columns.map(\.sql)
        let foreignKeys = columns.compactMap(\.references?.sql)
        let clauses = columnDefinitions + foreignKeys
        let existsClause = ifNotExists ? "IF NOT EXISTS " : ""
        return "CREATE TABLE \(existsClause)\(name.quotedSQLIdentifier) (\(clauses.joined(separator: ", ")))"
    }
}

/// Describes a single column for `SchemaChanger.CreateTableDefinition`.
public struct ColumnDefinition {

    public let name: String

    public let primaryKey: PrimaryKey?

    public let type: Affinity

    public let nullable: Bool

    public let unique: Bool

    public let defaultValue: DefaultValue

    public let references: References?

    public init(
        name: String,
        primaryKey: PrimaryKey?,
        type: Affinity,
        nullable: Bool,
        unique: Bool,
        defaultValue: DefaultValue,
        references: References?
    ) {
        self.name = name
        self.primaryKey = primaryKey
        self.type = type
        self.nullable = nullable
        self.unique = unique
        self.defaultValue = defaultValue
        self.references = references
    }
}

public extension ColumnDefinition {

    struct PrimaryKey: Sendable {

        public let autoIncrement: Bool

        public init(autoIncrement: Bool) {
            self.autoIncrement = autoIncrement
        }
    }

    /// SQLite [column affinity](https://sqlite.org/datatype3.html#determination_of_column_affinity).
    enum Affinity: String, Sendable {

        case TEXT
        case NUMERIC
        case INTEGER
        case REAL
        case BLOB
    }

    enum DefaultValue: Sendable {

        case NULL
        case integer(Int64)
        case double(Double)
        case text(String)
    }

    struct References: Sendable {

        public let fromColumn: String

        public let toTable: String

        public let toColumn: String

        public init(fromColumn: String, toTable: String, toColumn: String) {
            self.fromColumn = fromColumn
            self.toTable = toTable
            self.toColumn = toColumn
        }
    }
}

internal extension ColumnDefinition {

    var sql: String {
        var clause = "\(name.quotedSQLIdentifier) \(type.rawValue)"
        if let primaryKey {
            clause += " PRIMARY KEY"
            if primaryKey.autoIncrement {
                clause += " AUTOINCREMENT"
            }
        }
        if nullable == false {
            clause += " NOT NULL"
        }
        if unique {
            clause += " UNIQUE"
        }
        switch defaultValue {
        case .NULL:
            break
        case let .integer(value):
            clause += " DEFAULT \(value)"
        case let .double(value):
            clause += " DEFAULT \(value)"
        case let .text(value):
            let escaped = value.split(separator: "'", omittingEmptySubsequences: false).joined(separator: "''")
            clause += " DEFAULT '\(escaped)'"
        }
        return clause
    }
}

internal extension ColumnDefinition.References {

    var sql: String {
        "FOREIGN KEY (\(fromColumn.quotedSQLIdentifier)) REFERENCES \(toTable.quotedSQLIdentifier) (\(toColumn.quotedSQLIdentifier))"
    }
}

internal extension String {

    var quotedSQLIdentifier: String {
        "\"" + doubledQuotes + "\""
    }

    private var doubledQuotes: String {
        var result = ""
        result.reserveCapacity(count)
        for character in self {
            if character == "\"" {
                result.append("\"\"")
            } else {
                result.append(character)
            }
        }
        return result
    }
}
