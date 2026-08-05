// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TubeKeep",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.0"
        ),
    ],
    targets: [
        .systemLibrary(
            name: "Clibmpv",
            pkgConfig: "mpv",
            providers: [
                .brew(["mpv"])
            ]
        ),
        .executableTarget(
            name: "TubeKeep",
            dependencies: [
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
                "Clibmpv",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .executableTarget(
            name: "TubeKeepWidget",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "TubeKeepTests",
            dependencies: ["TubeKeep"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
