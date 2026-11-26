import XCTest
import MapClusteringCore
import os

/// Select an individual method on a physical iOS device for an approved run.
final class DeviceBenchmarks: XCTestCase {
    private enum Distribution {
        case sparseEven, sparseUneven, denseEven, denseUneven

        var span: Double {
            switch self {
            case .sparseEven, .sparseUneven: 0.5
            case .denseEven, .denseUneven: 0.01
            }
        }

        var hasHotspot: Bool { self == .sparseUneven || self == .denseUneven }
    }

    func testSupercluster50kSparseEven() throws {
        try measureDataset(50_000, .supercluster(), distribution: .sparseEven)
    }

    func testSupercluster50kSparseUneven() throws {
        try measureDataset(50_000, .supercluster(), distribution: .sparseUneven)
    }

    func testSupercluster50kDenseEven() throws {
        try measureDataset(50_000, .supercluster(), distribution: .denseEven)
    }

    func testSupercluster50kDenseUneven() throws {
        try measureDataset(50_000, .supercluster(), distribution: .denseUneven)
    }

    func testSupercluster100kSparseEven() throws {
        try measureDataset(100_000, .supercluster(), distribution: .sparseEven)
    }

    func testSupercluster100kSparseUneven() throws {
        try measureDataset(100_000, .supercluster(), distribution: .sparseUneven)
    }

    func testSupercluster100kDenseEven() throws {
        try measureDataset(100_000, .supercluster(), distribution: .denseEven)
    }

    func testSupercluster100kDenseUneven() throws {
        try measureDataset(100_000, .supercluster(), distribution: .denseUneven)
    }

    func testDBSCAN50kSparseEven() throws {
        try measureDataset(50_000, .dbscan(), distribution: .sparseEven)
    }

    func testDBSCAN50kSparseUneven() throws {
        try measureDataset(50_000, .dbscan(), distribution: .sparseUneven)
    }

    func testDBSCAN50kDenseEven() throws {
        try measureDataset(50_000, .dbscan(), distribution: .denseEven)
    }

    func testDBSCAN50kDenseUneven() throws {
        try measureDataset(50_000, .dbscan(), distribution: .denseUneven)
    }

    func testDBSCAN100kSparseEven() throws {
        try measureDataset(100_000, .dbscan(), distribution: .sparseEven)
    }

    func testDBSCAN100kSparseUneven() throws {
        try measureDataset(100_000, .dbscan(), distribution: .sparseUneven)
    }

    func testDBSCAN100kDenseEven() throws {
        try measureDataset(100_000, .dbscan(), distribution: .denseEven)
    }

    func testDBSCAN100kDenseUneven() throws {
        try measureDataset(100_000, .dbscan(), distribution: .denseUneven)
    }

    func testKMeans50kSparseEven() throws {
        try measureDataset(50_000, .kMeans(clusterCount: 8), distribution: .sparseEven)
    }

    func testKMeans50kSparseUneven() throws {
        try measureDataset(50_000, .kMeans(clusterCount: 8), distribution: .sparseUneven)
    }

    func testKMeans50kDenseEven() throws {
        try measureDataset(50_000, .kMeans(clusterCount: 8), distribution: .denseEven)
    }

    func testKMeans50kDenseUneven() throws {
        try measureDataset(50_000, .kMeans(clusterCount: 8), distribution: .denseUneven)
    }

    func testKMeans100kSparseEven() throws {
        try measureDataset(100_000, .kMeans(clusterCount: 8), distribution: .sparseEven)
    }

    func testKMeans100kSparseUneven() throws {
        try measureDataset(100_000, .kMeans(clusterCount: 8), distribution: .sparseUneven)
    }

    func testKMeans100kDenseEven() throws {
        try measureDataset(100_000, .kMeans(clusterCount: 8), distribution: .denseEven)
    }

    func testKMeans100kDenseUneven() throws {
        try measureDataset(100_000, .kMeans(clusterCount: 8), distribution: .denseUneven)
    }

    private func measureDataset(_ count: Int, _ algorithm: ClusteringAlgorithm, distribution: Distribution) throws {
        #if !os(iOS) || targetEnvironment(simulator)
        throw XCTSkip("Select a physical iOS device for performance measurements.")
        #else
        guard ProcessInfo.processInfo.environment["MAP_CLUSTERING_BENCHMARK"] == "1" else {
            throw XCTSkip("Set MAP_CLUSTERING_BENCHMARK=1 for an approved benchmark.")
        }
        let points = (0..<count).map { index in
            let x = Double(index * 7_919 % 100_003) / 100_003 - 0.5
            let y = Double(index * 17_389 % 100_019) / 100_019 - 0.5
            // Place 80% of uneven fixtures in a hotspot with one fifth the width.
            let span = distribution.span * (distribution.hasHotspot && index % 5 != 0 ? 0.2 : 1)
            return Coordinate(latitude: 43.65 + x * span, longitude: -79.38 + y * span)
        }
        let configuration = ClusteringConfiguration(algorithm: algorithm)
        let log = OSLog(subsystem: "MapClustering", category: .pointsOfInterest)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let done = expectation(description: "Membership and viewport queries")
            let task = Task {
                defer { done.fulfill() }
                let data = ClusterDataset(coordinates: points)
                do {
                    os_signpost(.begin, log: log, name: "Cold membership")
                    let groups = try await data.groups(atZoom: 13, configuration: configuration)
                    os_signpost(.end, log: log, name: "Cold membership")
                    for i in 0..<25 {
                        let x = 0.279 + Double(i) * 0.00001
                        os_signpost(.begin, log: log, name: "Warm query")
                        _ = try await data.visibleGroups(in: groups, xRange: x..<x+0.001, yRange: 0.364..<0.366,
                                                   zoom: 13, configuration: configuration)
                        os_signpost(.end, log: log, name: "Warm query")
                    }
                } catch { XCTFail(String(describing: error)) }
            }
            wait(for: [done], timeout: 300)
            task.cancel()
        }
        #endif
    }
}
