import MapKit

struct Place: Identifiable {
    let id: Int
    let name: String
    let coordinate: CLLocationCoordinate2D

    static let region = MKCoordinateRegion(
        center: .init(latitude: 43.711, longitude: -79.343),
        span: .init(latitudeDelta: 0.20, longitudeDelta: 0.24)
    )

    static let fixture: [Self] = {
        let hubs = [
            ("Union Station", 43.6453, -79.3806),
            ("Kensington Market", 43.6545, -79.4005),
            ("North York Centre", 43.7685, -79.4130),
            ("Scarborough Town Centre", 43.7765, -79.2580)
        ]
        return (0..<100).map { index in
            let hub = hubs[index % hubs.count]
            let row = index / hubs.count
            return Self(id: index, name: "\(hub.0) · \(row + 1)", coordinate: .init(
                latitude: hub.1 + Double(row / 5 - 2) * 0.002,
                longitude: hub.2 + Double(row % 5 - 2) * 0.003
            ))
        }
    }()
}
