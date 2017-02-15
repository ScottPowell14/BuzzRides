//
//  DriverQueueViewController.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 8/1/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import UIKit
import Firebase

class DriverQueueViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    
    // Driver Information
    var driverName : String?
    var driverPhoneNumber : String?
    var driverEmailAddress : String?
    var isDriverActive : Bool?
    
    // Firebase
    var ref : FIRDatabaseReference! // reference to the database
    fileprivate var _refHandle : FIRDatabaseHandle! // handle in order to receive updates to database
    var queue : [FIRDataSnapshot]! = [] // array of rides in queue in the database format (JSON)
    
    // UI Elements
    @IBOutlet weak var queueTableView: UITableView!
    @IBOutlet weak var activeDriverLabel: UIBarButtonItem!
    
    // Ride
    var selectedRide : Ride?
    var rides : [Ride?] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (isDriverActive!) {
            self.activeDriverLabel.title = "Active"
            self.activeDriverLabel.tintColor = UIColor.green
        } else {
            self.activeDriverLabel.title = "Not Active"
            self.activeDriverLabel.tintColor = UIColor.red
        }
        
        
        self.checkForDatabaseUpdates()
        self.queueTableView.reloadData()
        
        
        // status bar configuration
        self.setNeedsStatusBarAppearanceUpdate()
        UIApplication.shared.statusBarStyle = .lightContent // if you want to change this back, implement it to set to the default style in the viewDidDisappear method
        let statusBarFrame = UIApplication.shared.statusBarFrame
        let view = UIView(frame: statusBarFrame)
        view.backgroundColor = UIColor(red: 2/255, green: 0/255, blue: 130/255, alpha: 1.0)
        self.view.addSubview(view)
        
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    
    func checkForDatabaseUpdates() {
        ref = FIRDatabase.database().reference()
        let queueRef = ref.child("queue")
        
        _refHandle = queueRef.observe(.value, with: { (snapshot) -> Void in
            self.rides.removeAll()
            
            for rideContents in snapshot.children {
                print(rideContents)
                let ride = Ride(rideContents: rideContents as! FIRDataSnapshot)
                
                self.rides.append(ride)
            }
            self.queueTableView.reloadData()
            
            // update queue size section of database
            self.ref.child("rideInfo").child("queueSize").setValue(self.rides.count)
        })
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rides.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // this is if the driver selects a ride from the table view -- go to new view controller with more passenger information, map, and the request button
        print("Table View Cell hit at \((indexPath as NSIndexPath).row)")
        selectedRide = rides[(indexPath as NSIndexPath).row]
        
        self.performSegue(withIdentifier: "queueToRide", sender: self)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let nib = UINib(nibName: "RideCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "rideCell")
        let rideCell = tableView.dequeueReusableCell(withIdentifier: "rideCell") as! RideTableViewCell
        
        
        if let ride = rides[(indexPath as NSIndexPath).row] {
            rideCell.nameLabel.text = ride.passengerName
            rideCell.startAddressLabel.text = "From: \(ride.passengerPickUpLocationString!)"
            rideCell.endAddressLabel.text = "To: \(ride.passengerDestinationString!)"
            
            if ride.driverOnRide! {
                rideCell.driverOnRideLabel.text = "Driver on Ride: YES"
                rideCell.driverOnRideLabel.textColor = UIColor.green
            } else {
                rideCell.driverOnRideLabel.text = "Driver on Ride : NO"
                rideCell.driverOnRideLabel.textColor = UIColor.red
            }
            
            rideCell.partySizeLabel.text = "Party Size: \(ride.numberOfPassengers!)"
        }
        
        // rideCell.currentRideForCell = rides[indexPath.row] -- EDIT: I think we should only do the distance calculation if we go to the ride info view controller
        // do computation for the distance here too -- so we can pass it to the RideInfoViewController scene
        
        return rideCell
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let segID = segue.identifier
        
        if segID == "queueToRide" {
            let destinationViewController = segue.destination as! RideInfoViewController
            
            // passenger and ride information
            destinationViewController.currentRide = selectedRide
            
            destinationViewController.passengerName = selectedRide?.passengerName
            destinationViewController.passengerPhoneNumber = selectedRide?.passengerPhoneNumber
            destinationViewController.startAddressString = selectedRide?.passengerPickUpLocationString
            destinationViewController.endAddressString = selectedRide?.passengerDestinationString
            destinationViewController.partySize = selectedRide?.numberOfPassengers
            destinationViewController.rideDatabaseKey = selectedRide?.rideDatabaseKey
            
            // driver information
            destinationViewController.driverName = self.driverName
            destinationViewController.driverEmail = self.driverEmailAddress
            destinationViewController.driverPhoneNumber = self.driverPhoneNumber
            destinationViewController.isDriverActive = self.isDriverActive
            destinationViewController.driverCurrentlyOnRide = false
        }
        
        if segID == "queueToDriverProfile" {
            let destinationViewController = segue.destination as! DriverProfileViewController
            
            destinationViewController.driverName = self.driverName
            destinationViewController.driverEmail = self.driverEmailAddress
            destinationViewController.driverPhoneNumber = self.driverPhoneNumber
            destinationViewController.isDriverActive = self.isDriverActive
        }
        
        
    }

}
