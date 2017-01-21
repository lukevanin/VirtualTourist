//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController {
    
    fileprivate lazy var dataStack: CoreDataStack = {
        let instance = try! CoreDataStack(name: "VirtualTourist")
        instance.autosave(every: 5.0)
        return instance
    }()
    
    fileprivate var locations = [Location]()
    fileprivate var didAppear = false
    
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
        locations.append(location)

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadLocations()
        reloadAnnotations()
        didAppear = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? LocationViewController, let annotation = sender as? LocationAnnotation {
            let match = locations.first() { $0.id == annotation.locationID }
            if let location = match {
                viewController.context = dataStack.mainContext
                viewController.location = location
            }
        }
    }
    
    // MARK: Map annotations
    
    //
    //
    //
    fileprivate func loadLocations() {
        do {
            locations = try dataStack.mainContext.allLocations()
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
        let annotations = locations.map { $0.toAnnotation() }
        mapView.addAnnotations(annotations)
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
            pinView.animatesDrop = !didAppear
            view = pinView
        }
        
        return view
    }
    
    //
    //
    //
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? LocationAnnotation else {
            return
        }
        performSegue(withIdentifier: "location", sender: annotation)
    }
}
