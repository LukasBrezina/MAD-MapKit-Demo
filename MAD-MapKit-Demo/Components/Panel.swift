//
//  Panel.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 07.11.26.
//
import SwiftUI
import MapKit

struct MapPanel: View {
    
    @Binding
    var transport: TransportType
    
    let legs: [MKRoute]
    
    // number of selected stops
    let stopCount: Int
    
    // button action goes back to MapView
    let onCalculate: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Picker("Transport", selection: $transport) {
                ForEach(TransportType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // calculate route (needs at least 2 selected stops)
            Button("Calculate route (\(stopCount) stops)", action: onCalculate)
                .buttonStyle(.borderedProminent)
                .disabled(stopCount < 2)

            // route info has a fixed height, so the panel doesn't jump when a route appears
            VStack(spacing: 4) {
                if legs.isEmpty {
                    Text("No route yet")
                        .foregroundStyle(.secondary)
                } else {
                    let km = legs.reduce(0) { $0 + $1.distance } / 1000
                    let time = Duration.seconds(legs.reduce(0) { $0 + $1.expectedTravelTime })
                    Text("\(km.formatted(.number.precision(.fractionLength(1)))) km · \(time.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))")
                        .font(.headline)
                        .lineLimit(1)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(legs.flatMap(\.steps).filter { !$0.instructions.isEmpty }, id: \.self) { step in
                            Text(step.instructions)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(.regularMaterial)
    }
}
