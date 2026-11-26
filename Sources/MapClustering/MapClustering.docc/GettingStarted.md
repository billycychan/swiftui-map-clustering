# Display clustered places

Keep one controller in view state and pass it to both the map content and the camera-tracking modifier. The caller retains its own identifiable model.

```swift
import MapKit
import MapClustering
import MapClusteringCore
import SwiftUI

struct PlacesMap: View {
    let places: [Place]
    let revision: Int
    @State private var controller = ClusterController<Place>(coordinate: \.coordinate)
    @State private var position = MapCameraPosition.automatic
    @State private var selection: Place.ID?

    var body: some View {
        Map(position: $position, selection: $selection) {
            ClusteredAnnotations(controller, position: $position) { place in
                Marker(place.name, coordinate: place.coordinate)
            } cluster: { group in
                Text(group.count, format: .number)
            }
        }
        .mapClustering(controller)
        .onChange(of: revision, initial: true) {
            controller.replaceItems(with: places)
        }
    }
}
```

Provide an initial region or camera when the first dataset should open at a particular location. Change the revision when items, coordinates, or display values change. Use the same ID type for the map selection. The package supplies the annotation button for custom badge views.

Set `controller.configuration.algorithm = .dbscan(radius: 60, minimumPointCount: 4)` to change clustering at the current viewport. Use `.kMeans(clusterCount: 8, minimumClusterSize: 2)` to tune k-means. Supercluster merges nearby points into a hierarchy. DBSCAN follows density-connected neighborhoods and keeps noise as single pins. Experimental k-means takes a target group count and fits deterministic centers across the dataset. Off mode supplies each valid input as a pin.

Cluster badges fit their members when activated. Supercluster can use a tighter fit to reach its expansion zoom when the members still fit. The tracking modifier honors Reduce Motion for animated changes between zoom levels.

The radius is measured in tile pixels relative to extent at the current integer zoom. Zoom uses projected map width and layout width, so the radius is approximate for rotated or pitched cameras. Whole-dataset membership persists across pans. Viewport filtering wraps across the date line. Planar distance calculations have a seam at ±180 degrees.

For fixed data, pass `items:` when creating the controller. Omit the `cluster:` closure to use the default count badge.

To record timings with unified logging, import `OSLog` and pass an event handler when creating the controller:

```swift
let logger = Logger(subsystem: "Places", category: "Clustering")
let controller = ClusterController(items: places, coordinate: \.coordinate) { event in
    logger.info("\(event.stage.rawValue) took \(String(describing: event.elapsed))")
}
```
