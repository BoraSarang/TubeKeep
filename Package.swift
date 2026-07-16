// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TubeKeep",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "TubeKeep",
            dependencies: [
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
            ]
        ),
    ]
)
