//
//  ImageViewController.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/22.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController {
    
    enum State {
        case loading
        case loaded
    }
    
    var imageURL: URL!
    
    fileprivate var state: State = .loaded {
        didSet {
            updateState(animated: true)
        }
    }
    
    // MARK: Outlets
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        state = .loading
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: false)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (context) in
            self.calculateZoom()
        })
    }
    
    // MARK: State
    
    private func updateState(animated: Bool) {
        if animated {
            UIView.transition(
                with: view,
                duration: 0.25,
                options: [.beginFromCurrentState, .transitionCrossDissolve],
                animations: {
                    self.updateState()
            })
        }
        else {
            updateState()
        }
    }
    
    private func updateState() {
        switch state {
        case .loaded:
            imageView.isHidden = false
            activityIndicator.stopAnimating()
            
        case .loading:
            imageView.isHidden = true
            activityIndicator.startAnimating()
            loadImage()
        }
    }
    
    // MARK: Image
    
    private func loadImage() {
        let request = URLRequest(url: imageURL)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data, scale: UIScreen.main.scale) {
                    self.imageView.image = image
                }
                else {
                    print("Cannot load image: \(error)")
                }
                self.calculateZoom()
                self.state = .loaded
            }
        }
        task.resume()
    }
    
    private func calculateZoom() {
        guard let image = imageView.image else {
            return
        }
        let imageSize = image.size
        let viewSize = scrollView.bounds.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        let scale: CGFloat
        if imageAspect > viewAspect {
            scale = viewSize.width / imageSize.width
        }
        else {
            scale = viewSize.height / imageSize.height
        }
        
        let minimumScale = min(1.0, scale)
        let maximumScale = max(1.0, scale)
        
        scrollView.minimumZoomScale = minimumScale
        scrollView.maximumZoomScale = maximumScale
        scrollView.zoomScale = scale
        scrollView.layoutIfNeeded()
        
        centerScrollContent()
    }
    
    fileprivate func centerScrollContent() {
        let viewSize = scrollView.bounds.size
        let contentSize = imageView.frame.size
        var offset = scrollView.contentOffset
        
        if contentSize.width < viewSize.width {
            offset.x = -((viewSize.width - contentSize.width) * 0.5)
        }
        
        if contentSize.height < viewSize.height {
            offset.y = -((viewSize.height - contentSize.height) * 0.5)
        }
        
        scrollView.contentOffset = offset
    }
}

extension ImageViewController: UIScrollViewDelegate {
    
    //
    //
    //
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    //
    //
    //
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        centerScrollContent()
    }
    
    //
    //
    //
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerScrollContent()
    }
    
    //
    //
    //
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        centerScrollContent()
    }
}
