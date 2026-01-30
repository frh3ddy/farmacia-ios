// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FarmaciaApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FarmaciaApp",
            targets: ["FarmaciaApp"]
        ),
    ],
    dependencies: [
        // No external dependencies - using native SwiftUI and Foundation
    ],
    targets: [
        .target(
            name: "FarmaciaApp",
            dependencies: [],
            path: "FarmaciaApp"
        ),
        .testTarget(
            name: "FarmaciaAppTests",
            dependencies: ["FarmaciaApp"],
            path: "FarmaciaAppTests"
        ),
    ]
)
