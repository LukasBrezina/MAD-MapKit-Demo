//
//  MapPanel.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 07.11.26.
//
import SwiftUI
import MapKit

struct MapPanel: View {

    @Binding
    var transport: TransportType
    
    @Binding
    var avoidHighways: Bool

    let stops: [Location]
    let legs: [RouteLeg]
    let isCalculating: Bool

    // button action goes back to MapView
    let onCalculate: () -> Void

    private var km: Double { legs.reduce(0) { $0 + $1.distance } / 1000 }
    private var time: Duration { .seconds(legs.reduce(0) { $0 + $1.travelTime }) }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Verkehrsmittel", selection: $transport) {
                ForEach(TransportType.allCases, id: \.self) {
                    Label($0.title, systemImage: $0.systemImage).tag($0)
                }
            }
            .pickerStyle(.segmented)

            ZStack(alignment: .leading) {
                Toggle("Autobahnen vermeiden", isOn: $avoidHighways)
                    .opacity(transport == .car ? 1 : 0)
                    .disabled(transport != .car)

                if transport != .car {
                    Label(transportInfo, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            if stops.count < 2 {
                hint
            } else {
                Button(action: onCalculate) {
                    Group {
                        if isCalculating {
                            ProgressView()
                        } else {
                            Label("Route berechnen (\(stops.count) Stopps)",
                                  systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isCalculating)
            }

            if !legs.isEmpty {
                summary
                legList
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var transportInfo: String {
        switch transport {
        case .walking: "Fußwege inkl. Alternativrouten"
        case .cycling: "Radwege inkl. Alternativrouten"
        case .transit: "ÖPNV: MapKit liefert nur die Fahrzeit"
        case .car: ""
        }
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Tippe auf Orte, um sie als Stopp hinzuzufügen", systemImage: "hand.tap")
            Label("Lange drücken setzt einen eigenen Punkt", systemImage: "hand.point.up.left")
            Label("Suche oder tippe auf POIs für Details & Look Around", systemImage: "binoculars")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: some View {
        HStack(spacing: 8) {
            iconCapsule(km.formatted(.number.precision(.fractionLength(1))) + " km", icon: "ruler")
            iconCapsule(time.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)), icon: "clock")
            Spacer()
        }
    }

    private var legList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(legs) { leg in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle().fill(leg.color).frame(width: 10, height: 10)
                            Text("\(leg.from.name) → \(leg.to.name)").font(.subheadline.bold())
                            Spacer()
                            Text(Duration.seconds(leg.travelTime)
                                .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if leg.steps.isEmpty {
                            Text("Nur Fahrzeit verfügbar (MapKit liefert für ÖPNV keine Route)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(Array(leg.steps.enumerated()), id: \.offset) { i, text in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(leg.color, in: .circle)
                                Text(text)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 160)
    }

    private func iconCapsule(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.15), in: .capsule)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}
