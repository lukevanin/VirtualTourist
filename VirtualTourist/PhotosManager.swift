//
//  UpdatePhotosOperation.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/23.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation

class PhotosManager {
    
    typealias DeleteCompletion = (Bool) -> Void
    typealias FetchCompletion = () -> Void
    
    private var lastResponse: FlickrPhotos?
    private var fetchTask: FetchPhotosTask?
    private var downloadTask: DownloadPhotosTask?
    
    private let locationId: String
    private let dataStack: CoreDataStack
    
    init(location: String, dataStack: CoreDataStack) {
        self.locationId = location
        self.dataStack = dataStack
    }

    //
    //
    //
    func deletePhoto(id: NSManagedObjectID, completion: DeleteCompletion?) {
        assert(Thread.isMainThread)
        dataStack.performBackgroundChanges() { context in
            do {
                let photo = try context.existingObject(with: id)
                context.delete(photo)
                try context.save()
                completion?(true)
            }
            catch {
                print("Cannot delete photo: \(error)")
                completion?(true)
            }
        }
    }

    //
    //
    //
    func deletePhotos(completion: DeleteCompletion?) {
        dataStack.performBackgroundChanges() { [locationId] context in
            do {
                let photos = try context.photos(forLocation: locationId)
                for photo in photos {
                    context.delete(photo)
                }
                try context.save()
                completion?(true)
            }
            catch {
                print("Cannot delete photos: \(error)")
                completion?(false)
            }
        }
    }
    
    //
    //
    //
    func cancelFetching() {
        assert(Thread.isMainThread)
        
        downloadTask?.cancel()
        downloadTask = nil

        fetchTask?.cancel()
        fetchTask = nil
    }
    
    //
    //
    //
    func fetchPhotos(coordinate: CLLocationCoordinate2D, radius: Int, numberOfItems: Int, completion: FetchCompletion?) {
        let request = makeRequest(coordinate: coordinate, radius: radius, numberOfItems: numberOfItems)
        fetchTask = FetchPhotosTask(location: locationId, request: request, dataStack: dataStack) { [weak self] (response) in
            DispatchQueue.main.async {
                self?.fetchTask = nil
                self?.lastResponse = response
                self?.downloadImages(completion: completion)
            }
        }
    }
    
    //
    //
    //
    private func makeRequest(coordinate: CLLocationCoordinate2D, radius: Int, numberOfItems: Int) -> FlickrPhotosRequest {
        let page: Int
        
        if let response = lastResponse {
            // Flickr response is limited to 4000 results. 
            // https://www.flickr.com/groups/51035612836@N01/discuss/72157663968579450/
            let maxPage = min(response.pages, 4000 / numberOfItems)
            page = Int(arc4random()) % maxPage
        }
        else {
            page = 1
        }
        
        let request = FlickrPhotosRequest(
            coordinate: coordinate,
            radius: radius,
            itemsPerPage: numberOfItems,
            page: page
        )
        
        return request
    }
    
    //
    //
    //
    func downloadImages(completion: FetchCompletion?) {
        downloadTask = DownloadPhotosTask(location: locationId, dataStack: dataStack) { [weak self] in
            DispatchQueue.main.async {
                self?.downloadTask = nil
            }
        }
    }
}
