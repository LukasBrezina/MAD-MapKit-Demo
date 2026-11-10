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

    @State
    private var selectedIDs: [UUID] = []

    @State
    private var selection: UUID?

    @State
    private var legs: [MKRoute] = []
    
    @State
    private var visibleRegion: MKCoordinateRegion?
    
    @State
    private var query = ""
    
    // found place (search), shown as marker + result card
    @State
    private var result: MKMapItem?
    
    @State
    private var showDetails = false
    
    @State
    private var completer = SearchCompleter()
    
    @State
    private var followRoute = false

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $cameraPosition, interactionModes: .all, selection: $selection) {
                    placeMarkers
                    routeLines
                    if let result {
                        Marker(item: result)
                    }
                }
                .mapStyle(style.mapStyle)
                .mapControls { MapCompass() }
                .onMapCameraChange(frequency: .onEnd) {
                    visibleRegion = $0.region
                    completer.region = $0.region
                }
                .simultaneousGesture(createLocation(proxy))
            }
            .navigationTitle("MapKit Demo")
            .navigationBarTitleDisplayMode(.inline)
            // suggestions while typing
            .searchable(text: $query) {
                ForEach(completer.results, id: \.self) { s in
                    Button { Task { await selectLocation(s) } } label: {
                        VStack(alignment: .leading) {
                            Text(s.title)
                            Text(s.subtitle).font(.caption)
                        }
                    }
                }
            }
            .onChange(of: query) { _, q in completer.query = q }
            .onSubmit(of: .search) { Task { await searchMap() } }
            .toolbar {
                // reset everything
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset", systemImage: "trash") {
                        places = locations; selectedIDs = []; legs = []
                        result = nil
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Follow Route", systemImage: "play.fill") { Task { await followRoute() } }
                        .disabled(legs.isEmpty || followRoute)
                    Menu("Style", systemImage: "map") {
                        Picker("Style", selection: $style) {
                            ForEach(StyleOptions.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    if let result {
                        locationCard(result)
                    }
                    MapPanel(transport: $transport, legs: legs, stopCount: selectedIDs.count) {
                        Task {
                            await updateRoute()
                        }
                    }
                }
            }
            .onChange(of: transport) {
                // recalculate route when transport type changes
                if !legs.isEmpty {
                    Task {
                        await updateRoute()
                    }
                }
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
        .mapItemDetailSheet(isPresented: $showDetails, item: result)
    }
    
    @MapContentBuilder
    private var placeMarkers: some MapContent {
        ForEach(places) { place in
            Marker(place.name, coordinate: place.coordinate)
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
    
    // card for the found place: details, waypoint
    private func locationCard(_ item: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name ?? "Result").font(.headline).lineLimit(1)
                Spacer()
                Button("Close", systemImage: "xmark") { result = nil }
                    .labelStyle(.iconOnly)
            }
            HStack {
                Button("Details", systemImage: "info.circle") { showDetails = true }
                Button("Waypoint", systemImage: "mappin") { addResult(item) }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    // found place becomes a normal place + the next stop
    private func addResult(_ item: MKMapItem) {
        let location = Location(name: item.name ?? "Result", coordinate: item.location.coordinate)
        places.append(location)
        selectedIDs.append(location.id)
        legs = []
        result = nil
    }
    
    private func updateRoute() async {
        let items = selectedIDs.compactMap {
            id in places.first { $0.id == id }?.mapItem
        }
        guard items.count > 1 else {
            legs = [];
            return
        }
        // ÖPNV directs to Apple Karten
        if transport == .transit {
            MKMapItem.openMaps(
                with: [items.first!, items.last!],
                launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit]
            )
            return
        }
        var routes: [MKRoute] = []
        for (a, b) in zip(items, items.dropFirst()) {
            let req = MKDirections.Request()
            req.source = a
            req.destination = b
            req.transportType = transport.type
            if let route = try? await MKDirections(request: req).calculate().routes.first {
                routes.append(route)
            }
        }
        legs = routes
    }
    
    // searching and selecting a location
    private func searchMap() async {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        if let visibleRegion { req.region = visibleRegion }
        guard let item = try? await MKLocalSearch(request: req).start().mapItems.first else { return }
        showLocation(item)
    }
    
    private func selectLocation(_ s: MKLocalSearchCompletion) async {
        let req = MKLocalSearch.Request(completion: s)
        guard let item = try? await MKLocalSearch(request: req).start().mapItems.first else { return }
        showLocation(item)
    }
    
    private func showLocation(_ item: MKMapItem) {
        query = ""
        result = item
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: item.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        }
    }
    
    // follow calculated route (animation)
    private func followRoute() async {
        followRoute = true
        let points = legs.flatMap(\.steps).compactMap {
            $0.polyline.coords.first
        }
        
        for (a, b) in zip(points, points.dropFirst()) {
            withAnimation(.linear(duration: 2)) {
                cameraPosition = .camera(MapCamera(centerCoordinate: a, distance: 400,
                                                   heading: followDirection(a, b), pitch: 70))
            }
            try? await Task.sleep(for: .seconds(2))
        }
        followRoute = false
        cameraPosition = .automatic
    }
    
    private func followDirection(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        atan2((b.longitude - a.longitude) * cos(a.latitude * .pi / 180), b.latitude - a.latitude) * 180 / .pi
    }
    
    // long press on map = add new place
    private func createLocation(_ proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                guard let coord = proxy.convert(drag.location, from: .local) else { return }
                let name = "Point \(places.count + 1)"
                places.append(
                    Location(name: name, coordinate: coord)
                )
            }
    }
}

extension Location {
    var mapItem: MKMapItem {
        MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
    }
}

extension MKPolyline {
    var coords: [CLLocationCoordinate2D] {
        var c = [CLLocationCoordinate2D](repeating: .init(), count: pointCount)
        getCoordinates(&c, range: NSRange(location: 0, length: pointCount))
        return c
    }
}
