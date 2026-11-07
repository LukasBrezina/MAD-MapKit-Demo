//
//  MapStyle.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 07.11.26.
//
import MapKit
import SwiftUI

enum StyleOptions: String, CaseIterable {
    case standard = "Standard", imagery = "Satellit", hybrid = "Hybrid"
    var mapStyle: MapStyle {
        switch self { case .standard: .standard; case .imagery: .imagery; case .hybrid: .hybrid }
    }
}

