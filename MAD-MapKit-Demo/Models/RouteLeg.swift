//
//  RouteLeg.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 11.11.26.
//
import MapKit
import SwiftUI

struct RouteLeg: Identifiable {
    let id = UUID()
    let index: Int
    let from: Location
    let to: Location
    let distance: CLLocationDistance
    let travelTime: TimeInterval

    // not set for transit, only shows time
    var polyline: MKPolyline?
    var alternatives: [MKPolyline] = []
    var steps: [String] = []

    private static let palette: [Color] = [.blue, .purple, .orange, .teal, .pink, .indigo]

    var color: Color { Self.palette[index % Self.palette.count] }
}

