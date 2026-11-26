// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MapClustering",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(name: "MapClustering", targets: ["MapClustering"]),
        .library(name: "MapClusteringCore", targets: ["MapClusteringCore"])
    ],
    targets: [
        .target(name: "MapClusteringCore"),
        .target(name: "MapClustering", dependencies: ["MapClusteringCore"], resources: [.process("Resources")]),
        .testTarget(name: "MapClusteringCoreTests", dependencies: ["MapClusteringCore"]),
        .testTarget(name: "MapClusteringTests", dependencies: ["MapClustering", "MapClusteringCore"]),
        .testTarget(name: "DeviceBenchmarks", dependencies: ["MapClusteringCore"], path: "Benchmarks")
    ],
    swiftLanguageModes: [.v6]
)
