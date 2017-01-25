//
//  FlickrPhotos.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/23.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation

struct FlickrPhotos {
    let page: Int
    let pages: Int
    let itemsPerPage: Int
    let photos: [FlickrPhoto]
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
                throw FlickrError.invalidContent
        }
        
        self.page = page
        self.pages = pages
        self.itemsPerPage = perPage
        self.photos = try photo.map { try FlickrPhoto(json: $0) }
    }
}
