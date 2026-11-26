import Foundation

/// Builds a hierarchy by merging nearby groups from finer to coarser zoom levels.
struct SuperclusterClustering {
    /// Merges unclaimed neighbors at one zoom level when their combined member count meets
    /// the minimum. New groups record the next finer level as their expansion zoom.
    func merge(_ groups: [ClusterGroup], points: [ProjectedPoint], radius: Double,
                      minimumPointCount: Int, leafSize: Int, zoom: Int) throws -> [ClusterGroup] {
        let tree = try SpatialIndex(groups.map(\.point), leafSize: leafSize)
        var used = Array(repeating: false, count: groups.count)
        var result: [ClusterGroup] = []
        for i in groups.indices where !used[i] {
            try Task.checkCancellation()
            used[i] = true
            let neighbors = try tree.neighbors(of: groups[i].point, radius: radius).filter { !used[$0] }
            let total = neighbors.reduce(groups[i].count) { $0 + groups[$1].count }
            if !neighbors.isEmpty && total >= max(2, minimumPointCount) {
                var members = groups[i].memberIndices
                for j in neighbors {
                    used[j] = true
                    members.append(contentsOf: groups[j].memberIndices)
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
}
