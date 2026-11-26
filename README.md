# MapClustering

A Swift 6 package for annotation clustering on SwiftUI’s native Map.

<!-- GIF placeholder: Toronto clusters expanding into member pins. -->

## Toronto example

Open [Examples/Toronto.xcodeproj](Examples/Toronto.xcodeproj) in Xcode and select the shared **Toronto** scheme in the toolbar. Choose an iOS 17+ simulator or a Mac running macOS 14+ as the run destination.

The map opens with 100 sample places and uses the package’s default algorithm, Supercluster. Tap or click a numbered cluster to zoom in. Zoom out to see nearby pins group again.

In [TorontoMap.swift](Examples/Toronto/TorontoMap.swift), create one `ClusterController`, pass it to both `ClusteredAnnotations` and `.mapClustering(...)`, and load the places with `replaceItems`. The two annotation closures define how individual markers and cluster badges look. See [Getting started](Sources/MapClustering/MapClustering.docc/GettingStarted.md) for package usage and projection limits.

## Device benchmarks

Open `Examples/Toronto.xcodeproj`, choose the shared **DeviceBenchmarks** scheme, and select a physical iOS device for an approved benchmark run. The scheme uses Toronto as its test host, builds in Release, and enables `MAP_CLUSTERING_BENCHMARK` for the test process. Each algorithm has 50k and 100k fixtures. The dense DBSCAN methods add a compact hotspot and a separate noise point. Use the XCTest clock and memory metrics for the whole workload and the **Cold membership** and **Warm query** signposts to measure the phases separately.

## SDK check

Xcode 27.2 (27B48), iPhoneOS SDK 27.2. Checked xcodebuild -version and xcrun --sdk iphoneos --show-sdk-version, then searched the public arm64e Swift interface of _MapKit_SwiftUI for “cluster”. The interface exposes MapContent and onMapCameraChange and contains no clustering declaration.
