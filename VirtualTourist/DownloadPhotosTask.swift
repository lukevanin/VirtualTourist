//
//  UpdatePhotosOperation.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/24.
//  Copyright © 2017 Luke Van In. All rights reserved.
//
//  Downloads a collection of flickr photos from and saves them to the core data store.
//

import Foundation

class DownloadPhotosTask {
    
    typealias Completion = () -> Void
    
    var isCancelled: Bool = false
    
    private var tasks = [URLSessionTask]()
    
    private let locationId: String
    private let dataStack: CoreDataStack
    private let completion: Completion
    private let dispatchGroup: DispatchGroup
    
    init(location id: String, dataStack: CoreDataStack, completion: @escaping Completion) {
        self.locationId = id
        self.dataStack = dataStack
        self.completion = completion
        self.dispatchGroup = DispatchGroup()
        self.execute()
    }
    
    //
    //  Cancels any pending download tasks.
    //
    func cancel() {
        assert(Thread.isMainThread)
        isCancelled = true
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
    
    //
    //
    //
    private func execute() {
        
        self.enqueueDownloads() { tasks in
            self.downloadPhotos()
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let `self` = self, !self.isCancelled else {
                return
            }
            self.completion()
        }
    }
    
    //
    //
    //
    private func enqueueDownloads(completion: @escaping () -> Void) {
        dispatchGroup.enter()
        dataStack.performBackgroundChanges { [weak self, locationId] (context) in
            guard let `self` = self else {
                return
            }
            do {
                let photos = try context.photos(forLocation: locationId)
                for photo in photos {
                    if let url = photo.url, let imageURL = URL(string: url), photo.image == nil {
                        let task = self.downloadPhoto(url: imageURL)
                        self.tasks.append(task)
                    }
                }
            }
            catch {
                print("Cannot enqueue photos: \(error)")
            }
            completion()
            self.dispatchGroup.leave()
        }
    }
    
    //
    //
    //
    private func downloadPhoto(url: URL) -> URLSessionDataTask {
        dispatchGroup.enter()
        let request = URLRequest(url: url)
        return URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            if let data = data {
                self?.savePhoto(url: url.absoluteString, data: data)
            }
            else {
                print("Cannot download photo: \(error)")
            }
            self?.dispatchGroup.leave()
        }
    }
    
    //
    //
    //
    private func downloadPhotos() {
        for task in tasks {
            task.resume()
        }
    }
    
    //
    //
    //
    private func savePhoto(url: String, data: Data) {
        self.dispatchGroup.enter()
        dataStack.performBackgroundChanges() { [weak self] context in
            guard let `self` = self else {
                return
            }
            do {
                let photos = try context.photos(withURL: url)
                for photo in photos {
                    photo.image = data as NSData
                }
                
                if !self.isCancelled {
                    try context.save()
                }
            }
            catch {
                print("Cannot update photo: %@", error)
            }
            
            self.dispatchGroup.leave()
        }
    }
   
}
