//
//  RideTableViewCell.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 8/4/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import UIKit

class RideTableViewCell: UITableViewCell {
    
    var currentRideForCell : Ride?
    
    let placeHolderDistance = 5
    
    // UI Elements
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var startAddressLabel: UILabel!
    @IBOutlet weak var endAddressLabel: UILabel!
    @IBOutlet weak var driverOnRideLabel: UILabel!
    @IBOutlet weak var partySizeLabel: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
