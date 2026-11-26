import Foundation

/// Partitions projected points around a target number of centers.
struct KMeansClustering {
    let k: Int

    /// Seeds centers deterministically using squared-distance weighting, then alternates
    /// nearest-center assignment and averaging until assignments stabilize or 50 passes
    /// finish. Empty groups are omitted, so the result can contain fewer than `k` groups.
    /// If `k` meets or exceeds the point count, each point is returned as a singleton.
    func groups(for points: [ProjectedPoint]) throws -> [[Int]] {
        guard !points.isEmpty, k < points.count else { return points.indices.map { [$0] } }
        var rng = SplitMix64()
        var centers = [points[Int(rng.next() % UInt64(points.count))]]
        var distances = Array(repeating: Double.infinity, count: points.count)
        while centers.count < max(1, k) {
            try Task.checkCancellation()
            let newest = centers[centers.count - 1]
            var total = 0.0
            for i in points.indices {
                distances[i] = min(distances[i], points[i].distanceSquared(to: newest))
                total += distances[i]
            }
            guard total > 0 else { break }
            var target = Double(rng.next() >> 11) / 9_007_199_254_740_992 * total
            let chosen = distances.indices.first { target -= distances[$0]; return target < 0 }
            centers.append(points[chosen ?? distances.lastIndex(where: { $0 > 0 })!])
        }
        var labels = Array(repeating: -1, count: points.count)
        var groups = [[Int]]()
        for _ in 0..<50 {
            var changed = false
            groups = Array(repeating: [], count: centers.count)
            for i in points.indices {
                if i.isMultiple(of: 256) { try Task.checkCancellation() }
                let nearest = centers.indices.min {
                    points[i].distanceSquared(to: centers[$0]) < points[i].distanceSquared(to: centers[$1])
                }!
                changed = changed || labels[i] != nearest
                labels[i] = nearest
                groups[nearest].append(i)
            }
            if !changed { break }
            for i in groups.indices where !groups[i].isEmpty {
                try Task.checkCancellation()
                var x = 0.0
                var y = 0.0
                for member in groups[i] {
                    x += points[member].x
                    y += points[member].y
                }
                let count = Double(groups[i].count)
                centers[i] = ProjectedPoint(x: x / count, y: y / count)
            }
        }
        return groups.filter { !$0.isEmpty }
    }
}

private struct SplitMix64 {
    var state: UInt64 = 0
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
