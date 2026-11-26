/// Membership strategy. Off mode returns every input point.
public enum ClusteringAlgorithm: Hashable, Sendable {
    case supercluster, dbscan, kMeans(k: Int), off
}

/// Membership and diagnostics settings. Radius is measured in logical tile pixels.
public struct ClusteringOptions: Hashable, Sendable {
    public var algorithm: ClusteringAlgorithm = .supercluster
    public var minZoom = 0
    public var maxZoom = 16
    public var minPoints = 2
    public var radius = 40.0
    public var extent = 512
    public var nodeSize = 64
    public var log = false

    public init() {}

    var upperZoom: Int { min(30, max(0, maxZoom)) }
    var lowerZoom: Int { min(upperZoom, max(0, minZoom)) }
}

/// Aggregated diagnostic. Contains no coordinates or identifiers.
public struct ClusteringEvent: Sendable {
    public enum Stage: String, Sendable { case projection, membership, query }
    public let stage: Stage
    public let algorithm: ClusteringAlgorithm
    public let zoom: Int
    public let inputs: Int
    public let outputs: Int
    public let elapsed: Duration
    public let cancelled: Bool
}
