import MapKit
import SwiftUI
import MapClusteringCore

struct ClusterButton<Badge: View>: View {
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
        .accessibilityLabel(Text("\(group.count) places", bundle: .module))
        .accessibilityHint("Zoom to these places")
    }
}
