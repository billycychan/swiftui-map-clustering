/// A partition entry. Indices refer to the supplied dataset in input order.
public struct ClusterGroup: Identifiable, Sendable {
    public let id: Int
    /// Indices into the original input collection.
    public let memberIndices: [Int]
    public var count: Int { memberIndices.count }
    public let coordinate: Coordinate
    public let northwest: Coordinate
    public let southeast: Coordinate
    /// First finer level at which this hierarchy node splits.
    public let expansionZoom: Int?
    let point: ProjectedPoint

    init(_ members: [Int], points: [ProjectedPoint], expansionZoom: Int? = nil) {
        self.expansionZoom = expansionZoom
        precondition(!members.isEmpty)
        self.memberIndices = members
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
