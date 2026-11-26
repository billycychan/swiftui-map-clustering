import Foundation

/// Groups points by density using radius queries against a spatial index.
struct DBSCANClustering {
    /// Returns groups of input indices. The minimum neighbor count includes the point itself.
    /// Only core points expand a group, shared border points join the first group that
    /// reaches them, and points left unassigned are returned as singletons.
    func groups(in tree: SpatialIndex, radius: Double, minimum: Int) throws -> [[Int]] {
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
}

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
