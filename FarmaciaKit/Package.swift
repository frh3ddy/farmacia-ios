// swift-tools-version: 6.0
import PackageDescription

// Pure business logic for FarmaciaApp. Foundation only — no SwiftUI/UIKit/SwiftData —
// so `swift test` runs on the Mac host in seconds without a simulator.
let package = Package(
    name: "FarmaciaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FarmaciaKit", targets: ["FarmaciaKit"]),
    ],
    targets: [
        .target(name: "FarmaciaKit"),
        .testTarget(name: "FarmaciaKitTests", dependencies: ["FarmaciaKit"]),
    ],
    swiftLanguageModes: [.v5]
)
