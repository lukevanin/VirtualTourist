//
//  LocationViewController.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//
//  Shows information for a specific location. The location is shown as a static pin on a map. Images for the location
//  are downloaded and shown.
//

import UIKit
import MapKit

class LocationViewController: UIViewController {
    
    var dataStack: CoreDataStack!
    var location: Location!
    
    fileprivate var photos: [Photo]?
    
    // MARK: Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var placeholderView: UIView!
    @IBOutlet weak var reloadButton: UIButton!

    // MARK: Actions
    
    //
    //  "New collection" button tapped. Reload random images from Flickr.
    //
    @IBAction func onReloadAction(_ sender: Any) {
        downloadPhotos()
    }
    
    // MARK: View controller life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPhotos()
    }
}

//
// Functionality for loading photos from core data and flickr.
//
extension LocationViewController {
    
    //
    //
    //
    func loadPhotos() {
        // TODO: Load photos for location. If location does not have any photos then automatically load from Flickr.
    }
    
    //
    //
    //
    func downloadPhotos() {
        // TODO: Download photos from flickr. Insert photos into core data and refresh the cell as each photo is downloaded.
    }
}

//
//  UICollectionView data source.
//
extension LocationViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath)
        if let cell = cell as? ImageCell, let photo = photos?[indexPath.item], let data = photo.image as? Data {
            let image = UIImage(data: data)
            cell.imageView.image = image
        }
        return cell
    }
}

//
//  UICollectionView delegate.
//
extension LocationViewController: UICollectionViewDelegate {
    
}
