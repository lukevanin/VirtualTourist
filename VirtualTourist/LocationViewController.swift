//
//  LocationViewController.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//
//  Shows information for a specific location. The location is shown as a static pin on a map. Images for the location
//  are downloaded and cached in core data.
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

    var coordinate: CLLocationCoordinate2D!
    var model: LocationModel!
    var dataStack: CoreDataStack!
    
    //
    //  Fetched results controller for providing Photo objects from core data. Notifies the view controller when changes 
    //  are made to the photos for the current location (ie when photos are inserted or deleted).
    //
    fileprivate lazy var fetchedResultsController: NSFetchedResultsController<Photo> = { [unowned self] in
        let controller = self.model.makePhotosFetchedResultsController()
        controller.delegate = self
        return controller
    }()
    
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
        model.refreshPhotos()
    }
    
    // MARK: View controller life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = editButtonItem
        navigationController?.toolbar.barTintColor = UIColor(
            red: 0.0 / 255.0,
            green: 128.0 / 255.0,
            blue: 64.0 / 255.0,
            alpha: 1.0)
        configurePlaceholderView()
        configureMapView()
        configureMap()
        applyCurrentState(animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setEditing(false, animated: false)
        loadPhotos()
        updateFetchingState(animated: false)
        addNotificationObservers()
        
        view.layoutIfNeeded()
        configureCellLayout()
        configureCollectionViewInset()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeNotificationObservers()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        configureCellLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureCollectionViewInset()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Configure the image view controller when tapping on an image in the collection.
        if let viewController = segue.destination as? ImageViewController, let url = sender as? URL {
            viewController.imageURL = url
        }
    }
    
    // MARK Editing
    
    //
    //  Respond to edit mode change when edit/done button is tapped. When not editing, show the toolbar. When editing, 
    //  hide the toolbar and show a helpful hint.
    //
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        // Hide the toolbar in edit mode to show the hint message.
        if navigationController?.isToolbarHidden != editing {
            navigationController?.setToolbarHidden(editing, animated: animated)
        }
        
        // Show the hint message in edit mode.
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
    
    //
    //  Enable/disable the edit/done button according to the content. Enable the button if one or more photos are
    //  available. Disable the button, and exit edit mode, if no photos are available.
    //
    fileprivate func updateEditMode() {
        let canEdit = (photos.count > 0)
        editButtonItem.isEnabled = canEdit
        
        if !canEdit && isEditing {
            isEditing = false
        }
    }

    // MARK: Placeholder message
    
    //
    //  Show a placeholder view when images are loading, or when the api request completes and there are no images. The
    //  placeholder appears below the map and above the "load more" button.
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
    //  Observe notifications from the model when the api request starts and finishes. Used to control the appearance
    //  of the activity indicator.
    //
    private func addNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleFetchingStateChangeNotification), name: .DidStartFetchingPhotosForLocation, object: model)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFetchingStateChangeNotification), name: .DidFinishFetchingPhotosForLocation, object: model)
    }
    
    //
    //  Remove notification observers on the model.
    //
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: .DidStartFetchingPhotosForLocation, object: model)
        NotificationCenter.default.removeObserver(self, name: .DidFinishFetchingPhotosForLocation, object: model)
    }
    
    //
    //  Called when the model starts, or finishes, fetching images from the api. Update the state of the activity
    //  indicator.
    //
    @objc func handleFetchingStateChangeNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.updateFetchingState(animated: true)
        }
    }
    
    //
    //  Update the state of the activity indicator to match the state of the model. Only updates the view if the view
    //  state is different to the model state.
    //
    private func updateFetchingState(animated: Bool) {
        guard isFetching != self.model.isFetchingPhotos else {
            return
        }
        isFetching = self.model.isFetchingPhotos
        applyCurrentState(animated: animated)
    }
    
    //
    //  Show or hide the activity indicator and/or empty content placeholder message, depending on the state and 
    //  contents of the model. The activity indicator while an api request is underway. The placeholder is shown if no
    //  photos are present after the api request completes. 
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
        
        // Show / hide the activity indicator.
        if showActivity {
            photosActivityIndicator.startAnimating()
        }
        else {
            photosActivityIndicator.stopAnimating()
        }
    }

    // MARK: Map

    //
    //  Setup a view to display a map above the list of images. The view is constrained so that it resizes according to
    //  the available space above the collection view, shrinks when the collection is scrolled up, and stretches when 
    //  the collection is scrolled down passed its maximum limits.
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
    //  Calculate the amount of space above the collection view for the map view. Some space is left below the map so 
    //  that at least one line of images is visible, such as in landscape mode on iPhone.
    //
    private func configureCollectionViewInset() {
        let viewSize = view.bounds.size
        let maximumHeight = viewSize.height - 140
        let headerHeight: CGFloat = min(viewSize.width, maximumHeight)
        collectionView.contentInset.top = headerHeight
    }
    
    //
    //  Calculate the size of the cells for the current view size. Try to match an ideal cell size while minimizing the
    //  wasted space.
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
    //  Display an image of the map for the current location.
    //
    private func configureMap() {
        
        let pinView = MKPinAnnotationView(annotation: nil, reuseIdentifier: nil)
        pinImageView.image = pinView.image
        pinImageView.isHidden = true

        mapActivityIndicator.startAnimating()
        
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
            }
        }
    }
    
    //
    //  Generates a map image for the current location..
    //
    private func loadMapImage(completion: @escaping (UIImage?) -> Void) {
        
        let region = MKCoordinateRegion(
            center: coordinate,
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

    
    // MARK: Photos
    
    //
    //  Sets up loading photos from core data using a fetched results controller. After the initial load, the data is
    //  updated incrementally by callbacks to the fetched results controller delegate.
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
}

//
//  NSFetchedResultsControllerDelegate
//
extension LocationViewController: NSFetchedResultsControllerDelegate {
    
    //
    //  Fetched results controller is about to make some changes. Initializes a change list to collect changes.
    //
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        changes = []
    }
    
    //
    //  Handle an incremental change from the fetched results controller. The changes are coalesced into an list and 
    //  applied in a batch at the end of the changes.
    //
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
    
    //
    //  Fetched results controller has finished making changes. Any collected changes are applied now in a batch 
    //  operation on the collection view.
    //
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

    //
    //  Load and display the cached photo from the data stored in core data. The cell is reloaded when the data is saved 
    //  into core data. If no image data is available when the cell appears, an activity indicator is shown instead.
    //
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
    
    //
    //  Handle tap on photo. Shows a large version of the image which is tapped. If in editing mode, then the image is 
    //  deleted.
    //
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photo = photos[indexPath.item]
        if isEditing {
            if let url = photo.url {
                model.cancelDownloadingPhoto(url: url)
                model.deletePhoto(url: url, completion: nil)
            }
        }
        else {
            if let url = photo.largeURL, let imageURL = URL(string: url) {
                performSegue(withIdentifier: "image", sender: imageURL)
            }
        }
    }
}
