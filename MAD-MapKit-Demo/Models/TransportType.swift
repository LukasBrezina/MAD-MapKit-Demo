//
//  TransportType.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 07.11.26.
//
import MapKit

enum TransportType: String, CaseIterable {
    case walking = "Zu Fuß", car = "Auto", transit = "ÖPNV"
    var type: MKDirectionsTransportType {
        switch self { case .walking: .walking; case .car: .automobile; case .transit: .transit }
    }
}
