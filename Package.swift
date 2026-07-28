// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport
import class Foundation.ProcessInfo

// get environment variables
let environment = ProcessInfo.processInfo.environment
let dynamicLibrary = environment["SWIFT_BUILD_DYNAMIC_LIBRARY"] == "1"
let systemSQLite = environment["SWIFT_BUILD_SYSTEM_SQLITE"] == "1"

// force building as dynamic library
let libraryType: PackageDescription.Product.Library.LibraryType? = dynamicLibrary ? .dynamic : nil

// Linux uses the embedded SQLite build by default, like the other non-Darwin
// platforms. Set `SWIFT_BUILD_SYSTEM_SQLITE=1` to link the system SQLite
// (`libsqlite3-dev` / `sqlite-devel`) there instead.
let embeddedSQLitePlatforms: [Platform] = systemSQLite
    ? [.android, .windows, .wasi, .openbsd]
    : [.linux, .android, .windows, .wasi, .openbsd]

var sqliteDependencies: [Target.Dependency] = [
    .product(
        name: "SQLCipher",
        package: "swift-sqlcipher",
        condition: .when(platforms: embeddedSQLitePlatforms)
    )
]

var sqliteTargets: [Target] = []

if systemSQLite {
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
        // Darwin platforms link the system SQLite3.framework; everywhere else
        // uses this package's embedded copy, unless Linux opts into the system
        // libsqlite3 with `SWIFT_BUILD_SYSTEM_SQLITE=1`.
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
