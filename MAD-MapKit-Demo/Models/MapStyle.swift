//
//  MapStyle.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 07.11.26.
//
import MapKit
import SwiftUI

struct MapStyleSettings {

    enum Base: CaseIterable {
        case standard, hybrid, imagery

        var title: String {
            switch self {
            case .standard: "Standard"
            case .hybrid: "Hybrid"
            case .imagery: "Satellit"
            }
        }
    }
    
    var base = Base.standard
    
    // multiple options enhancing base style
    var realistic3D = false
    var showsTraffic = false
    var showsPOIs = true
    var muted = false

    var mapStyle: MapStyle {
        let elevation: MapStyle.Elevation = realistic3D ? .realistic : .flat
        let pois: PointOfInterestCategories = showsPOIs ? .all : .excludingAll

        return switch base {
        case .standard:
            .standard(elevation: elevation, emphasis: muted ? .muted : .automatic,
                      pointsOfInterest: pois, showsTraffic: showsTraffic)
        case .hybrid:
            .hybrid(elevation: elevation, pointsOfInterest: pois, showsTraffic: showsTraffic)
        case .imagery:
            .imagery(elevation: elevation)
        }
    }
}
