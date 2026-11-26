import MapClusteringCore
import SwiftUI

struct ClusteringDebugPanel: View {
    private enum Algorithm: String, CaseIterable {
        case supercluster = "Supercluster"
        case dbscan = "DBSCAN"
        case kMeans = "K-means"
        case off = "Off"
    }

    @Binding var scenario: TorontoScenario
    @Binding var itemCount: Int
    @Binding var showsRadius: Bool
    @Binding var showsStatistics: Bool
    let updateConfiguration: (ClusteringConfiguration) -> Void

    @State private var algorithm = Algorithm.supercluster
    @State private var radius = 40.0
    @State private var minimumPointCount = 2
    @State private var clusterCount = 12
    @State private var minimumClusterSize = 2
    @State private var minimumZoom = 0
    @State private var maximumZoom = 16
    @State private var tileExtent = 512
    @State private var leafSize = 64

    var body: some View {
        Form {
            Section("Map data") {
                Picker("Distribution", selection: $scenario) {
                    ForEach(TorontoScenario.allCases, id: \.self) { scenario in
                        Text(scenario.rawValue).tag(scenario)
                    }
                }
                Picker("Pins", selection: $itemCount) {
                    ForEach([100, 500, 1_000, 2_500, 5_000], id: \.self) { count in
                        Text(count, format: .number).tag(count)
                    }
                }
            }
            Section("Algorithm") {
                Picker("Method", selection: $algorithm) {
                    ForEach(Algorithm.allCases, id: \.self) { algorithm in
                        Text(algorithm.rawValue).tag(algorithm)
                    }
                }
                if algorithm == .supercluster || algorithm == .dbscan {
                    LabeledContent("Radius", value: "\(radius.formatted()) px")
                    Slider(value: $radius, in: 5...160, step: 5) {
                        Text("Radius")
                    }
                    Stepper("Minimum points: \(minimumPointCount)", value: $minimumPointCount, in: 2...50)
                    Stepper("Index leaf size: \(leafSize)", value: $leafSize, in: 16...128, step: 8)
                }
                if algorithm == .kMeans {
                    Stepper("Clusters: \(clusterCount)", value: $clusterCount, in: 1...64)
                    Stepper("Minimum cluster size: \(minimumClusterSize)", value: $minimumClusterSize, in: 2...50)
                }
                if algorithm != .off {
                    Stepper("Minimum zoom: \(minimumZoom)", value: $minimumZoom, in: 0...maximumZoom)
                    Stepper("Maximum zoom: \(maximumZoom)", value: $maximumZoom, in: minimumZoom...22)
                    Picker("Tile extent", selection: $tileExtent) {
                        ForEach([256, 512, 1024], id: \.self) { extent in
                            Text(extent, format: .number).tag(extent)
                        }
                    }
                }
            }
            Section("Overlays") {
                Toggle("Show pin and cluster radii", isOn: $showsRadius)
                    .disabled(algorithm == .off || algorithm == .kMeans)
                Toggle("Show map statistics", isOn: $showsStatistics)
            }
        }
        .onChange(of: configuration) { _, configuration in
            updateConfiguration(configuration)
        }
    }

    private var configuration: ClusteringConfiguration {
        let method: ClusteringAlgorithm
        switch algorithm {
        case .supercluster:
            method = .supercluster(radius: radius, minimumPointCount: minimumPointCount)
        case .dbscan:
            method = .dbscan(radius: radius, minimumPointCount: minimumPointCount)
        case .kMeans:
            method = .kMeans(clusterCount: clusterCount, minimumClusterSize: minimumClusterSize)
        case .off:
            method = .off
        }
        return ClusteringConfiguration(
            algorithm: method,
            zoomRange: minimumZoom...maximumZoom,
            tileExtent: tileExtent,
            spatialIndexLeafSize: leafSize
        )
    }
}
