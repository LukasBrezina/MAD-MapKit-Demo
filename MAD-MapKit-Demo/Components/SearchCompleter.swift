//
//  SearchCompleter.swift
//  MAD-MapKit-Demo
//
//  Created by Lukas Brezina on 10.11.26.
//
import MapKit
import Observation

@Observable
final class SearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    var query: String {
        get { completer.queryFragment }
        set { completer.queryFragment = newValue }
    }

    var region: MKCoordinateRegion {
        get {
            completer.region
        }
        set {
            completer.region = newValue
        }
    }

    func completerDidUpdateResults(_ c: MKLocalSearchCompleter) {
        results = c.results
    }
}
