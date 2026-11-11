//
//  MapView.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 03.11.26.
//
import SwiftUI
import MapKit

struct MapView: View {

    // camera
    @State private var cameraPosition: MapCameraPosition = .region(Location.vienna)
    @State private var camera: MapCamera?
    @State private var visibleRegion: MKCoordinateRegion?

    // mapStyle and route configs
    @State private var styleSettings = MapStyleSettings()
    @State private var transport = TransportType.walking
    @State private var avoidHighways = false

    // locations, selected stops, calculated routes, follow route
    @State private var places = Location.samples
    @State private var stopIDs: [UUID] = []
    @State private var selection: MapSelection<UUID>? // either own object (marker, annotation) or apple POI
    @State private var legs: [RouteLeg] = []
    @State private var isCalculating = false
    @State private var followTask: Task<Void, Never>?

    // search for place & look around
    @State private var query = ""
    @State private var completer = SearchCompleter()
    @State private var result: MKMapItem?
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var showDetails = false

    @State private var locationManager = CLLocationManager()

    private var stops: [Location] {
        stopIDs.compactMap { id in places.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $cameraPosition, interactionModes: .all, selection: $selection) {
                    UserAnnotation()
                    routeLines
                    placeContent
                    if let result {
                        Marker(item: result).tint(.green)
                    }
                }
                .mapStyle(styleSettings.mapStyle)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapPitchToggle()
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    camera = context.camera
                    visibleRegion = context.region
                    completer.region = context.region
                }
                .simultaneousGesture(addPlaceGesture(proxy))
                .overlay(alignment: .trailing) { zoomButtons }
            }
            .navigationTitle("MapKit Demo")
            .navigationBarTitleDisplayMode(.inline)
            // suggestions while typing
            .searchable(text: $query, prompt: "Ort suchen")
            .searchSuggestions {
                ForEach(completer.results, id: \.self) { s in
                    Button { Task { await selectCompletion(s) } } label: {
                        VStack(alignment: .leading) {
                            Text(s.title)
                            Text(s.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onChange(of: query) { _, q in completer.query = q }
            .onSubmit(of: .search) { Task { await search() } }
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let result {
                        resultCard(result)
                    }
                    MapPanel(transport: $transport, avoidHighways: $avoidHighways,
                             stops: stops, legs: legs, isCalculating: isCalculating) {
                        Task { await calculateRoute() }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            // recalculate when route options change
            .onChange(of: transport) { if !legs.isEmpty { Task { await calculateRoute() } } }
            .onChange(of: avoidHighways) { if !legs.isEmpty { Task { await calculateRoute() } } }
            .onChange(of: selection) { _, newSelection in
                handleSelection(newSelection)
            }
            // load Look Around scene whenever the result changes (result is only from search)
            .task(id: result) {
                lookAroundScene = nil
                guard let result else { return }
                lookAroundScene = try? await MKLookAroundSceneRequest(mapItem: result).scene
            }
            .task { locationManager.requestWhenInUseAuthorization() }
        }
        .mapItemDetailSheet(isPresented: $showDetails, item: result) // ready to go detail sheet in MapKit (only item is required)
    }

    @MapContentBuilder
    private var placeContent: some MapContent {
        ForEach(places) { place in
            let stopNumber = stopIDs.firstIndex(of: place.id).map { $0 + 1 }

            if place.kind == .landmark {
                // marker
                if let stopNumber {
                    Marker(place.name, monogram: Text("\(stopNumber)"), coordinate: place.coordinate)
                        .tint(.blue)
                        .tag(MapSelection(place.id))
                } else {
                    Marker(place.name, systemImage: place.systemImage, coordinate: place.coordinate)
                        .tint(.red)
                        .tag(MapSelection(place.id))
                }
            } else {
                // annotation
                Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                    PlaceAnnotationView(place: place, stopNumber: stopNumber)
                }
                .tag(MapSelection(place.id))
            }
        }
    }
    
    // routes, alternate routes are grey
    @MapContentBuilder
    private var routeLines: some MapContent {
        ForEach(legs) { leg in
            ForEach(leg.alternatives, id: \.self) { alternative in
                MapPolyline(alternative)
                    .stroke(.gray.opacity(0.7), lineWidth: 4)
            }
            if let polyline = leg.polyline {
                MapPolyline(polyline)
                    .stroke(leg.color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            } else {
                // transit: no geometry from MapKit → dashed straight line
                MapPolyline(coordinates: [leg.from.coordinate, leg.to.coordinate])
                    .stroke(leg.color, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 8]))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Zurücksetzen", systemImage: "arrow.counterclockwise", action: reset)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(followTask == nil ? "Route abfahren" : "Stopp",
                   systemImage: followTask == nil ? "play.fill" : "stop.fill",
                   action: toggleFollowing)
                .disabled(legs.allSatisfy { $0.polyline == nil })

            Menu("Kartenstil", systemImage: "map") {
                Picker("Stil", selection: $styleSettings.base) {
                    ForEach(MapStyleSettings.Base.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Section("Optionen") {
                    Toggle("3D (realistisch)", isOn: $styleSettings.realistic3D)
                    Toggle("Verkehr", isOn: $styleSettings.showsTraffic)
                        .disabled(styleSettings.base == .imagery)
                    Toggle("Points of Interest", isOn: $styleSettings.showsPOIs)
                        .disabled(styleSettings.base == .imagery)
                    Toggle("Gedämpft", isOn: $styleSettings.muted)
                        .disabled(styleSettings.base != .standard)
                }
            }
        }
    }

    private var zoomButtons: some View {
        VStack(spacing: 0) {
            Button { zoom(by: 0.5) } label: {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }
            Divider().frame(width: 44)
            Button { zoom(by: 2) } label: {
                Image(systemName: "minus").frame(width: 44, height: 44)
            }
        }
        .font(.title3.weight(.medium))
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        .padding(.trailing, 8)
    }

    // search result card
    private func resultCard(_ item: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Ergebnis").font(.headline).lineLimit(1)
                    if let address = item.address?.shortAddress {
                        Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Button("Schließen", systemImage: "xmark.circle.fill") { result = nil }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if let lookAroundScene {
                LookAroundPreview(initialScene: lookAroundScene)
                    .frame(height: 120)
                    .clipShape(.rect(cornerRadius: 12))
            }

            HStack {
                Button("Details", systemImage: "info.circle") { showDetails = true }
                Button("Als Stopp", systemImage: "plus.circle") { addAsStop(item) }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .cardStyle()
    }
    
    private func handleSelection(_ newSelection: MapSelection<UUID>?) {
        guard let newSelection else { return }
        if let id = newSelection.value {
            // own place tapped → add / remove as stop
            if let i = stopIDs.firstIndex(of: id) { stopIDs.remove(at: i) } else { stopIDs.append(id) }
            legs = []
        } else if let feature = newSelection.feature {
            Task {
                if let item = try? await MKMapItemRequest(feature: feature).mapItem {
                    showResult(item, moveCamera: false)
                }
            }
        }
        selection = nil
    }

    private func addAsStop(_ item: MKMapItem) {
        let location = Location(name: item.name ?? "Ergebnis", coordinate: item.location.coordinate,
                                kind: .custom, systemImage: "star.fill")
        places.append(location)
        stopIDs.append(location.id)
        legs = []
        result = nil
    }

    private func calculateRoute() async {
        let stops = stops
        guard stops.count > 1 else { legs = []; return }
        stopFollowing()
        isCalculating = true
        defer { isCalculating = false }

        var newLegs: [RouteLeg] = []
        for (index, (from, to)) in zip(stops, stops.dropFirst()).enumerated() {
            let request = MKDirections.Request()
            request.source = from.mapItem
            request.destination = to.mapItem
            request.transportType = transport.type
            if transport == .car {
                request.highwayPreference = avoidHighways ? .avoid : .any
            }

            if transport.supportsRoutes {
                request.requestsAlternateRoutes = true
                guard let routes = try? await MKDirections(request: request).calculate().routes,
                      let best = routes.first else { continue }
                newLegs.append(RouteLeg(
                    index: index, from: from, to: to,
                    distance: best.distance,
                    travelTime: best.expectedTravelTime,
                    polyline: best.polyline,
                    alternatives: routes.dropFirst().map(\.polyline),
                    steps: best.steps.map(\.instructions).filter { !$0.isEmpty }
                ))
            } else {
                // transit: MapKit can only calculate the travel time (ETA)
                guard let eta = try? await MKDirections(request: request).calculateETA() else { continue }
                newLegs.append(RouteLeg(
                    index: index, from: from, to: to,
                    distance: eta.distance,
                    travelTime: eta.expectedTravelTime
                ))
            }
        }
        legs = newLegs
        showWholeRoute()
    }

    private func showWholeRoute() {
        var rect = MKMapRect.null
        for leg in legs {
            if let polyline = leg.polyline {
                rect = rect.union(polyline.boundingMapRect)
            } else {
                for coordinate in [leg.from.coordinate, leg.to.coordinate] {
                    let point = MKMapPoint(coordinate)
                    rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
                }
            }
        }
        guard !rect.isNull else { return }
        let padding = max(rect.width, rect.height) * 0.2
        withAnimation {
            cameraPosition = .rect(rect.insetBy(dx: -padding, dy: -padding))
        }
    }

    private func toggleFollowing() {
        if followTask != nil {
            stopFollowing()
        } else {
            followTask = Task {
                await followRoute()
                followTask = nil
            }
        }
    }

    private func stopFollowing() {
        followTask?.cancel()
        followTask = nil
    }
    
    // camera follows calculated route
    private func followRoute() async {
        let all = legs.compactMap(\.polyline).flatMap(\.coordinates)
        guard all.count > 1 else { return }
        // ~ 40 points
        let stride = max(1, all.count / 40)
        let points = Swift.stride(from: 0, to: all.count, by: stride).map { all[$0] } + [all[all.count - 1]]

        for (a, b) in zip(points, points.dropFirst()) {
            if Task.isCancelled { return }
            withAnimation(.linear(duration: 1.5)) {
                cameraPosition = .camera(MapCamera(centerCoordinate: a, distance: 500,
                                                   heading: heading(from: a, to: b), pitch: 65))
            }
            try? await Task.sleep(for: .seconds(1.5))
        }
        if !Task.isCancelled { showWholeRoute() }
    }

    private func heading(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        atan2((b.longitude - a.longitude) * cos(a.latitude * .pi / 180), b.latitude - a.latitude) * 180 / .pi
    }

    // called by zoom buttons
    private func zoom(by factor: Double) {
        guard let camera else { return }
        withAnimation {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: camera.centerCoordinate,
                distance: camera.distance * factor,
                heading: camera.heading,
                pitch: camera.pitch
            ))
        }
    }
    
    // reset everything
    private func reset() {
        stopFollowing()
        legs = []
        stopIDs = []
        places = Location.samples
        result = nil
        transport = .walking
        avoidHighways = false
        styleSettings = MapStyleSettings()
        withAnimation { cameraPosition = .region(Location.vienna) }
    }

    private func search() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let visibleRegion { request.region = visibleRegion }
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return }
        showResult(item)
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) async {
        // resolves the tapped search suggestion (text only) into a full MKMapItem via MKLocalSearch and shows it.
        let request = MKLocalSearch.Request(completion: completion)
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return }
        showResult(item)
    }

    private func showResult(_ item: MKMapItem, moveCamera: Bool = true) {
        query = ""
        result = item
        guard moveCamera else { return }
        withAnimation {
            cameraPosition = .item(item)
        }
    }

    // long pressing adds new place
    private func addPlaceGesture(_ proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let coordinate = proxy.convert(drag.location, from: .local) else { return }
                let number = places.filter { $0.kind == .custom }.count + 1
                places.append(Location(name: "Punkt \(number)", coordinate: coordinate))
            }
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var result = [CLLocationCoordinate2D](repeating: .init(), count: pointCount)
        getCoordinates(&result, range: NSRange(location: 0, length: pointCount))
        return result
    }
}
