//
//  Waypoint.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 07.11.26.
//
import MapKit

struct Waypoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    
    var mapItem: MKMapItem {
        MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil
        )
    }
}
