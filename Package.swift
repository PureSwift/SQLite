// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport
import class Foundation.ProcessInfo

// get environment variables
let environment = ProcessInfo.processInfo.environment
let dynamicLibrary = environment["SWIFT_BUILD_DYNAMIC_LIBRARY"] == "1"
let embeddedSQLite = environment["SWIFT_BUILD_SQLCIPHER"] == "1"

// force building as dynamic library
let libraryType: PackageDescription.Product.Library.LibraryType? = dynamicLibrary ? .dynamic : nil

// Linux links the system SQLite (`libsqlite3-dev` / `sqlite-devel`) by default.
// Set `SWIFT_BUILD_SQLCIPHER=1` to use the embedded build there instead, e.g.
// when the development package isn't available.
let embeddedSQLitePlatforms: [Platform] = embeddedSQLite
    ? [.linux, .android, .windows, .wasi, .openbsd]
    : [.android, .windows, .wasi, .openbsd]

var sqliteDependencies: [Target.Dependency] = [
    .product(
        name: "SQLCipher",
        package: "swift-sqlcipher",
        condition: .when(platforms: embeddedSQLitePlatforms)
    )
]

var sqliteTargets: [Target] = []

if !embeddedSQLite {
    sqliteDependencies.append(
        .target(name: "CSQLite", condition: .when(platforms: [.linux]))
    )
    sqliteTargets.append(
        .systemLibrary(
            name: "CSQLite",
            pkgConfig: "sqlite3",
            providers: [
                .apt(["libsqlite3-dev"]),
                .yum(["sqlite-devel"])
            ]
        )
    )
}

let package = Package(
    name: "SQLite",
    products: [
        .library(
            name: "SQLite",
            type: libraryType,
            targets: ["SQLite"]
        )
    ],
    dependencies: [
        // Darwin platforms link the system SQLite3.framework and Linux links the
        // system libsqlite3; the remaining platforms have no system SQLite, so
        // this package's embedded copy is used instead.
        .package(
            url: "https://github.com/PureSwift/swift-sqlcipher",
            from: "0.1.0"
        )
    ],
    targets: sqliteTargets + [
        .target(
            name: "SQLite",
            dependencies: sqliteDependencies,
            swiftSettings: [
                .define(
                    "SQLITE_SWIFT_SQLCIPHER",
                    .when(platforms: embeddedSQLitePlatforms)
                )
            ]
        ),
        .testTarget(
            name: "SQLiteTests",
            dependencies: ["SQLite"],
            resources: [
               .copy("TestFiles")
           ]
        )
    ]
)
