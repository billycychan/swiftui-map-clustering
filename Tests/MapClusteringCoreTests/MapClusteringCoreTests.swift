import Testing
@testable import MapClusteringCore

private let algorithms: [ClusteringAlgorithm] = [.supercluster, .dbscan, .kMeans(k: 2), .off]

@Test(arguments: algorithms)
func membershipConservesInput(_ algorithm: ClusteringAlgorithm) async throws {
    let point = Coordinate(latitude: 43.65, longitude: -79.38)
    let coordinates = [point, point, Coordinate(latitude: 0, longitude: 0)]
    var options = ClusteringOptions()
    options.algorithm = algorithm
    let data = ClusterDataset(coordinates)
    let groups = try await data.groups(at: 12, options: options)
    #expect(groups.flatMap(\.members).sorted() == [0, 1, 2])
    #expect(groups.count == (algorithm == .off ? 3 : 2))
    let again = try await data.groups(at: 12, options: options)
    #expect(groups.map(\.members) == again.map(\.members))
    let fine = try await data.groups(at: 17, options: options)
    #expect(fine.count == 3)
}

@Test(arguments: algorithms)
func emptyAndSingle(_ algorithm: ClusteringAlgorithm) async throws {
    var options = ClusteringOptions()
    options.algorithm = algorithm
    let empty = try await ClusterDataset([]).groups(at: 0, options: options)
    #expect(empty.isEmpty)
    let single = try await ClusterDataset([.init(latitude: 90, longitude: 180)]).groups(at: 0, options: options)
    #expect(single.count == 1)
    #expect(single.first?.coordinate.longitude == -180)
}

@Test func densityChainAndNoise() async throws {
    let input = [0.0, 0.2, 0.4, 30].map { Coordinate(latitude: 0, longitude: $0) }
    var options = ClusteringOptions()
    options.algorithm = .dbscan
    options.minPoints = 3
    options.radius = 0.3 * 512 / 360
    let groups = try await ClusterDataset(input).groups(at: 0, options: options)
    #expect(groups.map { $0.members.sorted() } == [[0, 1, 2], [3]])
}

@Test func denseDBSCANWithUnassignedNoise() async throws {
    let center = Coordinate(latitude: 43.65, longitude: -79.38)
    let hotspot = (0..<50_000).map { index in
        Coordinate(latitude: center.latitude + Double(index % 250) * 0.000_000_1,
                   longitude: center.longitude + Double(index / 250) * 0.000_000_1)
    }
    let data = ClusterDataset(hotspot + [Coordinate(latitude: 0, longitude: 0)])
    var options = ClusteringOptions()
    options.algorithm = .dbscan
    let groups = try await data.groups(at: 13, options: options)
    #expect(groups.count == 2)
    #expect(groups.first?.members.sorted() == Array(hotspot.indices))
    #expect(groups.last?.members == [hotspot.count])
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
    let groups = try DBSCANMembership().groups(in: tree, radius: 0.1, minimum: 4)
    #expect(groups.map { $0.sorted() } == [[0, 1, 2, 3, 4], [5, 6, 7, 8]])
}

@Test func seamViewport() async throws {
    let data = ClusterDataset([-179.0, 0, 179].map { Coordinate(latitude: 0, longitude: $0) })
    let groups = try await data.groups(at: 20, options: .init())
    let visible = try await data.visible(groups, x: 0.99..<1.01, y: 0.49..<0.51, zoom: 20, options: .init())
    #expect(visible.map(\.id) == [0, 2])
}

@Test func oversizedKAndZoomCap() async throws {
    var options = ClusteringOptions()
    options.algorithm = .kMeans(k: 4)
    let point = Coordinate(latitude: 0, longitude: 0)
    let data = ClusterDataset([point, point])
    let singles = try await data.groups(at: 10, options: options)
    #expect(singles.count == 2)
    options.maxZoom = 100
    options.algorithm = .supercluster
    let lastLevel = try await data.groups(at: 30, options: options)
    #expect(lastLevel.first?.expansionZoom == 31)
    let leaves = try await data.groups(at: 31, options: options)
    #expect(leaves.count == 2)
}

@Test func timingEventsAreOptIn() async throws {
    let (events, stream) = AsyncStream<ClusteringEvent>.makeStream()
    let data = ClusterDataset([.init(latitude: 0, longitude: 0)]) { stream.yield($0) }
    var options = ClusteringOptions()
    _ = try await data.groups(at: 2, options: options)
    options.log = true
    let groups = try await data.groups(at: 3, options: options)
    _ = try await data.visible(groups, x: 0..<1, y: 0..<1, zoom: 3, options: options)
    stream.finish()
    var stages: [String] = []
    for await event in events {
        #expect(event.zoom == 3)
        #expect(event.inputs == 1)
        stages.append(event.stage.rawValue)
    }
    #expect(stages == ["membership", "query"])
}

@Test func cancelledProjectionReportsAndSuccessfullyRetries() async throws {
    let (events, stream) = AsyncStream<ClusteringEvent>.makeStream()
    let data = ClusterDataset([.init(latitude: 0, longitude: 0)]) { stream.yield($0) }
    var settings = ClusteringOptions()
    settings.algorithm = .off
    settings.log = true
    let options = settings

    let cancelled = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await data.groups(at: 10, options: options)
    }
    await #expect(throws: CancellationError.self) { try await cancelled.value }
    let groups = try await data.groups(at: 10, options: options)
    #expect(groups.count == 1)
    stream.finish()

    var diagnostics: [ClusteringEvent] = []
    for await event in events { diagnostics.append(event) }
    #expect(diagnostics.map(\.stage.rawValue) == ["projection", "projection"])
    #expect(diagnostics.map(\.cancelled) == [true, false])
    #expect(diagnostics.map(\.outputs) == [0, 1])
}
