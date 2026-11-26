import MapKit
import SwiftUI

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
