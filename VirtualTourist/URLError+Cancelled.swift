//
//  URLError+Cancelled.swift
//  VirtualTourist
//
//  Created by Luke Van In on 2017/01/24.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation

extension Error {
    
    var isURLDomainCancelledError: Bool {
        let error = self as NSError
        return (error.domain == NSURLErrorDomain) && (error.code == NSURLErrorCancelled)
    }
}
