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
    
    convenience init(ordering: Int, url: String, largeURL: String, location: Location, context: NSManagedObjectContext) {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            fatalError("Cannot initialize entity \(entityName)")
        }
        self.init(entity: entity, insertInto: context)
        self.ordering = Int16(ordering)
        self.url = url
        self.largeURL = largeURL
        self.location = location
    }
}

extension NSManagedObjectContext {
    
    //
    //  Retrieve all photos for a specific location
    //
    func photos(location id: String) throws -> [Photo] {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.predicate = NSPredicate(format: "location.id == %@", id)
        return try fetch(request)
    }
    
    //
    //
    //
    func photos(location id:String, url: String) throws -> [Photo] {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.predicate = NSCompoundPredicate.init(andPredicateWithSubpredicates: [
            NSPredicate(format: "location.id == %@", id),
            NSPredicate(format: "url == %@", url)
            ])
        return try fetch(request)
    }
}
