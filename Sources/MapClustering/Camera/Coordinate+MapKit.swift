import MapKit
import MapClusteringCore

extension Coordinate {
    var location: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}
