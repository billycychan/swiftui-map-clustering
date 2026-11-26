import MapKit

struct Place: Identifiable {
    let id: Int
    let name: String
    let coordinate: CLLocationCoordinate2D

    static let region = MKCoordinateRegion(
        center: .init(latitude: 43.711, longitude: -79.343),
        span: .init(latitudeDelta: 0.20, longitudeDelta: 0.24)
    )

}

enum TorontoScenario: String, CaseIterable {
    case downtown = "Downtown"
    case corridor = "Yonge Street"
    case city = "Across Toronto"

    var region: MKCoordinateRegion {
        switch self {
        case .downtown:
            MKCoordinateRegion(center: .init(latitude: 43.650, longitude: -79.390),
                               span: .init(latitudeDelta: 0.035, longitudeDelta: 0.045))
        case .corridor, .city:
            Place.region
        }
    }

    func makePlaces(count: Int = 100) -> [Place] {
        // A fixed seed keeps the same places on the map when revisiting a scenario.
        var seed: UInt64 = 42
        func sample() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            return Double(seed >> 11) / 9_007_199_254_740_992
        }

        return (0..<count).map { id in
            let name: String
            let latitude, longitude, spread: Double
            let share = sample()
            switch self {
            case .corridor:
                // Follow Yonge north from downtown, with a narrow band of side streets.
                (name, latitude, longitude, spread) =
                    ("Yonge Street", 43.649 + 0.124 * share, -79.379 - 0.035 * share, 0.002)
            case .city where share >= 0.94:
                (name, latitude, longitude, spread) =
                    ("Midtown", 43.710, -79.365, 0.044)
            case .city where share >= 0.80:
                (name, latitude, longitude, spread) =
                    ("Scarborough Town Centre", 43.7765, -79.2580, 0.012)
            case .city where share >= 0.60:
                (name, latitude, longitude, spread) =
                    ("North York Centre", 43.7685, -79.4130, 0.009)
            case .city, .downtown:
                if share < 0.40 {
                    (name, latitude, longitude, spread) =
                        ("Union Station", 43.6453, -79.3806, 0.004)
                } else {
                    (name, latitude, longitude, spread) =
                        ("Kensington Market", 43.6545, -79.4005, 0.006)
                }
            }

            let angle = sample() * 2 * .pi
            let radius = sample() * spread
            return Place(id: id, name: "\(name) · \(id + 1)", coordinate: .init(
                latitude: latitude + radius * sin(angle),
                longitude: longitude + radius * cos(angle) / cos(latitude * .pi / 180)
            ))
        }
    }
}
