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
    
    enum Change {
        case update(IndexPath)
        case insert(IndexPath)
        case delete(IndexPath)
    }
    
    var dataStack: CoreDataStack!
    var location: Location!
    
    fileprivate lazy var model: PhotosManager = { [unowned self] in
        let manager = PhotosManager(
            location: self.location.id!,
            dataStack: self.dataStack)
        return manager
    }()
    
    fileprivate lazy var fetchedResultsController: NSFetchedResultsController<Photo> = { [unowned self] in
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "ordering", ascending: true)]
        if let id = self.location.id {
            request.predicate = NSPredicate(format: "location.id == %@", id)
        }
        
        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: self.dataStack.mainContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        controller.delegate = self
        return controller
    }()
    
    override var isEditing: Bool {
        didSet {
            updateEditMode()
        }
    }
    
    fileprivate var photos = [Photo]() {
        didSet {
            let hadPhotos = (oldValue.count > 0)
            let hasPhotos = (photos.count > 0)
            if hadPhotos != hasPhotos {
                self.applyCurrentState(animated: true)
            }
        }
    }
    fileprivate var isFetching: Bool = false
    fileprivate var changes: [Change]?
    
    // MARK: Outlets
    
    @IBOutlet weak var mapImageView: UIImageView!
    @IBOutlet weak var mapView: UIView!
    @IBOutlet weak var mapActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var pinImageView: UIImageView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var reloadButtonItem: UIBarButtonItem!
    @IBOutlet weak var placeholderView: UIView!
    @IBOutlet weak var photosActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var placeholderLabel: UILabel!
    @IBOutlet weak var messageView: UIView!

    // MARK: Actions
    
    //
    //  "New collection" button tapped. Reload random images from Flickr.
    //
    @IBAction func onReloadAction(_ sender: Any) {
        refreshPhotos()
    }
    
    // MARK: View controller life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = editButtonItem
        navigationController?.toolbar.barTintColor = UIColor(
            red: 53.0 / 255.0,
            green: 83.0 / 255.0,
            blue: 147.0 / 255.0,
            alpha: 1.0)
        configurePlaceholderView()
        configureMapView()
        configureMap()
        applyCurrentState(animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.layoutIfNeeded()
        setEditing(false, animated: false)
        loadPhotos()
        refreshPhotosIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        model.cancelFetching()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        configureCellLayout()
        configureCollectionViewInset()
    }
    
