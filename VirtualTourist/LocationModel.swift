//
//  LocationModel.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/23.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation
import MapKit

extension NSNotification.Name {
    static let DidStartFetchingPhotosForLocation = NSNotification.Name("DidStartFetchingPhotosForLocation")
    static let DidFinishFetchingPhotosForLocation = NSNotification.Name("DidFinishFetchingPhotosForLocation")
}

class LocationModel {
    
    typealias DeleteCompletion = (Bool) -> Void
    typealias FetchCompletion = () -> Void
    typealias InsertCompletion = (LocationModel?) -> Void
    
    var isFetchingPhotos: Bool {
        return (photosFetcher != nil)
    }
    
    private var lastResponse: FlickrPhotos?
    private var photosFetcher: FetchPhotosTask?
    
    fileprivate let downloader: PhotosDownloader
    fileprivate let locationId: String
    fileprivate let radius: Int
    fileprivate let numberOfPhotos: Int
    fileprivate let dataStack: CoreDataStack
    
    
    init(location: String, radius: Int, numberOfPhotos: Int, dataStack: CoreDataStack) {
        self.locationId = location
        self.radius = radius
        self.numberOfPhotos = numberOfPhotos
        self.dataStack = dataStack
        self.downloader = PhotosDownloader(location: location, dataStack: dataStack)
    }
    
    // MARK: Location
    
    //
    //
    //
    func deleteLocation(completion: DeleteCompletion?) {
        dataStack.performBackgroundChanges() { [dataStack, locationId] context in
            do {
                let locations = try context.locations(withId: locationId)
                for location in locations {
                    context.delete(location)
                }
                try context.save()
                context.processPendingChanges()
                DispatchQueue.main.async {
                    dataStack.saveNow()
                    completion?(true)
                }
            }
            catch {
                print("Cannot delete location: \(error)")
                completion?(false)
            }
        }
    }
    
    // MARK: Photos
    
    //
    //
    //
    func cancelDownloadingPhoto(url: String) {
        downloader.cancelDownload(url: url)
    }

    //
    //
    //
    func deletePhoto(url: String, completion: DeleteCompletion?) {
        assert(Thread.isMainThread)
        dataStack.performBackgroundChanges() { [dataStack, locationId] context in
            do {
                let photos = try context.photos(location: locationId, url: url)
                for photo in photos {
                    context.delete(photo)
                }
                try context.save()
                context.processPendingChanges()
                DispatchQueue.main.async {
                    dataStack.saveNow()
                    completion?(true)
                }
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
    func resumeFetchingPhotos() {
        assert(Thread.isMainThread)
        guard !isFetchingPhotos else {
            // Already fetching photos.
            return
        }
        do {
            let photos = try dataStack.mainContext.photos(location: locationId)
            if photos.count == 0 {
                // No photos loaded. Fetch some photos.
                fetchPhotos()
            }
            else {
                // Photos entries exist. Download images if needed.
                downloadImages()
            }
        }
        catch {
            print("Cannot resume downloads. \(error)")
        }
    }
    
    //
    //
    //
    func refreshPhotos() {
        cancelFetching()
        deletePhotos() { [weak self] _ in
            DispatchQueue.main.async {
                self?.fetchPhotos()
            }
        }
    }

    //
    //
    //
    func deletePhotos(completion: DeleteCompletion?) {
        dataStack.performBackgroundChanges() { [dataStack, locationId] context in
            do {
                let photos = try context.photos(location: locationId)
                for photo in photos {
                    context.delete(photo)
                }
                try context.save()
                context.processPendingChanges()
                DispatchQueue.main.async {
                    dataStack.saveNow()
                    completion?(true)
                }
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
        downloader.cancelAllDownloads()
        photosFetcher?.cancel()
        photosFetcher = nil
    }
    
    //
    //
    //
    func fetchPhotos() {
        assert(Thread.isMainThread)
        guard photosFetcher == nil else {
            // Already fetching photos
            return
        }
        guard let locations = try? dataStack.mainContext.locations(withId: locationId), let location = locations.first else {
            // Location no longer exists.
            return
        }
        let coordinate = location.coordinate
        let request = makeRequest(coordinate: coordinate, radius: radius, numberOfItems: numberOfPhotos)
        photosFetcher = FetchPhotosTask(location: locationId, request: request, dataStack: dataStack) { [weak self] (response) in
            DispatchQueue.main.async {
                self?.photosFetcher = nil
                self?.lastResponse = response
                self?.downloadImages()
                NotificationCenter.default.post(name: .DidFinishFetchingPhotosForLocation, object: self)
            }
        }
        NotificationCenter.default.post(name: .DidStartFetchingPhotosForLocation, object: self)
        photosFetcher?.execute()
    }
    
    //
    //  Choose a random page based on the number of pages returned in the last response.
    //  Ensure that the page is within the first 4000 entries. Beyond this flickr just returns the first page.
    //  https://www.flickr.com/groups/51035612836@N01/discuss/72157663968579450/
    //
    private func makeRequest(coordinate: CLLocationCoordinate2D, radius: Int, numberOfItems: Int) -> FlickrPhotosRequest {

        let maxPage: Int
        let totalPages = 4000 / numberOfItems

        if let response = lastResponse {
            maxPage = min(response.pages, totalPages)
        }
        else {
            maxPage = totalPages
        }

        let page = Int(arc4random()) % maxPage
        
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
    func downloadImages() {
        downloader.resumeDownloads()
    }
}

extension LocationModel {
    
    //
    //  Instantiate a FetchedResultsController returning photos for the current location. Uses a context on the main 
    //  queue.
    //
    func makePhotosFetchedResultsController() -> NSFetchedResultsController<Photo> {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "ordering", ascending: true)]
        request.predicate = NSPredicate(format: "location.id == %@", locationId)
        
        return NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: dataStack.mainContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
    }
}
