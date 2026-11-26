# Integrate MapClustering with a SwiftUI map

Start with the [installation and fixed-data example](../README.md#show-clustered-markers). Use one `ClusterController` per map. The controller takes an `Identifiable` model and a key path to its `CLLocationCoordinate2D`. Keep item IDs unique and stable across updates so SwiftUI can track pins and preserve selection.

## Update data, select pins, and style annotations

This view reuses `PlacesMap.Place` from the README. Pass the current array and a revision that changes whenever an item is added, removed, moved, or renamed.

```swift
import MapClustering
import MapKit
import SwiftUI

struct LivePlacesMap: View {
    typealias Place = PlacesMap.Place

    let places: [Place]
    let revision: Int
    let initialRegion: MKCoordinateRegion

    @State private var controller = ClusterController<Place>(coordinate: \.coordinate)
    @State private var position = MapCameraPosition.automatic
    @State private var selection: Place.ID?

    var body: some View {
        Map(position: $position, selection: $selection) {
            ClusteredAnnotations(controller, position: $position) { place in
                Marker(place.name, coordinate: place.coordinate)
                    .tint(.indigo)
            } cluster: { group in
                Text(group.count, format: .number)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.indigo, in: Capsule())
            }
        }
        .mapClustering(controller)
        .onChange(of: revision, initial: true) { _, _ in
            if case .automatic = position {
                position = .region(initialRegion)
            }
            controller.replaceItems(with: places)
        }
        .overlay(alignment: .bottom) {
            if let selected = places.first(where: { $0.id == selection }) {
                Text(selected.name)
                    .padding(8)
                    .background(.regularMaterial, in: Capsule())
                    .padding()
            }
        }
    }
}
```

- **Data.** Call `replaceItems(with:)` when the dataset changes. The controller refreshes the annotations using the current viewport. For fixed data, set `items:` when you initialize the controller.
- **Pins and selection.** Return a `Marker` or your own `Annotation` from the item closure. MapClustering tags individual pins with the item's ID. Use `Item.ID?` for the selection binding.
- **Cluster badges.** Use a plain SwiftUI view for the badge. MapClustering supplies the annotation, button, VoiceOver label, and camera action. Omit the `cluster:` closure to use the default count badge.
- **Camera.** Pass the same camera binding to `Map` and `ClusteredAnnotations`. Activating a cluster fits its members. Supercluster can use a tighter fit toward its expansion zoom when the members still fit. A K-means cluster can remain grouped after zooming because its membership is independent of zoom within the configured range.

## Choose an algorithm

| Algorithm | Behavior |
| --- | --- |
| Supercluster | Builds a hierarchy by merging nearby groups across zoom levels. |
| DBSCAN | Expands density-connected neighborhoods. Points outside those neighborhoods appear as individual pins. |
| K-means | Fits up to a requested number of groups. Groups below the minimum size appear as individual pins. |
| Off | Creates one pin for each finite input coordinate, including coincident coordinates. MapKit can still draw overlapping pins in the same place. |

Update `controller.configuration` to change the algorithm or its settings. See the [settings examples and defaults](../README.md#settings).

## How zoom and filtering work

MapClustering projects coordinates to Web Mercator. The SwiftUI layer derives an integer zoom level from the visible map width and the view's layout width, with a small buffer around zoom thresholds to reduce flicker. Radius is measured in logical tile pixels relative to `tileExtent`. The apparent on-screen radius is approximate when the map is pitched or rotated.

Membership is calculated across the dataset. Panning at the same zoom reuses that membership and filters cluster centers and pins against a padded viewport. Off mode provides all individual pins to the map. Viewport filtering wraps across the antimeridian, while clustering distances use a planar projection with a seam at ±180°.

Clustering work runs outside the main actor. The controller cancels superseded work and publishes only the latest result. `onEvent` can receive aggregate projection, membership, and query diagnostics with timing, counts, and cancellation status. Events contain no item identifiers or coordinates.
