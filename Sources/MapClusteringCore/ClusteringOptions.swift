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
