import Foundation

struct ProjectedPoint: Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) { self.x = x; self.y = y }

    init(_ coordinate: Coordinate) {
        let longitude = coordinate.longitude.truncatingRemainder(dividingBy: 360)
        x = (longitude + 180) / 360
        x -= floor(x)
        let latitude = min(85.05112878, max(-85.05112878, coordinate.latitude))
        y = max(0, min(1, (1 - asinh(tan(latitude * .pi / 180)) / .pi) / 2))
    }

    var coordinate: Coordinate {
        Coordinate(latitude: atan(sinh(.pi * (1 - 2 * y))) * 180 / .pi, longitude: x * 360 - 180)
    }

    func distanceSquared(to other: Self) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }
}
