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

class PhotosDownloader {
    
    private var tasks = [String : URLSessionTask]()
    
    private let locationId: String
    private let dataStack: CoreDataStack
    
    init(location id: String, dataStack: CoreDataStack) {
        self.locationId = id
        self.dataStack = dataStack
    }
    
    //
    //  Cancels all pending download tasks.
    //
    func cancelAllDownloads() {
        assert(Thread.isMainThread)
        for (_ , task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
    
    //
    //
    //
    func cancelDownload(url: String) {
        assert(Thread.isMainThread)
        guard let task = tasks.removeValue(forKey: url) else {
            return
        }
        task.cancel()
    }
    
    //
    //
    //
    func resumeDownloads() {
        assert(Thread.isMainThread)
        self.enqueueDownloads() { tasks in
            self.resumeTasks()
        }
    }
    
    //
    //
    //
    private func enqueueDownloads(completion: @escaping () -> Void) {
        dataStack.performBackgroundChanges { [weak self, locationId] (context) in
            guard let `self` = self else {
                return
            }
            do {
                let photos = try context.photos(location: locationId)
                for photo in photos {
                    if let url = photo.url, photo.image == nil {
                        self.addTask(url: url)
                    }
                }
            }
            catch {
                print("Cannot enqueue photos: \(error)")
            }
            completion()
        }
    }
    
    //
    //
    //
    private func addTask(url: String) {
        guard let requestURL = URL(string: url), tasks[url] == nil else {
            return
        }
        let request = URLRequest(url: requestURL)
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            if let data = data {
                self?.savePhoto(url: url, data: data)
            }
            else {
                print("Cannot download photo: \(error)")
            }
        }
        tasks[url] = task
    }
    
    //
    //
    //
    private func resumeTasks() {
        for (_, task) in tasks {
            task.resume()
        }
    }
    
    //
    //
    //
    private func savePhoto(url: String, data: Data) {
        dataStack.performBackgroundChanges() { [weak self, locationId] context in
            do {
                let photos = try context.photos(location: locationId, url: url)
                for photo in photos {
                    photo.image = data as NSData
                }
                
                let task = DispatchQueue.main.sync { self?.tasks.removeValue(forKey: url) }

                // Task must exist and not be cancelled.
                if let task = task, task.state != .canceling, task.state != .suspended {
                    try context.save()
                }
            }
            catch {
                print("Cannot update photo: %@", error)
            }
        }
    }
   
}
