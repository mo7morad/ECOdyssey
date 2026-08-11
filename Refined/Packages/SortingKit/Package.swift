// swift-tools-version: 6.0

import PackageDescription

// macOS is declared so the domain suite runs on a developer machine without a
// simulator. iOS is the shipping platform.
let package = Package(
    name: "SortingKit",
    platforms: [.iOS("27.0"), .macOS(.v14)],
    products: [
        .library(name: "SortingKit", targets: ["SortingKit"]),
    ],
    targets: [
        .target(
            name: "SortingKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SortingKitTests",
            dependencies: ["SortingKit"]
        ),
    ]
)
