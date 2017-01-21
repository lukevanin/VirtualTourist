//
//  Photo.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation
import CoreData

private let entityName = "Photo"

extension Photo {
    
    convenience init(url: String, location: Location, context: NSManagedObjectContext) {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            fatalError("Cannot initialize entity \(entityName)")
        }
        self.init(entity: entity, insertInto: context)
        self.url = url
        self.location = location
    }
}

extension NSManagedObjectContext {
    
    //
    //  Retrieve all photos for a specific location
    //
    func photos(forLocation location: Location) throws -> [Photo] {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.predicate = NSPredicate(format: "location == %@", location)
        return try fetch(request)
    }
    
    //
    //
    //
    func photos(withURL url: String) throws -> [Photo] {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.predicate = NSPredicate(format: "url == %@", url)
        return try fetch(request)
    }
}
