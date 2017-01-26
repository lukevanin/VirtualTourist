//
//  PhotosFetcher.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/24.
//  Copyright © 2017 Luke Van In. All rights reserved.
//
//  Fetches a list of photos from flickr.
//

import Foundation

class FetchPhotosTask {
    
    typealias Completion = (FlickrPhotos?) -> Void
    
    var isCancelled: Bool = false
    
    private var task: URLSessionDataTask?
    
    private let locationId: String
    private let request: FlickrPhotosRequest
    private let dataStack: CoreDataStack
    private let completion: Completion
    
    init(location id: String, request: FlickrPhotosRequest, dataStack: CoreDataStack, completion: @escaping Completion) {
        self.locationId = id
        self.request = request
        self.dataStack = dataStack
        self.completion = completion
    }
    
    //
    //
    //
    func cancel() {
        isCancelled = true
        task?.cancel()
        task = nil
    }
    
    //
    //
    //
    func execute() {
        fetchPhotos() { [weak self] response in
            guard let `self` = self, !self.isCancelled else {
                return
            }
            self.completion(response)
        }
    }
    
    //
    //
    //
    private func fetchPhotos(completion: @escaping Completion) {
        let service = FlickrService()
        task = service.fetchPhotos(request: request) { [weak self] response, error in
            if let photos = response?.photos {
                self?.insertPhotos(photos: photos) {
                    completion(response)
                }
            }
            else {
                completion(nil)
            }
        }
        task?.resume()
    }

    //
    //
    //
    private func insertPhotos(photos: [FlickrPhoto], completion: @escaping () -> Void) {
        dataStack.performBackgroundChanges() { [weak self, locationId] context in
            guard let `self` = self else {
                return
            }
            
            do {
                let locations = try context.locations(withId: locationId)
                
                var i = 0
                for location in locations {
                    for photo in photos {
                        let url = photo.imageURL(forSize: .small)
                        let largeURL = photo.imageURL(forSize: .large)
                        let _ = Photo(
                            ordering: i,
                            url: url.absoluteString,
                            largeURL: largeURL.absoluteString,
                            location: location,
                            context: context
                        )
                        i += 1
                    }
                }
                
                // Save changed
                if !self.isCancelled {
                    try context.save()
                }
            }
            catch {
                print("Cannot insert photos: \(error)")
            }

            completion()
        }
    }
}
