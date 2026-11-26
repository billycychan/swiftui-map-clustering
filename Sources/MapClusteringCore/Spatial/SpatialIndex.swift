// Flat alternating-axis median tree and radius traversal adapted from KDBush.
// See THIRD_PARTY_NOTICES. Leaves store indices into the immutable input.
struct SpatialIndex: Sendable {
    let points: [ProjectedPoint]
    private var order: [Int]
    private let leafSize: Int

    init(_ points: [ProjectedPoint], leafSize: Int) throws {
        self.points = points
        self.leafSize = max(1, leafSize)
        order = Array(points.indices)
        try partition(0, points.count, horizontal: true)
    }

    private mutating func partition(_ lo: Int, _ hi: Int, horizontal: Bool) throws {
        try Task.checkCancellation()
        guard hi - lo > leafSize else { return }
        order[lo..<hi].sort {
            let a = horizontal ? points[$0].x : points[$0].y
            let b = horizontal ? points[$1].x : points[$1].y
            return a == b ? $0 < $1 : a < b
        }
        let mid = (lo + hi) / 2
        try partition(lo, mid, horizontal: !horizontal)
        try partition(mid + 1, hi, horizontal: !horizontal)
    }

    func neighbors(of point: ProjectedPoint, radius: Double) throws -> [Int] {
        var result: [Int] = []
        try visitNeighbors(of: point, radius: radius) { _, id in
            result.append(id)
            return true
        }
        return result
    }

    func hasNeighbors(of point: ProjectedPoint, radius: Double, minimum: Int) throws -> Bool {
        var needed = minimum
        try visitNeighbors(of: point, radius: radius) { _, _ in
            needed -= 1
            return needed > 0
        }
        return needed == 0
    }

    /// Visits radius matches. The cursor may skip removed slots in KD-tree order.
    /// Returning false from the visitor stops the entire search.
    func visitNeighbors(of point: ProjectedPoint, radius: Double,
                        nextSlot: (Int) -> Int = { $0 },
                        _ body: (Int, Int) -> Bool) throws {
        let squared = radius * radius
        func visit(_ lo: Int, _ hi: Int, horizontal: Bool) throws -> Bool {
            try Task.checkCancellation()
            let first = nextSlot(lo)
            guard first < hi else { return true }
            if hi - lo <= leafSize {
                var slot = first
                while slot < hi {
                    let id = order[slot]
                    if points[id].distanceSquared(to: point) <= squared, !body(slot, id) {
                        return false
                    }
                    slot = nextSlot(slot + 1)
                }
                return true
            }
            let mid = (lo + hi) / 2
            let id = order[mid]
            let pivot = points[id]
            if first <= mid, nextSlot(mid) == mid, pivot.distanceSquared(to: point) <= squared,
               !body(mid, id) {
                return false
            }
            let delta = horizontal ? point.x - pivot.x : point.y - pivot.y
            if delta <= radius, try !visit(lo, mid, horizontal: !horizontal) { return false }
            if delta >= -radius, try !visit(mid + 1, hi, horizontal: !horizontal) { return false }
            return true
        }
        _ = try visit(0, order.count, horizontal: true)
    }
}
