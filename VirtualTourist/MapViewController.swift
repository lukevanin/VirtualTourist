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
    
    fileprivate var context: NSManagedObjectContext {
        return self.dataStack.mainContext
    }
    
    fileprivate var locations = [Location]()
    fileprivate var isTouching = false
    
    // MARK: Outlets.
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var messageView: UIView!
    
    // MARK: Actions
    
    @IBAction func onMapLongPressGesture(_ gesture: UIGestureRecognizer) {
        
        guard gesture.state == .began else {
            isTouching = false
            return
        }
        
        isTouching = true
        
        // Convert the gesture location to map coordinates.
        let point = gesture.location(in: view)
        let coordinate = mapView.convert(point, toCoordinateFrom: view)

        // Create and add the location to the core data store.
        let location = Location(coordinate: coordinate, context: dataStack.mainContext)
        locations.append(location)

        // Create and add the annotation to the map.
        let annotation = location.toAnnotation()
        mapView.addAnnotation(annotation)
        
        //
        updateEditMode()

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
        navigationItem.rightBarButtonItem = editButtonItem
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isTouching = false
        navigationController?.setToolbarHidden(true, animated: false)
        setEditing(false, animated: false)
        loadLocations()
        updateEditMode()
        reloadAnnotations()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? LocationViewController, let annotation = sender as? LocationAnnotation {
            let match = locations.first { $0.id == annotation.locationId }
            if let location = match {
                viewController.dataStack = dataStack
                viewController.location = location
            }
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
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
    //
    //
    fileprivate func updateEditMode() {
        let canEdit = (locations.count > 0)
        editButtonItem.isEnabled = canEdit
        
        if !canEdit && isEditing {
            isEditing = false
        }
    }
    
    // MARK: Map annotations
    
    //
    //
    //
    fileprivate func loadLocations() {
        do {
            locations = try context.allLocations()
        }
        catch {
            showAlert(forError: error)
        }
    }
    
    //
    //
    //
    fileprivate func deleteLocation(withId id: String, completion: @escaping () -> Void) {
        dataStack.performBackgroundChanges() { context in
            do {
                let locations = try context.locations(withId: id)
                guard locations.count > 0 else {
                    return
                }
                for location in locations {
                    context.delete(location)
                }
                try context.save()
            }
            catch {
                print("Cannot delete location: \(error)")
            }
            completion()
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
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)  as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
        }

        pinView?.animatesDrop = isTouching
        return pinView
    }
    
    //
    //
    //
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? LocationAnnotation else {
            return
        }
        if isEditing {
            // Editing. Tap on pin to remove.
            if let id = annotation.locationId {
                mapView.removeAnnotation(annotation)
                deleteLocation(withId: id) {
                    DispatchQueue.main.async {
                        self.loadLocations()
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
