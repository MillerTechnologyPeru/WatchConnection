// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "WatchConnection",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(
            name: "WatchConnection",
            targets: ["WatchConnection"]
        ),
    ],
    targets: [
        .target(
            name: "WatchConnection"),
        .testTarget(
            name: "WatchConnectionTests",
            dependencies: ["WatchConnection"]
        ),
    ]
)
