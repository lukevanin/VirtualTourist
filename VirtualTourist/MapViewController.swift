//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//
//  Show a map with pins indicating locations of interest. Add a pin to the map by perfoming a long press gesture on the 
//  map. Editing allows pins to be deleted. Tap edit, then tap on a pin to remove it.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController {
    
    //
    //  Initialize the core data stack and set it to autosave on a fixed interval.
    //
    fileprivate lazy var dataStack: CoreDataStack = {
        let instance = try! CoreDataStack(name: "VirtualTourist")
        instance.autosave(every: 30.0)
        return instance
    }()
    
    fileprivate var isTouching = false
    fileprivate var models = [String : LocationModel]()
    
    // MARK: Outlets.
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var messageView: UIView!
    
    // MARK: Actions
    
    //
    //  Called when user performs a long press on the map to place a pin. The location of the press is converted from
    //  screen coordinates to latitude and longitude. The information is used to create a Location object when is 
    //  stored in core data, and shown on the map.
    //
    @IBAction func onMapLongPressGesture(_ gesture: UIGestureRecognizer) {
        
        guard gesture.state == .began else {
            isTouching = false
            return
        }
        
        isTouching = true
        
        // Convert the gesture location to map coordinates.
        let point = gesture.location(in: view)
        let coordinate = mapView.convert(point, toCoordinateFrom: view)

        // Add the location to core data.
        addLocation(coordinate: coordinate)
    }
    
    // MARK: View controller life cycle.
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = editButtonItem
        loadLocations()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isTouching = false
        navigationController?.setToolbarHidden(true, animated: false)
        setEditing(false, animated: false)
        updateEditMode()
    }

    //
    //  Configures the view controller for the tapped pin. Passd core data stack and selected location managed object.
    //
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? LocationViewController, let annotation = sender as? LocationAnnotation {
            viewController.dataStack = dataStack
            viewController.coordinate = annotation.coordinate
            
            if let id = annotation.locationId, let model = models[id] {
                viewController.model = model
            }
        }
    }
    
    //
    //  Respond to changes to the editing state when the edit/done toolbar button is tapped.
    //
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        // Show the tip message (ie "tap to remove pin") when in edit mode. Hide the tip when not in edit mode.
        if messageView.isHidden == isEditing {
            UIView.transition(
                with: view,
                duration: 0.25,
                options: [.beginFromCurrentState, .transitionCrossDissolve],
                animations: {
                    self.messageView.isHidden = !self.isEditing
            })
        }
    }
    
    // MARK: Editing 
    
    //
    //  Enable and disable the edit button. The edit button is enabled when there is one or more pins on the map, and 
    //  disabled when the map has no pins.
    //
    fileprivate func updateEditMode() {
        let canEdit = (mapView.annotations.count > 0)
        editButtonItem.isEnabled = canEdit
        
        if !canEdit && isEditing {
            isEditing = false
        }
    }
    
    // MARK: Map annotations
    
    //
    //  Loads locations from core data.
    //
    fileprivate func loadLocations() {
        assert(Thread.isMainThread)
        do {
            let locations = try dataStack.mainContext.allLocations()
            
            // Update map annotations.
            let annotations = locations.map { $0.toAnnotation() }
            mapView.addAnnotations(annotations)
            
            // Load models and resume downloading images.
            for location in locations {
                if let id = location.id {
                    let model = makeModelForLocation(id: id)
                    models[id] = model
                }
            }
        }
        catch {
            showAlert(forError: error)
        }
    }
    
    //
    //  Removes a location from core data in a background queue.
    //
    fileprivate func deleteLocation(id: String, completion: @escaping (Bool) -> Void) {
        if let model = models.removeValue(forKey: id) {
            model.cancelFetching()
            model.deleteLocation(completion: completion)
        }
    }
    
    //
    //  Add a location to the map and core data store. The object is inserted into the background context so that it is 
    //  available when it needs to be removed or modified. Once inserted, the object must be loaded into the main 
    //  context so that it can be be used on the map.
    //
    private func addLocation(coordinate: CLLocationCoordinate2D) {
        dataStack.performBackgroundChanges { (context) in
            do {
                
                // Create and insert the location
                let location = Location(coordinate: coordinate, context: context)
                try context.save()
                let objectID = location.objectID
                
                DispatchQueue.main.async {
                    
                    // Load the location on the main queue.
                    guard let object = try? self.dataStack.mainContext.existingObject(with: objectID), let location = object as? Location, let id = location.id  else {
                        return
                    }
                    
                    // Add the model.
                    let model = self.makeModelForLocation(id: id)
                    self.models[id] = model
                    
                    // Create and add the annotation to the map.
                    let annotation = location.toAnnotation()
                    self.mapView.addAnnotation(annotation)
                    
                    // Exit edit mode if no more pins are on the map.
                    self.updateEditMode()
                }
            }
            catch {
                print("Cannot add location: \(error)")
            }
        }
    }
    
    //
    //
    //
    private func makeModelForLocation(id: String) -> LocationModel {
        let model = LocationModel(
            location: id,
            radius: 20,
            numberOfPhotos: 30,
            dataStack: dataStack)
        model.resumeFetchingPhotos()
        return model
    }
}

//
//
//
extension MapViewController: MKMapViewDelegate {
    
    //
    //  Returns a pin view for a map annotation. The pin is animated if added while the screen is touched, otherwise the
    //  pin appears without animation.
    //
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseIdentifier = "location"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)  as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
        }

        pinView?.animatesDrop = isTouching
        return pinView
    }
    
    //
    //  Respond to tap on a pin on the map. Present the screen for the location of the tapped pin. When editing the pin 
    //  is removed when tapped.
    //
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? LocationAnnotation else {
            return
        }
        mapView.deselectAnnotation(annotation, animated: true)
        if isEditing {
            // Editing mode. Tap on pin to remove.
            if let id = annotation.locationId {
                mapView.removeAnnotation(annotation)
                deleteLocation(id: id) { _ in
                    DispatchQueue.main.async {
                        self.updateEditMode()
                    }
                }
            }
        }
        else {
            // Not editing. Tap pin to show images for location.
            performSegue(withIdentifier: "location", sender: annotation)
        }
    }
}
