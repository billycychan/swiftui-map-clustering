import MapKit
import SwiftUI
import MapClusteringCore

extension View {
    /// Feeds map geometry and camera updates to the same controller used by ClusteredAnnotations.
    public func mapClustering<Item>(_ controller: ClusterController<Item>,
                                    frequency: MapCameraUpdateFrequency = .onEnd) -> some View {
        modifier(ClusterTracking(controller: controller, frequency: frequency))
    }
}

private struct ClusterTracking<Item: Identifiable>: ViewModifier {
    let controller: ClusterController<Item>
    let frequency: MapCameraUpdateFrequency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onMapCameraChange(frequency: frequency) { controller.update(rect: $0.rect) }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { controller.update(width: $0) }
            .onChange(of: reduceMotion, initial: true) { controller.reduceMotion = reduceMotion }
    }
}

enum MapAnnotationID<ItemID: Hashable>: Hashable {
    case pin(ItemID)
    case cluster(revision: Int, zoom: Int?, anchor: Int)
}

/// Renders item content and accessible, tappable cluster annotations inside a native Map.
public struct ClusteredAnnotations<Item: Identifiable, Pin: MapContent, Badge: View>: MapContent {
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
        let algorithm = controller.options.algorithm
        let entries = presentation.groups.lazy.map { group in
            let id: MapAnnotationID<Item.ID>
            if group.members.count == 1 {
                id = .pin(items[group.id].id)
            } else {
                // A Supercluster node retains its creation level until it splits.
                let zoom = algorithm == .dbscan ? presentation.zoom : group.expansionZoom
                id = .cluster(revision: presentation.revision, zoom: zoom, anchor: group.id)
            }
            return (id: id, group: group)
        }
        ForEach(entries, id: \.id) { entry in
            let group = entry.group
            if group.members.count == 1 {
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

private struct ClusterButton<Badge: View>: View {
    let group: ClusterGroup
    let expansionWidth: Double?
    @Binding var position: MapCameraPosition
    @ViewBuilder let badge: () -> Badge
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button {
            let target = clusterCameraTarget(for: group, expansionWidth: expansionWidth)
            withAnimation(reduceMotion ? nil : .easeInOut) {
                position = .rect(target)
            }
        } label: { badge().frame(minWidth: 44, minHeight: 44) }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(group.members.count) places", bundle: .module))
        .accessibilityHint("Zoom to these places")
    }
}

/// Expansion may use some of the padding when the full member bounds still fit.
func clusterCameraTarget(for group: ClusterGroup, expansionWidth: Double?) -> MKMapRect {
    let northwest = MKMapPoint(group.northwest.location)
    let southeast = MKMapPoint(group.southeast.location)
    let bounds = MKMapRect(x: northwest.x, y: northwest.y,
                           width: max(1, southeast.x - northwest.x),
                           height: max(1, southeast.y - northwest.y))
    let padded = bounds.insetBy(dx: -max(30, bounds.width * 0.15),
                               dy: -max(30, bounds.height * 0.15))
    guard let expansionWidth, expansionWidth < padded.width else { return padded }
    let height = padded.height * expansionWidth / padded.width
    guard expansionWidth >= max(60, bounds.width), height >= max(60, bounds.height) else { return padded }
    return MKMapRect(x: padded.midX - expansionWidth / 2, y: padded.midY - height / 2,
                     width: expansionWidth, height: height)
}

private extension Coordinate {
    var location: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}
