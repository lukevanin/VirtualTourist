//
//  Location.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation
import MapKit

private let entityName = "Location"

//
//  Map kit extensions.
//
extension Location {
    
    //
    //  Convenience property for acccessing the location coordinates as a CoreLocation coordinate entity.
    //
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
        }
        set {
            self.latitude = newValue.latitude
            self.longitude = newValue.longitude
        }
    }
    
    //
    //  Initialize the location with a core location coordinate, and insert it into a context.
    //
    convenience init(coordinate: CLLocationCoordinate2D, context: NSManagedObjectContext) {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            fatalError("Cannot initialize entity \(entityName)")
        }
        self.init(entity: entity, insertInto: context)
        self.coordinate = coordinate
    }
    
    //
    //  Convenience function for creating map kit annotations from a location instance.
    //
    func toAnnotation() -> MKAnnotation {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        return annotation
    }
}

//
//  Core data stack extensions for querying locations.
//
extension CoreDataStack {
    
    //
    //  Retrieve all locations.
    //
    func fetchLocations() throws -> [Location] {
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        return try mainContext.fetch(request)
    }
}
