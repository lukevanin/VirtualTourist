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
import CoreData

class LocationViewController: UIViewController {
    
    var context: NSManagedObjectContext!
    var location: Location!
    
    fileprivate var photos: [Photo]?
    
    // MARK: Outlets
    
    @IBOutlet weak var mapImageView: UIImageView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var placeholderView: UIView!
    @IBOutlet weak var reloadButton: UIButton!
    @IBOutlet weak var photosActivityIndicator: UIActivityIndicatorView!
    
    override var isEditing: Bool {
        didSet {
            updateEditMode()
        }
    }

    // MARK: Actions
    
    //
    //  "New collection" button tapped. Reload random images from Flickr.
    //
    @IBAction func onReloadAction(_ sender: Any) {
        removePhotos()
        downloadPhotos()
        updateEditMode()
    }
    
    // MARK: View controller life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureMap()
        loadPhotos()
        
        if photos?.count == 0 {
            downloadPhotos()
        }
        
        updateEditMode()
    }
    
    private func configureView() {
        collectionView.addSubview(mapImageView)
        
        let headerHeight: CGFloat = 300
        
        mapImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let constraints = [
            mapImageView.widthAnchor.constraint(equalTo: collectionView.widthAnchor),
            mapImageView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            mapImageView.topAnchor.constraint(lessThanOrEqualTo: topLayoutGuide.bottomAnchor),
            mapImageView.bottomAnchor.constraint(equalTo: collectionView.topAnchor),
            mapImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: headerHeight)
            ]
        NSLayoutConstraint.activate(constraints)
        
        collectionView.contentInset.top = headerHeight
    }
    
    fileprivate func updateEditMode() {
        let canEdit = ((photos?.count ?? 0) > 0)
        navigationItem.rightBarButtonItem = canEdit ? editButtonItem : nil
    }
    
    // MARK: Map
    
    //
    //
    //
    private func configureMap() {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: 1.0,
                longitudeDelta: 1.0
            )
        )
        let options = MKMapSnapshotOptions()
        options.region = region
        options.size = view.bounds.size
        options.scale = UIScreen.main.scale
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { (snapshot, error) in
            guard let snapshot = snapshot else {
                print("Cannot create map snapshot: \(error)")
                return
            }
            self.mapImageView.image = snapshot.image
        }
    }
    
    // MARK: Photos
    
    //
    //
    //
    private func removePhotos() {
        deletePhotos()
        photos = nil
        collectionView?.reloadData()
    }
    
    //
    //
    //
    private func deletePhotos() {
        do {
            let photos = try context.photos(forLocation: location)
            for photo in photos {
                context.delete(photo)
            }
            try context.save()
        }
        catch {
            print("Cannot delete photos: \(error)")
        }
    }
    
    //
    //
    //
    fileprivate func deletePhoto(at index: Int) {
        guard let photo = photos?.remove(at: index) else {
            return
        }
        context.delete(photo)
        do {
            try context.save()
        }
        catch {
            print("Cannot delete photo: \(error)")
        }
    }
    
    //
    //
    //
    private func loadPhotos() {
        do {
            photos = try context.photos(forLocation: location)
            collectionView?.reloadData()
        }
        catch {
            print("Cannot load photos: \(error)")
        }
    }
    
    //
    //
    //
    private func downloadPhotos() {
        let request = FlickrPhotosRequest(
            coordinate: location.coordinate,
            radius: 20,
            itemsPerPage: 18,
            page: 1
        )
        fetchFlickrPhotos(request: request) { response in
            DispatchQueue.main.async {
                guard let photos = response?.photos else {
                    return
                }
                self.insertPhotos(photos)
                self.loadPhotos()
                self.updateEditMode()
                
                if let photos = self.photos {
                    self.downloadPhotos(photos)
                }
            }
        }
    }
    
    //
    //
    //
    private func insertPhotos(_ items: [FlickrPhoto]) {
        for item in items {
            let url = item.imageURL(forSize: .medium)
            let _ = Photo(url: url.absoluteString, location: location, context: context)
        }
        do {
            try context.save()
        }
        catch {
            print("Cannot insert photos: \(error)")
        }
    }
    
    //
    //
    //
    private func downloadPhotos(_ photos: [Photo]) {
        for photo in photos {
            if let url = photo.url {
                downloadPhoto(url: url)
            }
        }
    }
    
    //
    //
    //
    private func downloadPhoto(url: String) {
        guard let requestURL = URL(string: url) else {
            return
        }
        let request = URLRequest(url: requestURL)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                if let data = data {
                    
                    // Update core data store.
                    self.updatePhoto(url: url, data: data)
                    
                    // Update collection view.
                    if let photos = self.photos {
                        var indexPaths = [IndexPath]()
                        for i in 0 ..< photos.count {
                            let photo = photos[i]
                            if photo.url == url {
                                let indexPath = IndexPath(item: i, section: 0)
                                indexPaths.append(indexPath)
                            }
                        }
                        if indexPaths.count > 0 {
                            self.collectionView.performBatchUpdates({
                                self.collectionView.reloadItems(at: indexPaths)
                            }, completion: nil)
                        }
                    }
                }
            }
        }
        task.resume()
    }
    
    //
    //
    //
    private func updatePhoto(url: String, data: Data) {
        do {
            let photos = try context.photos(withURL: url)
            for photo in photos {
                photo.image = data as NSData
            }
            try context.save()
        }
        catch {
            print("Cannot update photo: %@", error)
        }
    }
    
    //
    //
    //
    private func fetchFlickrPhotos(request: FlickrPhotosRequest, completion: @escaping (FlickrPhotos?) -> Void) {
        let flickrKey = "55b886af3fbb96a78db2b14ace620b2f"
//        let flickrSecret = ""
        let baseURL = URL(string: "https://api.flickr.com/services/rest/")
        
        guard var components = URLComponents(url: baseURL!, resolvingAgainstBaseURL: false) else {
            return
        }
        
        let queryItems = [
            URLQueryItem(name: "method", value: "flickr.photos.search"),
            URLQueryItem(name: "api_key", value: flickrKey),
            URLQueryItem(name: "lat", value: String(format: "%0.8f", request.coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(format: "%0.8f", request.coordinate.longitude)),
            URLQueryItem(name: "radius", value: String(format: "%d", request.radius)),
            URLQueryItem(name: "radius_units", value: "km"),
            URLQueryItem(name: "per_page", value: String(format: "%d", request.itemsPerPage)),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "nojsoncallback", value: "1")
            ]
        components.queryItems = queryItems
        
        guard let url = components.url else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            DispatchQueue.main.async {
                guard let data = data else {
                    print("Cannot load photos: \(error)")
                    completion(nil)
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    let photos = try FlickrPhotos(json: json)
                    completion(photos)
                }
                catch {
                    print("Cannot parse photos: \(error)")
                    completion(nil)
                }
            }
        }
        task.resume()
    }
}

//
//  UICollectionView data source and delegate.
//
extension LocationViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath)
        if let cell = cell as? ImageCell {
            if let photo = photos?[indexPath.item], let data = photo.image as? Data {
                let image = UIImage(data: data)
                cell.imageView.image = image
            }
            else {
                cell.activityIndicator.startAnimating()
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditing {
            deletePhoto(at: indexPath.item)
            collectionView.performBatchUpdates({
                collectionView.deleteItems(at: [indexPath])
            }, completion: { _ in
                self.updateEditMode()
            })
        }
    }
}
