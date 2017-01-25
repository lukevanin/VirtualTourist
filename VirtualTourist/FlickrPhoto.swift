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
            throw FlickrError.invalidContent
        }
        self.id = id
        self.farm = farm
        self.server = server
        self.secret = secret
        self.title = title
    }
}
