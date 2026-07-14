// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "동영상 다운로더",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "MDownload",
            dependencies: [
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
            ]
        ),
    ]
)
