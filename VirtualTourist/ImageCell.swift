//
//  ImageCell.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit

class ImageCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 4
        layer.masksToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        activityIndicator.stopAnimating()
    }
}
