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
