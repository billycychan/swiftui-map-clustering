@_spi(Diagnostics) import MapClustering
import MapKit
import SwiftUI

struct TorontoMap: View {
    @Namespace private var mapScope
    @State private var showsDebugPanel = false
    @State private var showsRadius = false
    @State private var showsStatistics = false
    @State private var itemCount = 100
    @State private var scenario = TorontoScenario.downtown
    @State private var position = MapCameraPosition.region(TorontoScenario.downtown.region)
    @State private var selection: Place.ID?
    @State private var controller = ClusterController(items: TorontoScenario.downtown.makePlaces(), coordinate: \.coordinate)

    var body: some View {
        Map(position: $position, selection: $selection, scope: mapScope) {
            if showsRadius, let radius = projectedRadius {
                ForEach(controller.displayedGroups) { group in
                    let center = CLLocationCoordinate2D(
                        latitude: group.coordinate.latitude,
                        longitude: group.coordinate.longitude
                    )
                    MapCircle(
                        center: center,
                        radius: radius * MKMetersPerMapPointAtLatitude(center.latitude)
                    )
                    .foregroundStyle(.clear)
                    .stroke(.orange.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            ClusteredAnnotations(controller, position: $position) { place in
                Marker(place.name, coordinate: place.coordinate)
            }
        }
        .mapClustering(controller)
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .safeAreaInset(edge: .bottom) {
            if showsStatistics {
                VStack {
                    if let zoom = controller.displayedZoom {
                        Text("Clustering zoom: \(zoom)")
                    }
                    Text("\(controller.visiblePinCount) visible pins · \(controller.visibleClusterCount) clusters")
                    if showsRadius, projectedRadius != nil {
                        Text("Dashed rings show search radius at this zoom")
                    }
                }
                .font(.footnote)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .onChange(of: scenario) {
            replacePlaces()
            position = .region(scenario.region)
        }
        .onChange(of: itemCount) {
            replacePlaces()
        }
        .mapControls {}
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Button {
                    showsDebugPanel = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clustering Debug")
                .help("Clustering Debug")

                #if os(macOS)
                MapZoomStepper(scope: mapScope)
                #endif
            }
            .padding(12)
        }
        .sheet(isPresented: $showsDebugPanel) {
            NavigationStack {
                ClusteringDebugPanel(
                    scenario: $scenario,
                    itemCount: $itemCount,
                    showsRadius: $showsRadius,
                    showsStatistics: $showsStatistics
                ) { configuration in
                    controller.configuration = configuration
                }
                .navigationTitle("Clustering Debug")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showsDebugPanel = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var projectedRadius: Double? {
        let configuration = controller.configuration
        guard let zoom = controller.displayedZoom, zoom <= configuration.zoomRange.upperBound else {
            return nil
        }
        let radius: Double
        switch configuration.algorithm {
        case .supercluster(let value, _), .dbscan(let value, _):
            radius = value
        case .off, .kMeans:
            return nil
        }

        let effectiveZoom = max(zoom, configuration.zoomRange.lowerBound)
        return MKMapRect.world.width * radius
            / (Double(configuration.tileExtent) * exp2(Double(effectiveZoom)))
    }

    private func replacePlaces() {
        selection = nil
        controller.replaceItems(with: scenario.makePlaces(count: itemCount))
    }
}
