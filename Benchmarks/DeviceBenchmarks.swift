import XCTest
import MapClusteringCore
import os

/// Select an individual method on a physical iOS device for an approved run.
final class DeviceBenchmarks: XCTestCase {
    func testSupercluster50k() throws { try measureDataset(50_000, .supercluster) }
    func testSupercluster100k() throws { try measureDataset(100_000, .supercluster) }
    func testDBSCAN50k() throws { try measureDataset(50_000, .dbscan) }
    func testDBSCAN100k() throws { try measureDataset(100_000, .dbscan) }
    func testKMeans50k() throws { try measureDataset(50_000, .kMeans(k: 8)) }
    func testKMeans100k() throws { try measureDataset(100_000, .kMeans(k: 8)) }
    func testDenseDBSCAN50k() throws { try measureDataset(50_000, .dbscan, dense: true) }
    func testDenseDBSCAN100k() throws { try measureDataset(100_000, .dbscan, dense: true) }

    private func measureDataset(_ count: Int, _ algorithm: ClusteringAlgorithm, dense: Bool = false) throws {
        #if !os(iOS) || targetEnvironment(simulator)
        throw XCTSkip("Select a physical iOS device for performance measurements.")
        #else
        guard ProcessInfo.processInfo.environment["MAP_CLUSTERING_BENCHMARK"] == "1" else {
            throw XCTSkip("Set MAP_CLUSTERING_BENCHMARK=1 for an approved benchmark.")
        }
        let points = (0..<count).map { i in
            if dense {
                if i == count - 1 { return Coordinate(latitude: 0, longitude: 0) }
                return Coordinate(latitude: 43.65 + Double(i % 400) * 0.000_000_1,
                                  longitude: -79.38 + Double(i / 400) * 0.000_000_1)
            }
            return Coordinate(latitude: 43.5 + Double(i * 7_919 % 100_003) / 200_000,
                              longitude: -79.7 + Double(i * 17_389 % 100_019) / 150_000)
        }
        var settings = ClusteringOptions()
        settings.algorithm = algorithm
        let options = settings
        let log = OSLog(subsystem: "MapClustering", category: .pointsOfInterest)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let done = expectation(description: "Membership and viewport queries")
            let task = Task {
                defer { done.fulfill() }
                let data = ClusterDataset(points)
                do {
                    os_signpost(.begin, log: log, name: "Cold membership")
                    let groups = try await data.groups(at: 13, options: options)
                    os_signpost(.end, log: log, name: "Cold membership")
                    for i in 0..<25 {
                        let x = 0.279 + Double(i) * 0.00001
                        os_signpost(.begin, log: log, name: "Warm query")
                        _ = try await data.visible(groups, x: x..<x+0.001, y: 0.364..<0.366,
                                                   zoom: 13, options: options)
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
