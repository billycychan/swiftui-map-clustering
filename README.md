# MapClustering

A Swift 6 package for annotation clustering on SwiftUI’s native Map.

## Add the package

In Xcode, choose **File > Add Package Dependencies** and enter this repository’s Git URL. Select version **0.0.1** and add the `MapClustering` product to your app target. The package supports iOS 17+, macOS 14+, and visionOS 1+.

Or add the dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/billycychan/swiftui-map-clustering", from: "0.0.1")
]
```

Then add the product to your app target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "MapClustering", package: "swiftui-map-clustering")
    ]
)
```

## Display clustered markers (unreleased)

The following API is available in the development checkout. For version 0.0.1, use the [tagged example](https://github.com/billycychan/swiftui-map-clustering/tree/0.0.1/Examples/Toronto).

```swift
import MapClustering
import MapKit
import SwiftUI

struct TorontoMap: View {
    @State private var controller = ClusterController(items: TorontoScenario.downtown.makePlaces(), coordinate: \.coordinate)
    @State private var position = MapCameraPosition.region(TorontoScenario.downtown.region)
    @State private var selection: Place.ID?

    var body: some View {
        Map(position: $position, selection: $selection) {
            ClusteredAnnotations(controller, position: $position) { place in
                Marker(place.name, coordinate: place.coordinate)
            }
        }
        .mapClustering(controller)
    }
}
```

Your item type must conform to `Identifiable` and provide a `CLLocationCoordinate2D` at the key path passed to the controller. The default algorithm is Supercluster. See [Getting started](Sources/MapClustering/MapClustering.docc/GettingStarted.md) for options and projection details.

## Toronto example

Open [Examples/Toronto.xcodeproj](Examples/Toronto.xcodeproj) in Xcode and select the shared **Toronto** scheme in the toolbar. Choose an iOS 17+ simulator or a Mac running macOS 14+ as the run destination.

Open **Clustering Debug** to choose a pin distribution, set the count up to 5,000, and tune the clustering algorithm live. The map starts with 100 downtown pins and uses Supercluster by default. Tap or click a numbered cluster to zoom in. Zoom out to see nearby pins group again.

See the [complete Toronto map](Examples/Toronto/TorontoMap.swift).

## Device benchmarks

Open `Examples/Toronto.xcodeproj`, choose the shared **DeviceBenchmarks** scheme, and select a physical iOS device for an approved benchmark run. The scheme uses Toronto as its test host, builds in Release, and enables `MAP_CLUSTERING_BENCHMARK` for the test process. Each algorithm has 50k and 100k fixtures. The dense DBSCAN methods add a compact hotspot and a separate noise point. Use the XCTest clock and memory metrics for the whole workload and the **Cold membership** and **Warm query** signposts to measure the phases separately.

## SDK check

Xcode 27.2 (27B48), iPhoneOS SDK 27.2. Checked xcodebuild -version and xcrun --sdk iphoneos --show-sdk-version, then searched the public arm64e Swift interface of _MapKit_SwiftUI for “cluster”. The interface exposes MapContent and onMapCameraChange and contains no clustering declaration.
