/// Settings for grouping points at integer map zoom levels.
public struct ClusteringConfiguration: Hashable, Sendable {
    public var algorithm: ClusteringAlgorithm
    /// Below the lower bound, reuse that level. Above the upper bound, show individual pins.
    public var zoomRange: ClosedRange<Int>
    /// Logical tile width used to scale radius and compute zoom.
    public var tileExtent: Int
    /// Maximum leaf size for the spatial index used by Supercluster and DBSCAN.
    public var spatialIndexLeafSize: Int

    public init(algorithm: ClusteringAlgorithm = .supercluster(),
                zoomRange: ClosedRange<Int> = 0...16, tileExtent: Int = 512,
                spatialIndexLeafSize: Int = 64) {
        self.algorithm = algorithm
        self.zoomRange = zoomRange
        self.tileExtent = tileExtent
        self.spatialIndexLeafSize = spatialIndexLeafSize
    }

    var upperZoom: Int { min(30, max(0, zoomRange.upperBound)) }
    var lowerZoom: Int { min(upperZoom, max(0, zoomRange.lowerBound)) }
}
