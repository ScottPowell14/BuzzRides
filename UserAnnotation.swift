//
//  UserAnnotation.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 6/9/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import UIKit
import MapKit

class UserAnnotation: NSObject, MKAnnotation {
    var coordinate : CLLocationCoordinate2D
    var title : String?
   
    init(let coord : CLLocationCoordinate2D, let tit : String) {
        self.coordinate = coord
        self.title = tit
    }
}
