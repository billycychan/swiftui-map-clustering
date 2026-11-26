import MapKit
import SwiftUI
import MapClusteringCore

/// Renders item content and accessible, tappable cluster annotations inside a native Map.
public struct ClusteredAnnotations<Item: Identifiable, Pin: MapContent, Badge: View>: MapContent {
    private enum MapAnnotationID: Hashable {
        case pin(Item.ID)
        case cluster(revision: Int, zoom: Int?, anchor: Int)
    }

    private let controller: ClusterController<Item>
    @Binding private var position: MapCameraPosition
    private let pin: (Item) -> Pin
    private let badge: (ClusterGroup) -> Badge

    public init(_ controller: ClusterController<Item>, position: Binding<MapCameraPosition>,
                @MapContentBuilder item: @escaping (Item) -> Pin,
                @ViewBuilder cluster: @escaping (ClusterGroup) -> Badge) {
        self.controller = controller
        _position = position
        pin = item
        badge = cluster
    }

    public var body: some MapContent {
        let items = controller.items
        let presentation = controller.presentation
        let algorithm = controller.configuration.algorithm
        let entries = presentation.groups.lazy.map { group in
            let id: MapAnnotationID
            if group.count == 1 {
                id = .pin(items[group.id].id)
            } else {
                // A Supercluster node retains its creation level until it splits.
                let zoom: Int?
                if case .dbscan = algorithm { zoom = presentation.zoom } else { zoom = group.expansionZoom }
                id = .cluster(revision: presentation.revision, zoom: zoom, anchor: group.id)
            }
            return (id: id, group: group)
        }
        ForEach(entries, id: \.id) { entry in
            let group = entry.group
            if group.count == 1 {
                pin(items[group.id]).tag(items[group.id].id)
            } else {
                Annotation("", coordinate: group.coordinate.location) {
                    ClusterButton(group: group, expansionWidth: controller.expansionWidth(for: group), position: $position) { badge(group) }
                        .transition(.scale(scale: 0.75).combined(with: .opacity))
                }
            }
        }
    }
}

public extension ClusteredAnnotations where Badge == ClusterCountBadge {
    /// Renders individual items and uses a numbered badge for each cluster.
    init(_ controller: ClusterController<Item>, position: Binding<MapCameraPosition>,
         @MapContentBuilder item: @escaping (Item) -> Pin) {
        self.init(controller, position: position, item: item) { ClusterCountBadge(count: $0.count) }
    }
}