//    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        coordinator.animate(alongsideTransition: { (_) in
//            self.configureCollectionViewInset()
//            self.configureCellLayout()
//        }) { (_) in
//        }
//    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? ImageViewController, let url = sender as? URL {
            viewController.imageURL = url
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if navigationController?.isToolbarHidden != editing {
            navigationController?.setToolbarHidden(editing, animated: animated)
        }
        
        if messageView.isHidden == isEditing {
            UIView.transition(
                with: view,
                duration: 0.25,
                options: [.beginFromCurrentState, .transitionCrossDissolve],
                animations: {
                    self.messageView.isHidden = !self.isEditing
            })
        }
    }
    
    // MARK: Placeholder
    
    //
    //
    //
    private func configurePlaceholderView() {
        collectionView.addSubview(placeholderView)
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            placeholderView.widthAnchor.constraint(equalTo: collectionView.widthAnchor),
            placeholderView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            placeholderView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
    }
    
    // MARK: State
    
    
    //
    //
    //
    fileprivate func setFetching(fetching: Bool, animated: Bool) {
        guard isFetching != fetching else {
            return
        }
        isFetching = fetching
        applyCurrentState(animated: animated)
    }
    
    //
    //
    //
    fileprivate func applyCurrentState(animated: Bool) {
    
        let hasPhotos = (photos.count > 0)
        let showActivity = isFetching && !hasPhotos
        let showLabel = !isFetching && !hasPhotos
        let showPlaceholder = showLabel || showActivity

        func configureView() {
            placeholderView.isHidden = !showPlaceholder
            placeholderLabel.isHidden = !showLabel
        }

        if animated {
            UIView.transition(
                with: view,
                duration: 0.25,
                options: [.beginFromCurrentState, .transitionCrossDissolve],
                animations: {
                    configureView()
            })
        }
        else {
            configureView()
        }
        
        if showActivity {
            photosActivityIndicator.startAnimating()
        }
        else {
            photosActivityIndicator.stopAnimating()
        }
    }
    
    fileprivate func updateEditMode() {
        let canEdit = (photos.count > 0)
        editButtonItem.isEnabled = canEdit
        
        if !canEdit && isEditing {
            isEditing = false
        }
    }

    // MARK: Map

    //
    //
    //
    private func configureMapView() {
        collectionView.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            mapView.widthAnchor.constraint(equalTo: collectionView.widthAnchor),
            mapView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            mapView.topAnchor.constraint(lessThanOrEqualTo: topLayoutGuide.bottomAnchor),
            mapView.bottomAnchor.constraint(equalTo: collectionView.topAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
    }
    
    //
    //
    //
    private func configureCollectionViewInset() {
        let viewSize = view.bounds.size
        let maximumHeight = viewSize.height - 140
        let headerHeight: CGFloat = min(viewSize.width, maximumHeight)
        collectionView.contentInset.top = headerHeight
    }
    
    //
    //
    //
    private func configureCellLayout() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }

        let idealSize: CGFloat = 105
        let viewSize = view.bounds.size
        let margin = layout.sectionInset.left + layout.sectionInset.right
        let availableSpace = viewSize.width - margin
        let numberOfItems = round(availableSpace / idealSize)
        let numberOfSpaces = numberOfItems - 1
        let actualSize = floor((availableSpace - numberOfSpaces) / numberOfItems)
        layout.itemSize = CGSize(width: actualSize, height: actualSize)
    }

    //
    //
    //
    private func configureMap() {
        let pinView = MKPinAnnotationView(annotation: nil, reuseIdentifier: nil)
        pinImageView.image = pinView.image
        
        if let data = location.mapImage, let image = UIImage(data: data as Data, scale: UIScreen.main.scale) {
            mapImageView.image = image
        }
        else {
            mapActivityIndicator.startAnimating()
            pinImageView.isHidden = true
            loadMapImage() { [weak self] image in
                DispatchQueue.main.async {
                    guard let `self` = self else {
                        return
                    }
                    self.mapActivityIndicator.stopAnimating()
                    UIView.transition(
                        with: self.view,
                        duration: 0.25,
                        options: [.beginFromCurrentState, .transitionCrossDissolve],
                        animations: {
                            self.mapImageView.image = image
                            self.pinImageView.isHidden = false
                    })
                    
                    if let image = image {
                        self.saveMapImage(image: image)
                    }
                }
            }
        }
    }
    
    //
    //
    //
    private func loadMapImage(completion: @escaping (UIImage?) -> Void) {

        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: 1.0,
                longitudeDelta: 1.0
            )
        )
        
        let viewSize = view.bounds.size
        let dimension = max(viewSize.width, viewSize.height)
        let size = CGSize(width: dimension, height: dimension)
        
        let options = MKMapSnapshotOptions()
        options.region = region
        options.size = size
        options.scale = UIScreen.main.scale
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { (snapshot, error) in
            completion(snapshot?.image)
        }
    }
    
    //
    //
    //
    private func saveMapImage(image: UIImage) {
        let objectId = location.objectID
        dataStack.performBackgroundChanges { (context) in
            guard let data = UIImagePNGRepresentation(image) else {
                return
            }
            do {
                let location = try context.existingObject(with: objectId) as? Location
                location?.mapImage = data as NSData
                try context.save()
            }
            catch {
                print("Cannot save map image: \(error)")
            }
        }
    }
    
    // MARK: Photos
    
    //
    //
    //
    private func loadPhotos() {
        do {
            try fetchedResultsController.performFetch()
            photos = fetchedResultsController.fetchedObjects ?? []
            collectionView.reloadData()
            updateEditMode()
            applyCurrentState(animated: true)
        }
        catch {
            print("Cannot load photos: \(error)")
        }
    }
    
    //
    //
    //
    private func refreshPhotosIfNeeded() {
        if photos.count == 0 {
            refreshPhotos()
        }
        else {
            model.downloadImages(completion: nil)
        }
    }
    
    //
    //
    //
    private func refreshPhotos() {
        model.cancelFetching()
        setFetching(fetching: true, animated: true)
        model.deletePhotos() { [weak self] _ in
            guard let location = self?.location else {
                return
            }
            self?.model.fetchPhotos(coordinate: location.coordinate, radius: 20, numberOfItems: 30) {
                self?.setFetching(fetching: false, animated: true)
            }
        }
    }
    
}

//
//
//
extension LocationViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        changes = []
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch (type, indexPath, newIndexPath) {
        case (.delete, .some(let indexPath), _):
            changes?.append(.delete(indexPath))
            
        case (.insert, _, .some(let newIndexPath)):
            changes?.append(.insert(newIndexPath))
            
        case (.move, .some(let indexPath), .some(let newIndexPath)):
            changes?.append(.delete(indexPath))
            changes?.append(.insert(newIndexPath))
            
        case (.update, .some(let indexPath), _):
            changes?.append(.update(indexPath))
            
        default:
            print("Unsupported update: \(type) \(indexPath) \(newIndexPath)")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let changes = changes, changes.count > 0 else {
            return
        }
        self.changes = nil
        self.photos = (controller.fetchedObjects as? [Photo]) ?? []
        collectionView.performBatchUpdates({
            for change in changes {
                switch change {
                case .insert(let indexPath):
                    self.collectionView.insertItems(at: [indexPath])
                    
                case .delete(let indexPath):
                    self.collectionView.deleteItems(at: [indexPath])
                    
                case .update(let indexPath):
                    self.collectionView.reloadItems(at: [indexPath])
                }
            }
        }, completion: { (finished) in
            if finished {
                self.updateEditMode()
            }
        })
    }
}

//
//  UICollectionView data source and delegate.
//
extension LocationViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath)
        if let cell = cell as? ImageCell {
            let photo = photos[indexPath.item]
            if let data = photo.image as? Data {
                let image = UIImage(data: data, scale: UIScreen.main.scale)
                cell.imageView.image = image
            }
            else {
                cell.activityIndicator.startAnimating()
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photo = photos[indexPath.item]
        if isEditing {
            model.cancelFetching()
            model.deletePhoto(id: photo.objectID, completion: nil)
        }
        else {
            if let url = photo.largeURL, let imageURL = URL(string: url) {
                performSegue(withIdentifier: "image", sender: imageURL)
            }
        }
    }
}
