// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SwiftNES",
    platforms: [.macOS(.v13), .iOS(.v17), .tvOS(.v17)],
    products: [
        .library(
            name: "SwiftNES",
            targets: ["SwiftNES"]),
    ],
    targets: [
        .target(
            name: "SwiftNES",
            dependencies: []),
        .testTarget(
            name: "SwiftNESTests",
            dependencies: ["SwiftNES"]),
    ]
)
