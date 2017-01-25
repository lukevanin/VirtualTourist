//
//  FlickrService.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/23.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation

private let flickrKey = "55b886af3fbb96a78db2b14ace620b2f"

struct FlickrService {
    
    typealias PhotosCompletion = (FlickrPhotos?, Error?) -> Void
    
    //
    //
    //
    func fetchPhotos(request: FlickrPhotosRequest, completion: @escaping PhotosCompletion) -> URLSessionDataTask {

        let baseURL = URL(string: "https://api.flickr.com/services/rest/")
        var components = URLComponents(url: baseURL!, resolvingAgainstBaseURL: false)
        
        let queryItems = [
            URLQueryItem(name: "method", value: "flickr.photos.search"),
            URLQueryItem(name: "api_key", value: flickrKey),
            URLQueryItem(name: "lat", value: String(format: "%0.8f", request.coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(format: "%0.8f", request.coordinate.longitude)),
            URLQueryItem(name: "radius", value: String(format: "%d", request.radius)),
            URLQueryItem(name: "radius_units", value: "km"),
            URLQueryItem(name: "page", value: String(format: "%d", request.page)),
            URLQueryItem(name: "per_page", value: String(format: "%d", request.itemsPerPage)),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "nojsoncallback", value: "1")
        ]
        components!.queryItems = queryItems
        let url = components!.url
        
        let task = URLSession.shared.dataTask(with: url!) { (data, response, error) in
            DispatchQueue.main.async {
                guard let data = data else {
                    print("Cannot load photos: \(error)")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    let photos = try FlickrPhotos(json: json)
                    completion(photos, nil)
                }
                catch {
                    print("Cannot parse photos: \(error)")
                    completion(nil, error)
                }
            }
        }
        task.resume()
        return task
    }

}
