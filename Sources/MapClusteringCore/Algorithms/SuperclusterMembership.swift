import Foundation

struct SuperclusterMembership {
    func merge(_ groups: [ClusterGroup], points: [ProjectedPoint], radius: Double,
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
}
