# MapClustering

A Swift 6 package for annotation clustering on SwiftUI’s native Map.

## Add the package

In Xcode, choose **File > Add Package Dependencies** and enter this repository’s Git URL. Select version **0.0.1** and add the `MapClustering` product to your app target. The package supports iOS 17+, macOS 14+, and visionOS 1+.

Or add the dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "<repository Git URL>", from: "0.0.1")
]
```

Then add `.product(name: "MapClustering", package: "swiftui-map-clustering")` to your target’s dependencies. Replace the package name with the repository’s Swift package identity if it differs.

Import `MapClustering` in the file that defines your map. Keep a controller in SwiftUI state, pass it to clustered map content, attach the tracking modifier to the map, and provide your items:

```swift
@State private var controller = ClusterController<Place>(coordinate: \.coordinate)
@State private var position = MapCameraPosition.automatic

var body: some View {
    Map(position: $position) {
        ClusteredAnnotations(controller, position: $position) { place in
            Marker(place.name, coordinate: place.coordinate)
        } cluster: { group in
            Text(group.members.count, format: .number)
        }
    }
    .mapClustering(controller)
    .task {
        controller.replaceItems(places)
    }
}
```

Your item type must conform to `Identifiable` and provide a `CLLocationCoordinate2D` at the key path passed to the controller. The default algorithm is Supercluster. See [Getting started](Sources/MapClustering/MapClustering.docc/GettingStarted.md) for options and projection details.

<!-- GIF placeholder: Toronto clusters expanding into member pins. -->

## Toronto example

Open [Examples/Toronto.xcodeproj](Examples/Toronto.xcodeproj) in Xcode and select the shared **Toronto** scheme in the toolbar. Choose an iOS 17+ simulator or a Mac running macOS 14+ as the run destination.

The map opens with 100 sample places and uses the package’s default algorithm, Supercluster. Tap or click a numbered cluster to zoom in. Zoom out to see nearby pins group again.

In [TorontoMap.swift](Examples/Toronto/TorontoMap.swift), create one `ClusterController`, pass it to both `ClusteredAnnotations` and `.mapClustering(...)`, and load the places with `replaceItems`. The two annotation closures define how individual markers and cluster badges look. See [Getting started](Sources/MapClustering/MapClustering.docc/GettingStarted.md) for package usage and projection limits.

## Device benchmarks

Open `Examples/Toronto.xcodeproj`, choose the shared **DeviceBenchmarks** scheme, and select a physical iOS device for an approved benchmark run. The scheme uses Toronto as its test host, builds in Release, and enables `MAP_CLUSTERING_BENCHMARK` for the test process. Each algorithm has 50k and 100k fixtures. The dense DBSCAN methods add a compact hotspot and a separate noise point. Use the XCTest clock and memory metrics for the whole workload and the **Cold membership** and **Warm query** signposts to measure the phases separately.

## SDK check

Xcode 27.2 (27B48), iPhoneOS SDK 27.2. Checked xcodebuild -version and xcrun --sdk iphoneos --show-sdk-version, then searched the public arm64e Swift interface of _MapKit_SwiftUI for “cluster”. The interface exposes MapContent and onMapCameraChange and contains no clustering declaration.
