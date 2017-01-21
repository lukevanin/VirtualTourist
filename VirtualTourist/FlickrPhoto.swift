//
//  FlickrPhoto.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/21.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation
import CoreLocation
    
enum FlickrPhotoSize: String {
    case small = "m"
    case smallSquare = "s"
    case thumbnail = "t"
    case medium = "z"
    case large = "b"
}

struct FlickrPhotosRequest {
    let coordinate: CLLocationCoordinate2D
    let radius: Int
    let itemsPerPage: Int
    let page: Int
}

struct FlickrPhoto {
    let id: String
    let farm: Int
    let server: String
    let secret: String
    let title: String
}

extension FlickrPhoto {
    
    func imageURL(forSize size: FlickrPhotoSize) -> URL {
        let string = "https://farm\(farm).staticflickr.com/\(server)/\(id)_\(secret)_\(size.rawValue).jpg"
        return URL(string: string)!
    }
}

struct FlickrPhotos {
    let page: Int
    let pages: Int
    let itemsPerPage: Int
    let photos: [FlickrPhoto]
}

enum FlickrPhotosError: Error {
    case invalidContent
}

extension FlickrPhoto {
    
    init(json: Any) throws {
        guard
            let entity = json as? [String: Any],
            let id = entity["id"] as? String,
            let secret = entity["secret"] as? String,
            let server = entity["server"] as? String,
            let farm = entity["farm"] as? Int,
            let title = entity["title"] as? String
        else {
            throw FlickrPhotosError.invalidContent
        }
        self.id = id
        self.farm = farm
        self.server = server
        self.secret = secret
        self.title = title
    }
}

extension FlickrPhotos {
    
    init(json: Any) throws {
        guard let contents = json as? [String: Any],
            let photos = contents["photos"] as? [String: Any],
            let page = photos["page"] as? Int,
            let pages = photos["pages"] as? Int,
            let perPage = photos["perpage"] as? Int,
            let photo = photos["photo"] as? [[String: Any]]
        else {
            throw FlickrPhotosError.invalidContent
        }
        
        self.page = page
        self.pages = pages
        self.itemsPerPage = perPage
        self.photos = try photo.map { try FlickrPhoto(json: $0) }
    }
}
