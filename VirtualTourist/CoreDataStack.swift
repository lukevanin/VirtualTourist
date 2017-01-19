//
//  CoreDataStack.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//
//  Provides managed object contexts and helper methods for interacting with a core data store.
//
//  For safety, changes should only be made by calling performChanges() passing a block which implement the desired 
//  modifications.
//
//  Data which needs to be made available to the app, such as for displaying in the UI, should be obtained from
//  mainContext. Queries to mainContext should only be done on the main queue.
//

import Foundation
import CoreData

struct CoreDataStack {
    
    let name: String
    let mainContext: NSManagedObjectContext
    
    fileprivate let backgroundContext: NSManagedObjectContext
    
    init(name: String) throws {
        try self.init(name: name, bundle: Bundle.main)
    }
    
    init(name: String, bundle: Bundle) throws {
        self.name = name

        let modelURL = bundle.bundleURL.appendingPathComponent(name).appendingPathExtension("momd")
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let storeURL = documentsDirectory!.appendingPathComponent(name).appendingPathExtension("model")
        
        print("====================")
        print("Initializing Core Data")
        print("Managed Object Model: \(modelURL)")
        print("Persistent Store: \(storeURL)")
        print("====================")
        

        // Load model.
        let model = NSManagedObjectModel(contentsOf: modelURL)
        
        if (model == nil) {
            fatalError("Cannot load model.")
        }
        
        // Create persistent store coordinator.
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model!)
        
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        try persistentStoreCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
        
        // Create background managed object context on private queue. Used for persisting data to fixed storage.
        backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.persistentStoreCoordinator = persistentStoreCoordinator
        
        // Create context on main queue. Used for reading data from the store.
        mainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainContext.parent = backgroundContext
    }
}

//extension CoreDataStack {
//    
//    //
//    //  Execute a block on the change context. Any changes
//    //
//    func performChanges(block: @escaping (NSManagedObjectContext) throws -> Void) throws {
//        var outputError: Error?
//        changeContext.perform() {
//            do {
//                // Perform the insertion.
//                try block(self.changeContext)
//            
//                // Propogate insertions to the background context so that they are persisted when the background context 
//                // is saved.
//                if self.mainContext.hasChanges {
//                    try self.mainContext.save()
//                }
//            }
//            catch {
//                // Capture the error to re-propogate to the caller.
//                outputError = error
//            }
//        }
//        
//        if let error = outputError {
//            throw error
//        }
//    }
//}

extension CoreDataStack {
    
    //
    //
    //
    func autosave(every seconds: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            self.saveNow()
            self.autosave(every: seconds)
        }
    }
    
    //
    //  Save the background context and persist any pending changes to fixed storage.
    //
    func saveNow() {
        backgroundContext.perform() {
            guard self.backgroundContext.hasChanges else {
                // No pending changes.
                return
            }

            print("Saving background context")

            do {
                try self.backgroundContext.save()
            }
            catch {
                print("Cannot save background context. Reason: \(error)")
            }
        }
    }
}
