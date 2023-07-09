// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "SwiftNES",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16)],
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
