//
//  PlaceAnnotationView.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 11.11.26.
//
import SwiftUI

struct PlaceAnnotationView: View {
    
    let place: Location
    let stopNumber: Int?

    private var color: Color {
        stopNumber == nil ? .orange : .blue
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                if let stopNumber {
                    Text("\(stopNumber)")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: place.systemImage)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }
            Image(systemName: "triangle.fill")
                .font(.caption2)
                .foregroundStyle(color)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        .animation(.spring, value: stopNumber)
    }
}
