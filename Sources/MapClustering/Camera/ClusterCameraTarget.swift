import MapKit
import MapClusteringCore

/// Expansion may use some of the padding when the full member bounds still fit.
func clusterCameraTarget(for group: ClusterGroup, expansionWidth: Double?) -> MKMapRect {
    let northwest = MKMapPoint(group.northwest.location)
    let southeast = MKMapPoint(group.southeast.location)
    let bounds = MKMapRect(x: northwest.x, y: northwest.y,
                           width: max(1, southeast.x - northwest.x),
                           height: max(1, southeast.y - northwest.y))
    let padded = bounds.insetBy(dx: -max(30, bounds.width * 0.15),
                               dy: -max(30, bounds.height * 0.15))
    guard let expansionWidth, expansionWidth < padded.width else { return padded }
    let height = padded.height * expansionWidth / padded.width
    guard expansionWidth >= max(60, bounds.width), height >= max(60, bounds.height) else { return padded }
    return MKMapRect(x: padded.midX - expansionWidth / 2, y: padded.midY - height / 2,
                     width: expansionWidth, height: height)
}
