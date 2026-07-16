// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SQLite",
    products: [
        .library(
            name: "SQLite",
            targets: ["SQLite"]
        )
    ],
    dependencies: [
        // Darwin platforms link the system SQLite3.framework; everywhere else
        // has no system SQLite, so this package's embedded copy is used instead.
        .package(
            url: "https://github.com/PureSwift/swift-sqlcipher",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "SQLite",
            dependencies: [
                .product(
                    name: "SQLCipher",
                    package: "swift-sqlcipher",
                    condition: .when(platforms: [.linux, .android, .windows, .wasi, .openbsd])
                )
            ],
            swiftSettings: [
                .define(
                    "SQLITE_SWIFT_SQLCIPHER",
                    .when(platforms: [.linux, .android, .windows, .wasi, .openbsd])
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
