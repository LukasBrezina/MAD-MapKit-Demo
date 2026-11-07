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
    
    @State
    private var style = StyleOptions.standard
    
    @State
    private var transport = TransportType.walking
    
    @State
    private var places = locations

    // stops in the order they were tapped
    @State
    private var selectedIDs: [UUID] = []

    @State
    private var selection: UUID?

    @State
    private var legs: [MKRoute] = []
    
    @State
    private var query = ""

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $cameraPosition, interactionModes: .all, selection: $selection) {
                    placeMarkers
                    routeLines
                }
                .mapStyle(style.mapStyle)
                .simultaneousGesture(longPress(proxy))
            }
            .navigationTitle("MapKit Demo")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query)
            .onSubmit(of: .search) { Task { await search() } }
            .toolbar {
                // reset everything
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset", systemImage: "trash") {
                        places = locations; selectedIDs = []; legs = []
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Style", systemImage: "map") {
                        Picker("Style", selection: $style) {
                            ForEach(StyleOptions.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                MapPanel(transport: $transport, legs: legs, stopCount: selectedIDs.count) {
                    Task { await updateRoute() }
                }
            }
            .onChange(of: transport) {
                // recalculate route when transport type changes
                if !legs.isEmpty { Task { await updateRoute() } }
            }
            // tap on marker = add/remove stop
            .onChange(of: selection) { _, id in
                guard let id else { return }
                if let i = selectedIDs.firstIndex(of: id) { selectedIDs.remove(at: i) }
                else { selectedIDs.append(id) }
                legs = []          // old route is no longer valid
                selection = nil    // so the same marker can be tapped again
            }
        }
    }
    
    @MapContentBuilder
    private var placeMarkers: some MapContent {
        ForEach(places) { place in
            Marker(title(for: place), coordinate: place.coordinate)
                .tint(selectedIDs.contains(place.id) ? .blue : .red)
                .tag(place.id)
        }
    }

    @MapContentBuilder
    private var routeLines: some MapContent {
        ForEach(legs, id: \.self) { leg in
            MapPolyline(leg.polyline).stroke(.blue, lineWidth: 5)
        }
    }

    // title with number if the place is a selected stop
    private func title(for place: Location) -> String {
        guard let i = selectedIDs.firstIndex(of: place.id) else { return place.name }
        return "\(i + 1). \(place.name)"
    }
    
    private func updateRoute() async {
        let stops = selectedIDs.compactMap { id in places.first { $0.id == id } }
        guard stops.count > 1 else { legs = []; return }
        if transport == .transit {
            MKMapItem.openMaps(
                with: [stops.first!.mapItem, stops.last!.mapItem],
                launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit]
            )
            return
        }
        var result: [MKRoute] = []
        for (a, b) in zip(stops, stops.dropFirst()) {
            let req = MKDirections.Request()
            req.source = a.mapItem
            req.destination = b.mapItem
            req.transportType = transport.type
            if let route = try? await MKDirections(request: req).calculate().routes.first {
                result.append(route)
            }
        }
        legs = result
    }
    
    // TODO: fix
    private func search() async {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        let items = (try? await MKLocalSearch(request: req).start().mapItems) ?? []
        places += items.map { Location(name: $0.name ?? "Result", coordinate: $0.location.coordinate) }
        cameraPosition = .automatic
    }
    
    // long press on map = add new place
    private func longPress(_ proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                guard let coord = proxy.convert(drag.location, from: .local) else { return }
                let name = "Point \(places.count + 1)"
                places.append(Location(name: name, coordinate: coord))
            }
    }
}

extension Location {
    var mapItem: MKMapItem {
        MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
    }
}
