# SQLite

A lightweight, modern Swift wrapper over the SQLite C API.

The library is a thin layer over `sqlite3` — you write SQL, and it handles
statement preparation, value binding, row iteration, and error handling using
Swift 6 features (noncopyable types, typed `throws`). It is not a query-builder
DSL.

## Features

- Prepared statements with positional binding and pull-based row iteration
- Convenience `run` / `scalar` / `transaction` helpers
- Custom SQL **scalar**, **aggregate**, and **window** functions
- Custom **collating sequences**
- A minimal schema (DDL) builder — `CREATE TABLE`, primary/foreign keys, unique,
  default, nullable
- `Blob`, `Data`, `UUID`, and `Date` binding conversions
- Cross-platform: uses the system `SQLite3` on Apple platforms and the embedded
  [swift-sqlcipher](https://github.com/PureSwift/swift-sqlcipher) build
  everywhere else (Linux, Android, Windows, WASI, OpenBSD)

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/PureSwift/SQLite.git", branch: "master")
]
```

Then add `SQLite` to your target's dependencies.

## Usage

### Opening a connection

```swift
import SQLite

// A file on disk
let connection = try Connection(path: "/path/to/database.sqlite")

// Read-only
let readonly = try Connection(path: "/path/to/database.sqlite", isReadOnly: true)

// In-memory, temporary, or URI locations
let memory = try Connection(path: .inMemory)
```

### Running statements

```swift
try connection.run("CREATE TABLE people (id TEXT PRIMARY KEY, name TEXT, age INTEGER)")
try connection.run(
    "INSERT INTO people (id, name, age) VALUES (?, ?, ?)",
    ["1".binding, "Alice".binding, 30.binding]
)

// Single value
let count = try connection.scalar("SELECT COUNT(*) FROM people")?.integer

// Transactions (rolls back if the body throws)
try connection.transaction {
    try connection.run("INSERT INTO people (id, name) VALUES (?, ?)", ["2".binding, "Bob".binding])
    try connection.run("INSERT INTO people (id, name) VALUES (?, ?)", ["3".binding, "Carol".binding])
}
```

### Iterating rows

```swift
let statement = try connection.prepare("SELECT id, name FROM people ORDER BY id")
while let row = try statement.failableNext() {
    let id = row[0]?.string
    let name = row[1]?.string
    print(id ?? "", name ?? "")
}

// Or as dictionaries keyed by column name
for row in try connection.prepare("SELECT * FROM people").rowDictionaries() {
    print(row["name"] ?? nil)
}
```

### Schema builder

```swift
let schema = SchemaChanger(connection: connection)
try schema.create(table: "people") { table in
    table.add(column: ColumnDefinition(
        name: "id", primaryKey: .init(autoIncrement: false), type: .TEXT,
        nullable: false, unique: true, defaultValue: .NULL, references: nil
    ))
    table.add(column: ColumnDefinition(
        name: "team_id", primaryKey: nil, type: .TEXT,
        nullable: true, unique: false, defaultValue: .NULL,
        references: .init(fromColumn: "team_id", toTable: "teams", toColumn: "id")
    ))
}
```

### Custom functions

```swift
// Scalar
try connection.createFunction("double_it", argumentCount: 1, deterministic: true) { arguments in
    .integer((arguments[0].integer ?? 0) * 2)
}

// Aggregate
try connection.createAggregateFunction(
    "my_sum",
    argumentCount: 1,
    initialState: { Int64(0) },
    step: { state, arguments in state += arguments[0].integer ?? 0 },
    final: { state in .integer(state) }
)

// Window (usable with `OVER (...)`)
try connection.createWindowFunction(
    "running_sum",
    argumentCount: 1,
    initialState: { Int64(0) },
    step: { state, arguments in state += arguments[0].integer ?? 0 },
    inverse: { state, arguments in state -= arguments[0].integer ?? 0 },
    value: { state in .integer(state) },
    final: { state in .integer(state) }
)
```

### Custom collations

```swift
try connection.createCollation("REVERSE") { lhs, rhs in
    rhs == lhs ? 0 : (rhs < lhs ? -1 : 1)
}
// ... ORDER BY value COLLATE REVERSE
```

## License

See [LICENSE](LICENSE).
