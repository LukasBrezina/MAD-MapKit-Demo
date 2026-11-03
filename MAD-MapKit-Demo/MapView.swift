//
//  MapView.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 03.11.26.
//

import SwiftUI
import MapKit

struct MapView: View {

    @State
    private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: 48.2082,
                longitude: 16.3738
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 0.05,
                longitudeDelta: 0.05
            )
        )
    )

    var body: some View {
        Map(position: $cameraPosition) {

            ForEach(locations) { location in
                Marker(
                    location.name,
                    coordinate: location.coordinate
                )
            }
        }
    }
}
