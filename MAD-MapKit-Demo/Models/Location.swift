//
//  Location.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 03.11.26.
//

import MapKit

struct Location: Identifiable {

    enum Kind {
        case landmark, custom
    }

    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    var kind: Kind = .custom
    var systemImage: String = "mappin"

    var mapItem: MKMapItem {
        MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil
        )
    }
}

extension Location {
    static let samples = [
        Location(
            name: "Stephansdom",
            coordinate: CLLocationCoordinate2D(latitude: 48.2085, longitude: 16.3731),
            kind: .landmark,
            systemImage: "building.columns.fill"
        ),
        Location(
            name: "Schönbrunn",
            coordinate: CLLocationCoordinate2D(latitude: 48.1845, longitude: 16.3122),
            kind: .landmark,
            systemImage: "crown.fill"
        ),
        Location(
            name: "Prater",
            coordinate: CLLocationCoordinate2D(latitude: 48.2167, longitude: 16.3978),
            kind: .landmark,
            systemImage: "ferriswheel"
        ),
        Location(
            name: "Café Sacher",
            coordinate: CLLocationCoordinate2D(latitude: 48.2038, longitude: 16.3699),
            kind: .custom,
            systemImage: "cup.and.saucer.fill"
        )
    ]

    static let vienna = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    )
}
