import SwiftUI

/// The default badge for a group of map items.
public struct ClusterCountBadge: View {
    let count: Int

    public var body: some View {
        Text(count, format: .number)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(10)
            .background(.blue, in: .circle)
    }
}
