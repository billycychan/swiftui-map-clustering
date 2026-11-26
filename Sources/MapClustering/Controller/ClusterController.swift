import MapKit
import Observation
import SwiftUI
import MapClusteringCore

/// Own one controller per Map. Replace its items when the caller's dataset changes.
@MainActor @Observable
public final class ClusterController<Item: Identifiable> {
    public var groups: [ClusterGroup] { presentation.groups }
    private(set) var presentation = ClusterPresentation()
    @_spi(Diagnostics) public var displayedZoom: Int? { presentation.zoom }
    @_spi(Diagnostics) public var displayedGroups: [ClusterGroup] { presentation.groups }

    public private(set) var visiblePinCount = 0
    public private(set) var visibleClusterCount = 0
    public var configuration: ClusteringConfiguration {
        didSet { if configuration != oldValue { reset() } }
    }
    private(set) var items: [Item] = []
    private let coordinate: KeyPath<Item, CLLocationCoordinate2D>
    private let onEvent: ClusterDataset.EventSink?
    typealias MembershipLoader = @Sendable (ClusterDataset, Int, ClusteringConfiguration) async throws -> [ClusterGroup]
    @ObservationIgnored var loadMembership: MembershipLoader = { dataset, zoom, configuration in
        try await dataset.groups(atZoom: zoom, configuration: configuration)
    }

    // Await the captured request in deterministic scheduling tests.
    func waitForPublication() async {
        await membership?.value
        await query?.value
    }

    @ObservationIgnored private var dataset: ClusterDataset
    @ObservationIgnored private(set) var membership: Task<Void, Never>?
    @ObservationIgnored private var query: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var viewportGeneration = 0
    @ObservationIgnored private var level: Int?
    @ObservationIgnored private var partition: [ClusterGroup]?
    @ObservationIgnored private var rect: MKMapRect?
    @ObservationIgnored private var width: Double = 0
    @ObservationIgnored var reduceMotion = false

    public init(items: [Item] = [], coordinate: KeyPath<Item, CLLocationCoordinate2D>, configuration: ClusteringConfiguration = .init(),
                onEvent: ClusterDataset.EventSink? = nil) {
        self.coordinate = coordinate
        self.configuration = configuration
        self.onEvent = onEvent
        self.items = items
        dataset = Self.makeDataset(items, coordinate: coordinate, onEvent: onEvent)
    }

    private static func makeDataset(_ items: [Item], coordinate: KeyPath<Item, CLLocationCoordinate2D>,
                                    onEvent: ClusterDataset.EventSink?) -> ClusterDataset {
        let coordinates = items.map { item in
            let c = item[keyPath: coordinate]
            return Coordinate(latitude: c.latitude, longitude: c.longitude)
        }
        return ClusterDataset(coordinates: coordinates, onEvent: onEvent)
    }

    public func replaceItems(with items: [Item]) {
        self.items = items
        dataset = Self.makeDataset(items, coordinate: coordinate, onEvent: onEvent)
        reset()
    }

    private func reset() {
        generation += 1
        revision += 1
        membership?.cancel()
        query?.cancel()
        presentation = ClusterPresentation(revision: revision)
        visiblePinCount = 0
        visibleClusterCount = 0
        partition = nil
        level = nil
        refresh()
    }

    func expansionWidth(for group: ClusterGroup) -> Double? {
        guard let zoom = group.expansionZoom, width > 0 else { return nil }
        return MKMapRect.world.width * width / Double(max(1, configuration.tileExtent)) / exp2(Double(zoom) + 0.15)
    }

    func update(rect: MKMapRect) { self.rect = rect; refresh() }
    func update(width: Double) { self.width = width; refresh() }

    private func refresh() {
        guard let rect, width > 0, rect.width > 0, rect.width.isFinite,
              rect.height.isFinite, rect.origin.x.isFinite, rect.origin.y.isFinite else { return }
        let world = MKMapRect.world.width
        let zoom = log2(width / (rect.width / world) / Double(max(1, configuration.tileExtent)))
        guard zoom.isFinite else { return }
        let next = Int(min(31, max(0, floor(zoom))))
        let hold = level.map { zoom >= Double($0) - 0.08 && zoom < Double($0 + 1) + 0.08 } ?? false
        if level == nil || (next != level && !hold) {
            membership?.cancel()
            query?.cancel()
            generation += 1
            let current = generation
            level = next
            partition = nil
            membership = Task { [weak self, dataset, configuration, loadMembership] in
                guard let output = try? await loadMembership(dataset, next, configuration),
                      let self, current == generation, !Task.isCancelled else { return }
                partition = output
                refresh()
            }
            return
        }
        guard let partition, let level else { return }
        query?.cancel()
        viewportGeneration += 1
        let request = viewportGeneration
        let current = generation
        let padded = rect.insetBy(dx: -rect.width * 0.2, dy: -rect.height * 0.2)
        query = Task { [weak self, dataset, configuration] in
            @MainActor func visible(in r: MKMapRect, _ input: [ClusterGroup]) async throws -> [ClusterGroup] {
                try await dataset.visibleGroups(in: input, xRange: r.minX/world..<r.maxX/world,
                                          yRange: r.minY/world..<r.maxY/world, zoom: level, configuration: configuration)
            }
            do {
                let rendered = configuration.algorithm == .off ? partition : try await visible(in: padded, partition)
                let visible = try await visible(in: rect, rendered)
                guard let self, request == viewportGeneration, current == generation, !Task.isCancelled else { return }
                let animation: Animation? = if let previousZoom = presentation.zoom,
                                                previousZoom != level, !reduceMotion {
                    .easeInOut(duration: 0.22)
                } else {
                    nil
                }
                withAnimation(animation) {
                    presentation = ClusterPresentation(groups: rendered, revision: revision, zoom: level)
                }
                visiblePinCount = visible.count { $0.count == 1 }
                visibleClusterCount = visible.count - visiblePinCount
            } catch { return }
        }
    }
}
