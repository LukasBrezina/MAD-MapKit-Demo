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
    
    let stopCount: Int
    
    // button action goes back to MapView
    let onCalculate: () -> Void
    
    private var km: Double {
        legs.reduce(0) { $0 + $1.distance } / 1000
    }
    private var time: Duration {
        .seconds(legs.reduce(0) { $0 + $1.expectedTravelTime })
    }
    private var steps: [String] {
        legs.flatMap(\.steps).map(\.instructions).filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Transport", selection: $transport) {
                ForEach(TransportType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // calculate route (needs at least 2 selected stops)
            Button(action: onCalculate) {
                Label("Calculate route (\(stopCount) stops)", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(stopCount < 2)


            Group {
                if !legs.isEmpty {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            iconCapsule(km.formatted(.number.precision(.fractionLength(1))) + " km", icon: "ruler")
                            iconCapsule(time.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)), icon: "clock")
                        }

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(steps.enumerated()), id: \.offset) { i, text in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(i + 1)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .frame(width: 22, height: 22)
                                            .background(.blue, in: .circle)
                                        Text(text)
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 130)
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func iconCapsule(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.15), in: .capsule)
    }
}
