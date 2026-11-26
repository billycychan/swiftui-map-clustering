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

/// A partition entry. Indices refer to the supplied dataset in input order.
public struct ClusterGroup: Identifiable, Sendable {
    public let id: Int
    public let members: [Int]
    public let coordinate: Coordinate
    public let northwest: Coordinate
    public let southeast: Coordinate
    /// First finer level at which this hierarchy node splits.
    public let expansionZoom: Int?
    let point: ProjectedPoint

    init(_ members: [Int], points: [ProjectedPoint], expansionZoom: Int? = nil) {
        self.expansionZoom = expansionZoom
        precondition(!members.isEmpty)
        self.members = members
        var anchor = members[0]
        var x = 0.0, y = 0.0
        var west = 1.0, east = 0.0, north = 1.0, south = 0.0
        for index in members {
            let p = points[index]
            anchor = min(index, anchor)
            x += p.x
            y += p.y
            west = min(west, p.x)
            east = max(east, p.x)
            north = min(north, p.y)
            south = max(south, p.y)
        }
        id = anchor
        point = .init(x: x / Double(members.count), y: y / Double(members.count))
        coordinate = point.coordinate
        northwest = ProjectedPoint(x: west, y: north).coordinate
        southeast = ProjectedPoint(x: east, y: south).coordinate
    }
}
