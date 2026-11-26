import MapKit
import Testing
import MapClusteringCore
@testable import MapClustering

private actor Gate {
    private var release: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?

    func hold() async {
        await withCheckedContinuation {
            release = $0
            arrival?.resume()
            arrival = nil
        }
    }

    func waitForArrival() async {
        if release == nil { await withCheckedContinuation { arrival = $0 } }
    }

    func open() { release?.resume(); release = nil }
}

@MainActor @Test func newerOffRequestWins() async {
    struct Place: Identifiable {
        let id: Int
        var coordinate: CLLocationCoordinate2D { .init(latitude: 43.65, longitude: -79.38) }
    }
    var options = ClusteringOptions()
    options.algorithm = .dbscan
    let controller = ClusterController<Place>(coordinate: \.coordinate, options: options)
    let gate = Gate()
    controller.loadMembership = { data, zoom, settings in
        if settings.algorithm == .dbscan {
            await gate.hold()
            // Deliberately finish successfully even though the request was cancelled.
            return []
        }
        return try await data.groups(at: zoom, options: settings)
    }
    controller.replaceItems((0..<5000).map(Place.init))
    controller.update(width: 400)
    controller.update(rect: .world)
    await gate.waitForArrival()
    let stale = controller.membership
    options.algorithm = .off
    controller.configure(options)
    controller.replaceItems((0..<100).map(Place.init))
    await controller.waitForPublication()
    await gate.open()
    await stale?.value
    #expect(controller.groups.count == 100)
    #expect(controller.visiblePins == 100)
}

@Test func clusterCameraKeepsMembersInFrame() async throws {
    let dataset = ClusterDataset([
        .init(latitude: 43.65, longitude: -79.39),
        .init(latitude: 43.63, longitude: -79.37)
    ])
    var options = ClusteringOptions()
    options.algorithm = .kMeans(k: 1)
    let groups = try await dataset.groups(at: 12, options: options)
    let group = try #require(groups.first)
    let fitted = clusterCameraTarget(for: group, expansionWidth: nil)
    let croppedWidth = fitted.width * 0.5
    let target = clusterCameraTarget(for: group, expansionWidth: croppedWidth)
    #expect(target.minX == fitted.minX)
    #expect(target.minY == fitted.minY)
    #expect(target.width == fitted.width)
    #expect(target.height == fitted.height)

    let paddingOnlyWidth = fitted.width * 0.95
    let expanded = clusterCameraTarget(for: group, expansionWidth: paddingOnlyWidth)
    #expect(expanded.width == paddingOnlyWidth)
    #expect(abs(expanded.midX - fitted.midX) < 0.001)
    #expect(abs(expanded.midY - fitted.midY) < 0.001)
}
