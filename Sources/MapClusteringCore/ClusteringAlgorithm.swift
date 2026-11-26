/// Membership strategy. Off mode returns every input point.
public enum ClusteringAlgorithm: Hashable, Sendable {
    case supercluster, dbscan, kMeans(k: Int), off
}
