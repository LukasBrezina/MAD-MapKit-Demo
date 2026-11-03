//
//  Location.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 03.11.26.
//

import Foundation
import CoreLocation

struct Location: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

let locations = [
    Location(
        name: "Stephansdom",
        coordinate: CLLocationCoordinate2D(
            latitude: 48.2085,
            longitude: 16.3731
        )
    ),
    Location(
        name: "Schönbrunn",
        coordinate: CLLocationCoordinate2D(
            latitude: 48.1845,
            longitude: 16.3122
        )
    ),
    Location(
        name: "Prater",
        coordinate: CLLocationCoordinate2D(
            latitude: 48.2167,
            longitude: 16.3978
        )
    )
]
