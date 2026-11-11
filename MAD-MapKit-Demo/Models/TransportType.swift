//
//  TransportType.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 07.11.26.
//
import MapKit

enum TransportType: CaseIterable {
    case walking, cycling, car, transit

    var title: String {
        switch self {
        case .walking: "Zu Fuß"
        case .cycling: "Rad"
        case .car: "Auto"
        case .transit: "ÖPNV"
        }
    }

    var systemImage: String {
        switch self {
        case .walking: "figure.walk"
        case .cycling: "bicycle"
        case .car: "car.fill"
        case .transit: "tram.fill"
        }
    }

    var type: MKDirectionsTransportType {
        switch self {
        case .walking: .walking
        case .cycling: .cycling
        case .car: .automobile
        case .transit: .transit
        }
    }

    var supportsRoutes: Bool { self != .transit }
}
