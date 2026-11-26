/// How the dataset groups projected coordinates.
public enum ClusteringAlgorithm: Hashable, Sendable {
    /// Merge nearby groups at each zoom level. Radius is measured in logical tile pixels.
    case supercluster(radius: Double = 40, minimumPointCount: Int = 2)
    /// Expand dense neighborhoods within the tile-pixel radius. Each point counts itself.
    case dbscan(radius: Double = 40, minimumPointCount: Int = 2)
    /// Fit up to the requested number of groups. Smaller groups appear as individual pins.
    case kMeans(clusterCount: Int, minimumClusterSize: Int = 2)
    /// Show each valid coordinate as an individual pin.
    case off
}
