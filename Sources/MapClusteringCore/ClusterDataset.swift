import Foundation

/// A reusable spatial dataset. Actor isolation keeps membership work off the main actor.
public actor ClusterDataset {
    public typealias EventSink = @Sendable (ClusteringEvent) -> Void
    private var coordinates: [Coordinate]
    private var points: [ProjectedPoint] = []
    private var base: [ClusterGroup]?
    private var cachedConfiguration: ClusteringConfiguration?
    private var hierarchy: [Int: [ClusterGroup]] = [:]
    private var partitions: [Int: [ClusterGroup]] = [:]
    private var recent: [Int] = []
    private var index: SpatialIndex?
    private let onEvent: EventSink?

    public init(coordinates: [Coordinate], onEvent: EventSink? = nil) {
        self.coordinates = coordinates
        self.onEvent = onEvent
    }

    /// Retrieves global membership at an integer zoom. Repeated pans reuse this result.
    public func groups(atZoom zoom: Int, configuration: ClusteringConfiguration) throws -> [ClusterGroup] {
        if base == nil { try project(zoom: zoom, configuration: configuration) }
        try Task.checkCancellation()
        guard let base else { return [] }
        if cachedConfiguration != configuration {
            cachedConfiguration = configuration
            hierarchy.removeAll()
            partitions.removeAll()
            recent.removeAll()
            index = nil
        }
        let level = max(configuration.lowerZoom, zoom)
        guard level <= configuration.upperZoom, configuration.algorithm != .off else { return base }
        let start = onEvent != nil ? ContinuousClock.now : nil
        do {
            let groups = try partition(base, level: level, configuration: configuration)
            report(.membership, start, configuration, zoom, base.count, groups.count)
            return groups
        } catch {
            report(.membership, start, configuration, zoom, base.count, 0, cancelled: true)
            throw error
        }
    }

    private func project(zoom: Int, configuration: ClusteringConfiguration) throws {
        let start = onEvent != nil ? ContinuousClock.now : nil
        let inputCount = coordinates.count
        do {
            try Task.checkCancellation()
            var projected: [ProjectedPoint] = []
            var singletons: [ClusterGroup] = []
            projected.reserveCapacity(inputCount)
            singletons.reserveCapacity(inputCount)
            for (i, coordinate) in coordinates.enumerated() {
                if i.isMultiple(of: 256) { try Task.checkCancellation() }
                projected.append(ProjectedPoint(coordinate))
                if coordinate.latitude.isFinite && coordinate.longitude.isFinite {
                    singletons.append(ClusterGroup([i], points: projected))
                }
            }
            try Task.checkCancellation()
            points = projected
            base = singletons
            coordinates.removeAll()
            report(.projection, start, configuration, zoom, inputCount, singletons.count)
        } catch {
            report(.projection, start, configuration, zoom, inputCount, 0, cancelled: error is CancellationError)
            throw error
        }
    }

    private func partition(_ base: [ClusterGroup], level: Int, configuration: ClusteringConfiguration) throws -> [ClusterGroup] {
        func projectedRadius(_ radius: Double, at zoom: Int) -> Double {
            max(0, radius) / (Double(max(1, configuration.tileExtent)) * exp2(Double(zoom)))
        }
        if case let .supercluster(radius, minimumPointCount) = configuration.algorithm {
            var groups = base
            for z in stride(from: configuration.upperZoom, through: level, by: -1) {
                try Task.checkCancellation()
                if let cached = hierarchy[z] { groups = cached; continue }
                groups = try SuperclusterClustering().merge(groups, points: points, radius: projectedRadius(radius, at: z), minimumPointCount: minimumPointCount, leafSize: configuration.spatialIndexLeafSize, zoom: z)
                hierarchy[z] = groups
            }
            return groups
        }
        let key: Int
        if case .dbscan = configuration.algorithm { key = level } else { key = -1 }
        if let cached = partitions[key] {
            markRecentlyUsed(key)
            return cached
        }
        let positions = base.map(\.point)
        let membership: [[Int]]
        let minimumSize: Int
        switch configuration.algorithm {
        case let .dbscan(radius, minimumPointCount):
            minimumSize = max(2, minimumPointCount)
            if index == nil { index = try SpatialIndex(positions, leafSize: configuration.spatialIndexLeafSize) }
            membership = try DBSCANClustering().groups(in: index!, radius: projectedRadius(radius, at: level), minimum: minimumSize)
        case let .kMeans(k, minimumClusterSize):
            minimumSize = max(2, minimumClusterSize)
            membership = try KMeansClustering(k: k).groups(for: positions)
        default: return base
        }
        var result: [ClusterGroup] = []
        for members in membership {
            try Task.checkCancellation()
            if members.count < minimumSize {
                result.append(contentsOf: members.map { base[$0] })
            } else {
                result.append(ClusterGroup(members.map { base[$0].id }, points: points))
            }
        }
        partitions[key] = result
        markRecentlyUsed(key)
        if recent.count > 4 { partitions.removeValue(forKey: recent.removeFirst()) }
        return result
    }

    private func markRecentlyUsed(_ key: Int) {
        recent.removeAll { $0 == key }
        recent.append(key)
    }

    private func report(_ stage: ClusteringEvent.Stage, _ start: ContinuousClock.Instant?,
                        _ configuration: ClusteringConfiguration, _ zoom: Int, _ inputs: Int, _ outputs: Int,
                        cancelled: Bool = false) {
        guard let start else { return }
        onEvent?(.init(stage: stage, algorithm: configuration.algorithm, zoom: zoom, inputs: inputs,
                    outputs: outputs, elapsed: start.duration(to: .now), cancelled: cancelled))
    }

    /// Filters centers in normalized Mercator space. X bounds may cross a world edge.
    public func visibleGroups(in groups: [ClusterGroup], xRange x: Range<Double>, yRange y: Range<Double>,
                        zoom: Int, configuration: ClusteringConfiguration) throws -> [ClusterGroup] {
        let start = onEvent != nil ? ContinuousClock.now : nil
        let width = x.upperBound - x.lowerBound
        var visible: [ClusterGroup] = []
        defer { report(.query, start, configuration, zoom, groups.count, visible.count, cancelled: Task.isCancelled) }
        for (i, group) in groups.enumerated() {
            if i.isMultiple(of: 256) { try Task.checkCancellation() }
            let offset = group.point.x - x.lowerBound
            if y.contains(group.point.y) && offset - floor(offset) < width { visible.append(group) }
        }
        return visible
    }
}
