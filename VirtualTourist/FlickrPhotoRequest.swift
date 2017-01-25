//
//  FlickrPhotoRequest.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/23.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation
import CoreLocation

struct FlickrPhotosRequest {
    let coordinate: CLLocationCoordinate2D
    let radius: Int
    let itemsPerPage: Int
    let page: Int
}
