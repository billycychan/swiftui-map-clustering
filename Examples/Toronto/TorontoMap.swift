import MapClustering
import MapKit
import SwiftUI

struct TorontoMap: View {
    @State private var position = MapCameraPosition.region(Place.region)
    @State private var controller = ClusterController<Place>(coordinate: \.coordinate)

    var body: some View {
        Map(position: $position) {
            ClusteredAnnotations(controller, position: $position) { place in
                Marker(place.name, coordinate: place.coordinate)
            } cluster: { group in
                Text(group.members.count, format: .number)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.blue, in: .circle)
            }
        }
        .mapClustering(controller)
        .mapControls {
            #if os(macOS)
            MapZoomStepper()
            #endif
        }
        .task {
            controller.replaceItems(Place.fixture)
        }
    }
}
