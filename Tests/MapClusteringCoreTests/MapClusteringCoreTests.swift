import Testing
@testable import MapClusteringCore

private let algorithms: [ClusteringAlgorithm] = [.supercluster(), .dbscan(), .kMeans(clusterCount: 2), .off]

@Test(arguments: algorithms)
func membershipConservesInput(_ algorithm: ClusteringAlgorithm) async throws {
    let point = Coordinate(latitude: 43.65, longitude: -79.38)
    let coordinates = [point, Coordinate(latitude: .nan, longitude: 0), point, Coordinate(latitude: 0, longitude: 0)]
    let configuration = ClusteringConfiguration(algorithm: algorithm)
    let data = ClusterDataset(coordinates: coordinates)
    let groups = try await data.groups(atZoom: 12, configuration: configuration)
    #expect(groups.flatMap(\.memberIndices).sorted() == [0, 2, 3])
    #expect(groups.count == (algorithm == .off ? 3 : 2))
    let again = try await data.groups(atZoom: 12, configuration: configuration)
    #expect(groups.map(\.memberIndices) == again.map(\.memberIndices))
    let fine = try await data.groups(atZoom: 17, configuration: configuration)
    #expect(fine.count == 3)
}

@Test(arguments: algorithms)
func emptyAndSingle(_ algorithm: ClusteringAlgorithm) async throws {
    let configuration = ClusteringConfiguration(algorithm: algorithm)
    let empty = try await ClusterDataset(coordinates: []).groups(atZoom: 0, configuration: configuration)
    #expect(empty.isEmpty)
    let single = try await ClusterDataset(coordinates: [.init(latitude: 90, longitude: 180)]).groups(atZoom: 0, configuration: configuration)
    #expect(single.count == 1)
    #expect(single.first?.coordinate.longitude == -180)
}

@Test func densityChainAndNoise() async throws {
    let input = [0.0, 0.2, 0.4, 30].map { Coordinate(latitude: 0, longitude: $0) }
    let configuration = ClusteringConfiguration(algorithm: .dbscan(radius: 0.3 * 512 / 360, minimumPointCount: 3))
    let groups = try await ClusterDataset(coordinates: input).groups(atZoom: 0, configuration: configuration)
    #expect(groups.map { $0.memberIndices.sorted() } == [[0, 1, 2], [3]])
}

@Test func denseDBSCANWithUnassignedNoise() async throws {
    let center = Coordinate(latitude: 43.65, longitude: -79.38)
    let hotspot = (0..<50_000).map { index in
        Coordinate(latitude: center.latitude + Double(index % 250) * 0.000_000_1,
                   longitude: center.longitude + Double(index / 250) * 0.000_000_1)
    }
    let data = ClusterDataset(coordinates: hotspot + [Coordinate(latitude: 0, longitude: 0)])
    let configuration = ClusteringConfiguration(algorithm: .dbscan())
    let groups = try await data.groups(atZoom: 13, configuration: configuration)
    #expect(groups.count == 2)
    #expect(groups.first?.memberIndices.sorted() == Array(hotspot.indices))
    #expect(groups.last?.memberIndices == [hotspot.count])
}

@Test func sharedDBSCANBorderJoinsFirstReachingCluster() throws {
    let points = [
        ProjectedPoint(x: 0.50, y: 0.50), // Border point, encountered before either core.
        ProjectedPoint(x: 0.41, y: 0.50),
        ProjectedPoint(x: 0.35, y: 0.51),
        ProjectedPoint(x: 0.35, y: 0.50),
        ProjectedPoint(x: 0.35, y: 0.49),
        ProjectedPoint(x: 0.59, y: 0.50),
        ProjectedPoint(x: 0.65, y: 0.51),
        ProjectedPoint(x: 0.65, y: 0.50),
        ProjectedPoint(x: 0.65, y: 0.49)
    ]
    let tree = try SpatialIndex(points, leafSize: 2)
    let groups = try DBSCANClustering().groups(in: tree, radius: 0.1, minimum: 4)
    #expect(groups.map { $0.sorted() } == [[0, 1, 2, 3, 4], [5, 6, 7, 8]])
}

@Test func seamViewport() async throws {
    let data = ClusterDataset(coordinates: [-179.0, 0, 179].map { Coordinate(latitude: 0, longitude: $0) })
    let groups = try await data.groups(atZoom: 20, configuration: .init())
    let visible = try await data.visibleGroups(in: groups, xRange: 0.99..<1.01, yRange: 0.49..<0.51, zoom: 20, configuration: .init())
    #expect(visible.map(\.id) == [0, 2])
}

@Test func oversizedKAndZoomCap() async throws {
    var configuration = ClusteringConfiguration(algorithm: .kMeans(clusterCount: 4))
    let point = Coordinate(latitude: 0, longitude: 0)
    let data = ClusterDataset(coordinates: [point, point])
    let singles = try await data.groups(atZoom: 10, configuration: configuration)
    #expect(singles.count == 2)
    configuration.zoomRange = 0...100
    configuration.algorithm = .supercluster()
    let lastLevel = try await data.groups(atZoom: 30, configuration: configuration)
    #expect(lastLevel.first?.expansionZoom == 31)
    let leaves = try await data.groups(atZoom: 31, configuration: configuration)
    #expect(leaves.count == 2)
}

@Test func eventHandlerReceivesTimingForEachStage() async throws {
    let (events, stream) = AsyncStream<ClusteringEvent>.makeStream()
    let data = ClusterDataset(coordinates: [.init(latitude: 0, longitude: 0)]) { stream.yield($0) }
    let configuration = ClusteringConfiguration()
    let groups = try await data.groups(atZoom: 3, configuration: configuration)
    _ = try await data.visibleGroups(in: groups, xRange: 0..<1, yRange: 0..<1, zoom: 3, configuration: configuration)
    stream.finish()
    var stages: [String] = []
    for await event in events {
        #expect(event.zoom == 3)
        #expect(event.inputs == 1)
        stages.append(event.stage.rawValue)
    }
    #expect(stages == ["projection", "membership", "query"])
}

@Test func cancelledProjectionReportsAndSuccessfullyRetries() async throws {
    let (events, stream) = AsyncStream<ClusteringEvent>.makeStream()
    let data = ClusterDataset(coordinates: [.init(latitude: 0, longitude: 0)]) { stream.yield($0) }
    let configuration = ClusteringConfiguration(algorithm: .off)

    let cancelled = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await data.groups(atZoom: 10, configuration: configuration)
    }
    await #expect(throws: CancellationError.self) { try await cancelled.value }
    let groups = try await data.groups(atZoom: 10, configuration: configuration)
    #expect(groups.count == 1)
    stream.finish()

    var diagnostics: [ClusteringEvent] = []
    for await event in events { diagnostics.append(event) }
    #expect(diagnostics.map(\.stage.rawValue) == ["projection", "projection"])
    #expect(diagnostics.map(\.cancelled) == [true, false])
    #expect(diagnostics.map(\.outputs) == [0, 1])
}
