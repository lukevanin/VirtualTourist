//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController {
    
    fileprivate lazy var dataStack: CoreDataStack = {
        let instance = try! CoreDataStack(name: "VirtualTourist")
        instance.autosave(every: 5.0)
        return instance
    }()
    
    fileprivate var locations: [Location]?
    
    // MARK: Outlets.
    
    @IBOutlet weak var mapView: MKMapView!
    
    // MARK: Actions
    
    @IBAction func onMapLongPressGesture(_ gesture: UIGestureRecognizer) {
        
        guard gesture.state == .began else {
            return
        }
        
        // Convert the gesture location to map coordinates.
        let point = gesture.location(in: view)
        let coordinate = mapView.convert(point, toCoordinateFrom: view)

        // Create and add the location to the core data store.
        let location = Location(coordinate: coordinate, context: dataStack.mainContext)

        // Create and add the annotation to the map.
        let annotation = location.toAnnotation()
        mapView.addAnnotation(annotation)
        
        // Save the main context to propogate the changes to the background context.
        do {
            try dataStack.mainContext.save()
        }
        catch {
            showAlert(forError: error)
        }
    }
    
    // MARK: View controller life cycle.

    override func viewDidLoad() {
        super.viewDidLoad()
        loadLocations()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: Map annotations
    
    //
    //
    //
    fileprivate func loadLocations() {
        do {
            locations = try dataStack.fetchLocations()
            reloadAnnotations()
        }
        catch {
            showAlert(forError: error)
        }
    }
    
    //
    //
    //
    private func reloadAnnotations() {
        mapView.removeAnnotations(mapView.annotations)
        if let locations = locations {
            let annotations = makeAnnotations(forLocations: locations)
            mapView.addAnnotations(annotations)
        }
    }
    
    //
    //
    //
    private func makeAnnotations(forLocations locations: [Location]) -> [MKAnnotation] {
        return locations.map { $0.toAnnotation() }
    }
}

//
//
//
extension MapViewController: MKMapViewDelegate {
    
    //
    //
    //
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseIdentifier = "location"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
        
        if view == nil {
            let pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            pinView.animatesDrop = true
            view = pinView
        }
        
        return view
    }
    
    //
    //
    //
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
    }
}
