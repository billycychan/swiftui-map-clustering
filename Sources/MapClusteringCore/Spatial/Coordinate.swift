/// A geographic location in degrees.
public struct Coordinate: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    /// Creates a location from latitude and longitude in degrees.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
