import Foundation

/// A reusable spatial dataset. Actor isolation keeps membership work off the main actor.
public actor ClusterDataset {
    public typealias EventSink = @Sendable (ClusteringEvent) -> Void
    private var coordinates: [Coordinate]
    private var points: [ProjectedPoint] = []
    private var base: [ClusterGroup]?
    private var configuration: ClusteringOptions?
    private var hierarchy: [Int: [ClusterGroup]] = [:]
    private var partitions: [Int: [ClusterGroup]] = [:]
    private var recent: [Int] = []
    private var index: SpatialIndex?
    private let sink: EventSink?

    public init(_ coordinates: [Coordinate], sink: EventSink? = nil) {
        self.coordinates = coordinates
        self.sink = sink
    }

    /// Retrieves global membership at an integer zoom. Repeated pans reuse this result.
    public func groups(at zoom: Int, options: ClusteringOptions) throws -> [ClusterGroup] {
        if base == nil { try project(zoom: zoom, options: options) }
        try Task.checkCancellation()
        guard let base else { return [] }
        if configuration != options {
            configuration = options
            hierarchy.removeAll()
            partitions.removeAll()
            recent.removeAll()
            index = nil
        }
        let level = max(options.lowerZoom, zoom)
        guard level <= options.upperZoom, options.algorithm != .off else { return base }
        let start = options.log ? ContinuousClock.now : nil
        do {
            let groups = try partition(base, level: level, options: options)
            report(.membership, start, options, zoom, base.count, groups.count)
            return groups
        } catch {
            report(.membership, start, options, zoom, base.count, 0, cancelled: true)
            throw error
        }
    }

    private func project(zoom: Int, options: ClusteringOptions) throws {
        let start = options.log ? ContinuousClock.now : nil
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
            report(.projection, start, options, zoom, inputCount, singletons.count)
        } catch {
            report(.projection, start, options, zoom, inputCount, 0, cancelled: error is CancellationError)
            throw error
        }
    }

    private func partition(_ base: [ClusterGroup], level: Int, options: ClusteringOptions) throws -> [ClusterGroup] {
        func radius(_ zoom: Int) -> Double {
            max(0, options.radius) / (Double(max(1, options.extent)) * exp2(Double(zoom)))
        }
        if options.algorithm == .supercluster {
            var groups = base
            for z in stride(from: options.upperZoom, through: level, by: -1) {
                try Task.checkCancellation()
                if let cached = hierarchy[z] { groups = cached; continue }
                groups = try SuperclusterMembership().merge(groups, points: points, radius: radius(z), options: options, zoom: z)
                hierarchy[z] = groups
            }
            return groups
        }
        let key = options.algorithm == .dbscan ? level : -1
        if let cached = partitions[key] {
            markRecentlyUsed(key)
            return cached
        }
        let positions = base.map(\.point)
        let membership: [[Int]]
        switch options.algorithm {
        case .dbscan:
            if index == nil { index = try SpatialIndex(positions, leafSize: options.nodeSize) }
            membership = try DBSCANMembership().groups(in: index!, radius: radius(level), minimum: max(2, options.minPoints))
        case .kMeans(let k):
            membership = try KMeansMembership(k: k).groups(for: positions)
        default: return base
        }
        var result: [ClusterGroup] = []
        for members in membership {
            try Task.checkCancellation()
            if members.count < max(2, options.minPoints) {
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
                        _ options: ClusteringOptions, _ zoom: Int, _ inputs: Int, _ outputs: Int,
                        cancelled: Bool = false) {
        guard let start else { return }
        sink?(.init(stage: stage, algorithm: options.algorithm, zoom: zoom, inputs: inputs,
                    outputs: outputs, elapsed: start.duration(to: .now), cancelled: cancelled))
    }

    /// Filters centers in normalized Mercator space. X bounds may cross a world edge.
    public func visible(_ groups: [ClusterGroup], x: Range<Double>, y: Range<Double>,
                        zoom: Int, options: ClusteringOptions) throws -> [ClusterGroup] {
        let start = options.log ? ContinuousClock.now : nil
        let width = x.upperBound - x.lowerBound
        var visible: [ClusterGroup] = []
        defer { report(.query, start, options, zoom, groups.count, visible.count, cancelled: Task.isCancelled) }
        for (i, group) in groups.enumerated() {
            if i.isMultiple(of: 256) { try Task.checkCancellation() }
            let offset = group.point.x - x.lowerBound
            if y.contains(group.point.y) && offset - floor(offset) < width { visible.append(group) }
        }
        return visible
    }
}
