// swift-tools-version: 6.0
import PackageDescription

// Pure business logic for FarmaciaApp. Foundation only — no SwiftUI/UIKit/SwiftData —
// so `swift test` runs on the Mac host in seconds without a simulator.
//
// FarmaciaScan adds the barcode detector (Vision, Core Image: both on macOS too), kept
// out of FarmaciaKit so that stays Foundation-only. `swift run scan-bench <folder>`
// benchmarks it on photos.
let package = Package(
    name: "FarmaciaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FarmaciaKit", targets: ["FarmaciaKit"]),
        .library(name: "FarmaciaScan", targets: ["FarmaciaScan"]),
    ],
    targets: [
        .target(name: "FarmaciaKit"),
        .testTarget(name: "FarmaciaKitTests", dependencies: ["FarmaciaKit"]),
        .target(name: "FarmaciaScan", dependencies: ["FarmaciaKit"]),
        .testTarget(name: "FarmaciaScanTests", dependencies: ["FarmaciaScan"], resources: [.copy("Photos")]),
        .executableTarget(name: "scan-bench", dependencies: ["FarmaciaScan"]),
    ],
    swiftLanguageModes: [.v5]
)
