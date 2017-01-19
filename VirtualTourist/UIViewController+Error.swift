//
//  UIAlertController+Error.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/19.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit

typealias ErrorAlertCompletion = () -> Void

extension UIViewController {
    
    func showAlert(forError error: Error, completion: ErrorAlertCompletion? = nil) {
        let message = error.localizedDescription
        showAlert(forErrorMessage: message, completion: completion)
    }
    
    func showAlert(forErrorMessage message: String, completion: ErrorAlertCompletion? = nil) {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(
            UIAlertAction(
                title: "Dismiss",
                style: .cancel,
                handler: { _ in
                    completion?()
            })
        )
        present(controller, animated: true, completion: nil)
    }
}
