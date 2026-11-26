import Foundation

enum Membership {
    // Weighted, greedy bottom-up merging following Mapbox Supercluster.
    static func merge(_ groups: [ClusterGroup], points: [ProjectedPoint], radius: Double,
                      options: ClusteringOptions, zoom: Int) throws -> [ClusterGroup] {
        let tree = try SpatialIndex(groups.map(\.point), leafSize: options.nodeSize)
        var used = Array(repeating: false, count: groups.count)
        var result: [ClusterGroup] = []
        for i in groups.indices where !used[i] {
            try Task.checkCancellation()
            used[i] = true
            let neighbors = try tree.neighbors(of: groups[i].point, radius: radius).filter { !used[$0] }
            let total = neighbors.reduce(groups[i].members.count) { $0 + groups[$1].members.count }
            if !neighbors.isEmpty && total >= max(2, options.minPoints) {
                var members = groups[i].members
                for j in neighbors {
                    used[j] = true
                    members.append(contentsOf: groups[j].members)
                }
                result.append(ClusterGroup(members, points: points, expansionZoom: zoom + 1))
            } else {
                result.append(groups[i])
                for j in neighbors {
                    used[j] = true
                    result.append(groups[j])
                }
            }
        }
        return result
    }

    static func dbscan(_ tree: SpatialIndex, radius: Double, minimum: Int) throws -> [[Int]] {
        let points = tree.points
        var visited = Array(repeating: false, count: points.count)
        var assigned = visited
        var unassigned = UnassignedSlots(count: points.count)
        var groups: [[Int]] = []

        func discoverNeighbors(of i: Int, in queue: inout [Int]) throws {
            try tree.visitNeighbors(of: points[i], radius: radius, nextSlot: {
                unassigned.first(atOrAfter: $0)
            }) { slot, id in
                unassigned.remove(slot)
                assigned[id] = true
                queue.append(id)
                return true
            }
        }

        for seed in points.indices where !visited[seed] {
            try Task.checkCancellation()
            visited[seed] = true
            guard try tree.hasNeighbors(of: points[seed], radius: radius, minimum: minimum) else { continue }
            var queue: [Int] = []
            try discoverNeighbors(of: seed, in: &queue)
            var cursor = 0
            while cursor < queue.count, unassigned.first(atOrAfter: 0) < points.count {
                try Task.checkCancellation()
                let i = queue[cursor]
                cursor += 1
                guard !visited[i] else { continue }
                visited[i] = true
                if try tree.hasNeighbors(of: points[i], radius: radius, minimum: minimum) {
                    try discoverNeighbors(of: i, in: &queue)
                }
            }
            groups.append(queue)
            if unassigned.first(atOrAfter: 0) == points.count { return groups }
        }
        return groups + points.indices.filter { !assigned[$0] }.map { [$0] }
    }

    static func kMeans(_ points: [ProjectedPoint], k: Int) throws -> [[Int]] {
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

/// A successor set over KD-tree slots. Removed slots point to their next
/// available neighbor, allowing an entire assigned subtree to be skipped.
private struct UnassignedSlots {
    private var next: [Int]

    init(count: Int) {
        next = Array(0...count)
    }

    mutating func first(atOrAfter slot: Int) -> Int {
        var slot = slot
        while next[slot] != slot {
            next[slot] = next[next[slot]]
            slot = next[slot]
        }
        return slot
    }

    mutating func remove(_ slot: Int) {
        let successor = first(atOrAfter: slot + 1)
        next[slot] = successor
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
