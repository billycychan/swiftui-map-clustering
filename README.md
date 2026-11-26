# MapClustering

A Swift 6 package for annotation clustering on SwiftUI’s native Map.

## Add the package

In Xcode, choose **File > Add Package Dependencies** and enter this repository’s Git URL. Select version **0.0.2** and add the `MapClustering` product to your app target. The package supports iOS 17+, macOS 14+, and visionOS 1+.

Or add the dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/billycychan/swiftui-map-clustering", from: "0.0.2")
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

## Display clustered markers

The following API is available starting in version 0.0.2.

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

Open `Examples/Toronto.xcodeproj`, choose the shared **DeviceBenchmarks** scheme, and select a physical iOS device for an approved benchmark run. The scheme uses Toronto as its test host, builds in Release, and enables `MAP_CLUSTERING_BENCHMARK` for the test process. The matrix covers Supercluster, DBSCAN, and K-means (8 clusters) at 50,000 and 100,000 points each. Every case measures one cold membership calculation at zoom 13 and 25 warm viewport queries per XCTest iteration.

### Benchmark scenarios

| Scenario | Distribution |
| --- | --- |
| Sparse, even | Points spread across a 0.5° square |
| Sparse, uneven | Same area with 80% of points concentrated in a hotspot one fifth as wide |
| Dense, even | Points spread across a 0.01° square |
| Dense, uneven | Same smaller area with 80% of points concentrated in a hotspot one fifth as wide |

### Recorded results

Averages of five XCTest measurements on an iPhone 17 running iOS 27.2.1, Release configuration. Each measurement includes dataset creation, one cold membership calculation at zoom 13, and 25 warm viewport queries.

| Algorithm | Points | Scenario | Avg. time | Peak memory |
| --- | ---: | --- | ---: | ---: |
| Supercluster | 50,000 | Dense, even | 0.034 s | 242.0 MB |
| Supercluster | 50,000 | Dense, uneven | 0.034 s | 242.0 MB |
| Supercluster | 50,000 | Sparse, even | 0.193 s | 239.7 MB |
| Supercluster | 50,000 | Sparse, uneven | 0.097 s | 230.9 MB |
| Supercluster | 100,000 | Dense, even | 0.068 s | 213.0 MB |
| Supercluster | 100,000 | Dense, uneven | 0.075 s | 213.1 MB |
| Supercluster | 100,000 | Sparse, even | 0.356 s | 262.1 MB |
| Supercluster | 100,000 | Sparse, uneven | 0.188 s | 254.0 MB |
| DBSCAN | 50,000 | Dense, even | 0.248 s | 217.8 MB |
| DBSCAN | 50,000 | Dense, uneven | 0.551 s | 203.8 MB |
| DBSCAN | 50,000 | Sparse, even | 0.086 s | 201.4 MB |
| DBSCAN | 50,000 | Sparse, uneven | 0.113 s | 201.6 MB |
| DBSCAN | 100,000 | Dense, even | 0.709 s | 239.5 MB |
| DBSCAN | 100,000 | Dense, uneven | 1.631 s | 218.3 MB |
| DBSCAN | 100,000 | Sparse, even | 0.189 s | 213.7 MB |
| DBSCAN | 100,000 | Sparse, uneven | 0.262 s | 214.1 MB |
| K-means | 50,000 | Dense, even | 0.039 s | 210.9 MB |
| K-means | 50,000 | Dense, uneven | 0.026 s | 211.0 MB |
| K-means | 50,000 | Sparse, even | 0.039 s | 210.9 MB |
| K-means | 50,000 | Sparse, uneven | 0.025 s | 210.9 MB |
| K-means | 100,000 | Dense, even | 0.080 s | 211.2 MB |
| K-means | 100,000 | Dense, uneven | 0.075 s | 211.2 MB |
| K-means | 100,000 | Sparse, even | 0.078 s | 211.2 MB |
| K-means | 100,000 | Sparse, uneven | 0.063 s | 211.2 MB |

## SDK check

Xcode 27.2 (27B48), iPhoneOS SDK 27.2. Checked xcodebuild -version and xcrun --sdk iphoneos --show-sdk-version, then searched the public arm64e Swift interface of _MapKit_SwiftUI for “cluster”. The interface exposes MapContent and onMapCameraChange and contains no clustering declaration.
