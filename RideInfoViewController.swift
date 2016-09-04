//
//  RideInfoViewController.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 8/4/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import UIKit
import MapKit
import Firebase

class RideInfoViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    // UI Elements
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var startAddressTextField: UITextField!
    @IBOutlet weak var endAddressTextField: UITextField!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var partySizeLabel: UILabel!
    
    // UI Buttons
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var openInMapsButton: UIButton!
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var messageButton: UIButton!
    
    
    // Ride Information
    var currentRide : Ride?
    var routeOverlay : String?
    
    var passengerName : String?
    var passengerPhoneNumber : String?
    var startAddressString : String?
    var endAddressString : String?
    var distance : Int?
    var partySize : Int?
    var rideStartLocationCoord : CLLocationCoordinate2D?
    var rideEndLocationCoord : CLLocationCoordinate2D?
    var rideDatabaseKey : String?
    let messageComposer = MessageComposer()
    
    // Driver Information
    let locationManager = CLLocationManager()
    var driverName : String?
    var driverEmail : String?
    var driverPhoneNumber : String?
    var isDriverActive : Bool?
    var driverCurrentlyOnRide : Bool?
    
    // Firebase References
    var refToDatabase : FIRDatabaseReference!
    var refToExactRide : FIRDatabaseReference!
    var refToDriver : FIRDatabaseReference!
    private var _refHandle : FIRDatabaseHandle!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // status bar
        self.setNeedsStatusBarAppearanceUpdate()
        UIApplication.sharedApplication().statusBarStyle = .LightContent
        let statusBarFrame = UIApplication.sharedApplication().statusBarFrame
        let view = UIView(frame: statusBarFrame)
        view.backgroundColor = UIColor(red: 2/255, green: 0/255, blue: 130/255, alpha: 1.0)
        self.view.addSubview(view)
        
        // Hide Open in Maps and contact buttons
        openInMapsButton.hidden = true
        callButton.hidden = true
        messageButton.hidden = true
        
        
        locationManager.delegate = self
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        locationManager.requestWhenInUseAuthorization()
        
        self.currentRide?.rideInfoViewController = self
        
        self.setLabels()
        self.displayStartPlacemark()
        self.displayDestinationPlacemark()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    
    @IBAction func acceptRide(sender: AnyObject) {
        // Check if it's the "End Ride" button
        if (acceptButton.titleLabel?.text == "End Ride") {
            self.endRideButtonPressed()
            return
        }
        
        if !self.isDriverActive! {
            let alert = UIAlertController(title: "Buzz!", message: "Please turn on active driver status before accepting any rides.", preferredStyle: UIAlertControllerStyle.Alert)
            self.presentAlert(alert)
            return
        }
        
        // first, check if there is already a driver on the ride
        self.refToDatabase = FIRDatabase.database().reference()
        
        self.refToExactRide = self.refToDatabase.child("queue").child(self.rideDatabaseKey!)
        self.refToDriver = self.refToDatabase.child("drivers").child("\(self.driverName!)")
        
        self.refToExactRide.child("driverOnRide").observeSingleEventOfType(.Value, withBlock: { (snapshot) -> Void in
            if snapshot.key == "driverOnRide" {
                let driverOnRide = snapshot.value as! String
                
                if driverOnRide != "None" {
                    let alert = UIAlertController(title: "Buzz!", message: "There is already a driver on this ride! Please choose another", preferredStyle: UIAlertControllerStyle.Alert)
                    self.presentAlert(alert)
                } else {
                    self.refToExactRide.child("driverOnRide").setValue(self.driverName)
                    self.refToDriver.child("driverOnRide").setValue("true")
                    self.driverCurrentlyOnRide = true
                    self.rideHasBeenAccepted()
                }
            }
        })
    }
    
    func rideHasBeenAccepted() {
        openInMapsButton.hidden = false
        callButton.hidden = false
        messageButton.hidden = false
        acceptButton.setTitle("End Ride", forState: .Normal)
        acceptButton.backgroundColor = UIColor.redColor()
        
        // do routing for both the driver to the user, and the pickup to end location
        // rudimentary routing (just show an overlay between the start and end locations) and update the distance; then push the ETA
        
        // driver to user
        if let curLocation = locationManager.location, let pickupCoord = self.rideStartLocationCoord {
            currentRide?.passengerPickUpLocation = CLLocation(latitude: pickupCoord.latitude, longitude: pickupCoord.longitude)
            currentRide?.getRoute(curLocation, endLocation: (currentRide?.passengerPickUpLocation)!, routeType: "driverRoute", viewController: "RideInfoViewController")
        }
        
        // user pickup to user destination
        if let pickupCoord = self.rideStartLocationCoord, let destinationCoord = self.rideEndLocationCoord {
            currentRide?.passengerPickUpLocation = CLLocation(latitude: pickupCoord.latitude, longitude: pickupCoord.longitude)
            currentRide?.passengerDestination = CLLocation(latitude: destinationCoord.latitude, longitude: destinationCoord.longitude)
            currentRide?.getRoute((currentRide?.passengerPickUpLocation)!, endLocation: (currentRide?.passengerDestination)!, routeType: "userRoute", viewController: "RideInfoViewController")
        }
        
        _refHandle = self.refToExactRide.observeEventType(.ChildRemoved, withBlock: { (snapshot) -> Void in
            // this might mean that the rider cancelled the ride
            if self.driverCurrentlyOnRide! {
                let alert = UIAlertController(title: "Buzz!", message: "User has cancelled the ride. If this was unexpected, please report the situation.", preferredStyle: UIAlertControllerStyle.Alert)
                self.presentAlert(alert)
                self.endRideButtonPressed()
            }
        })
        
        
    }
    
    func didReceiveCallbackForDriverRouteInformation() {
        if let routeDriverToPickup = currentRide?.driverRoute {
            currentRide?.eta = currentRide?.getEta(routeDriverToPickup.expectedTravelTime)
            
            // check that the eta is actually updating correctly... I think because we're international we're having issues
            self.refToDatabase.child("drivers").child("\(self.driverName!)").child("eta").setValue("\(currentRide?.eta)")
            
            self.routeOverlay = "DriverRoute"
            self.mapView.addOverlay(routeDriverToPickup.polyline)
            self.distanceLabel.text = "Distance: \(currentRide?.getMiles(routeDriverToPickup.distance)) miles"
            
            if let curLocation = locationManager.location, let pickupLoc = currentRide?.passengerPickUpLocation {
                let mapRegion = self.regionForTwoPoints(curLocation, locationTwo: pickupLoc)
                self.mapView.setRegion(mapRegion, animated: true)
            }
        }
    }
    
    func didReceiveCallbackForUserRouteInformation() {
        if let routePickupToDest = currentRide?.userRoute {
            self.routeOverlay = "UserRoute"
            self.mapView.addOverlay(routePickupToDest.polyline)
        }
    }
    
    
    func endRideButtonPressed() {
        acceptButton.setTitle("Accept", forState: .Normal)
        acceptButton.backgroundColor = UIColor(red: 0.0/255, green: 122.0/255, blue: 255.0/255, alpha: 1)
        openInMapsButton.hidden = true
        callButton.hidden = true
        messageButton.hidden = true
        self.driverCurrentlyOnRide = false
        
        if self.refToExactRide != nil {
            self.refToExactRide.removeValue()
        }
        
        if self.refToDriver != nil {
            self.refToDriver.child("driverOnRide").setValue("false")
        }
        
        self.performSegueWithIdentifier("rideToQueue", sender: self)
    }
    
    
    @IBAction func openInMaps(sender: AnyObject) {
        
        
        let regionDistance:CLLocationDistance = 2000
        if let coordinates = currentRide?.passengerPickUpLocation?.coordinate {
            let regionSpan = MKCoordinateRegionMakeWithDistance(coordinates, regionDistance, regionDistance)
            let options = [
                MKLaunchOptionsMapCenterKey: NSValue(MKCoordinate: regionSpan.center),
                MKLaunchOptionsMapSpanKey: NSValue(MKCoordinateSpan: regionSpan.span)
            ]
            let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = "Passenger Pickup Location"
            mapItem.openInMapsWithLaunchOptions(options)
        }
    }
    
    
    @IBAction func callRider(sender: AnyObject) {
        if let phoneNumber = self.passengerPhoneNumber, let url = NSURL(string: "tel://\(phoneNumber)")  {
            UIApplication.sharedApplication().openURL(url)
        }
    }
    
    
    @IBAction func messageRider(sender: AnyObject) {
        if let phoneNumber = self.passengerPhoneNumber {
            self.messageComposer.textMessageRecipient = phoneNumber
            if (messageComposer.canSendText()) {
                let messageComposeVC = messageComposer.configuredMessageComposeViewController()
                self.presentViewController(messageComposeVC, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Buzz!", message: "Your device is unable to send text messages right now.", preferredStyle: UIAlertControllerStyle.Alert)
                self.presentAlert(alert)
            }
        }
    }
    
    func setLabels() {
        self.startAddressTextField.userInteractionEnabled = false
        self.endAddressTextField.userInteractionEnabled = false
        
        self.nameLabel.text = passengerName
        self.startAddressTextField.text = startAddressString
        self.endAddressTextField.text = endAddressString
        self.distanceLabel.text = "Distance: "
        self.partySizeLabel.text = "Party Size: \(String(partySize!))"
    }
    
    func displayStartPlacemark() {
        
        // consider just adding the user's start and end coordinates to the database and just using that information... Might be more precise than geocoding the address string
        let geoCoder = CLGeocoder()
        
        geoCoder.geocodeAddressString(startAddressString!, completionHandler: { (let placemarks : [CLPlacemark]?, let error : NSError?) -> Void in
            
            if error != nil {
                print("Error with geocoding")
                return
            }
            
            if let startPlacemark = placemarks?[0] {
                let startAnnotation = UserAnnotation(coord: (startPlacemark.location?.coordinate)!, tit: "Pickup Location")
                let startLoc = startAnnotation as MKAnnotation
                self.rideStartLocationCoord = startLoc.coordinate
                self.mapView.addAnnotation(startAnnotation)
                
                
            }
        })
    }
    
    func displayDestinationPlacemark() {
        
        let geoCoder = CLGeocoder()
        
        geoCoder.geocodeAddressString(endAddressString!, completionHandler: { (let placemarks : [CLPlacemark]?, let error : NSError?) -> Void in
            
            if error != nil {
                print("Error with geocoding")
                return
            }
            
            if let endPlacemark = placemarks?[0] {
                let endAnnotation = UserAnnotation(coord: (endPlacemark.location?.coordinate)!, tit: "Drop off Location")
                let endLoc = endAnnotation as MKAnnotation
                self.rideEndLocationCoord = endLoc.coordinate
                self.mapView.addAnnotation(endAnnotation)
            }
        })
    }
    
    
    
    @IBAction func centerOnDriverLocation(sender: AnyObject) {
        let mapSpan = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        if let coord = locationManager.location?.coordinate {
            let mapRegion = MKCoordinateRegion(center: coord, span: mapSpan)
            mapView.setRegion(mapRegion, animated: true)
        } else {
            print("Current location unknown")
            // locationManager.requestWhenInUseAuthorization
        }
    }
    
    func regionForTwoPoints(let locationOne : CLLocation, let locationTwo : CLLocation) -> MKCoordinateRegion {
        var center = CLLocationCoordinate2D()
        
        let lon1 = locationOne.coordinate.longitude * M_PI / 180
        let lon2 = locationTwo.coordinate.longitude * M_PI / 180
        
        let lat1 = locationOne.coordinate.latitude * M_PI / 180
        let lat2 = locationTwo.coordinate.latitude * M_PI / 180
        
        let dLon = lon2 - lon1
        
        let x = cos(lat2) * cos(dLon);
        let y = cos(lat2) * sin(dLon);
        
        let lat3 = atan2( sin(lat1) + sin(lat2), sqrt((cos(lat1) + x) * (cos(lat1) + x) + y * y) );
        let lon3 = lon1 + atan2(y, cos(lat1) + x);
        
        center.latitude  = lat3 * 180 / M_PI;
        center.longitude = lon3 * 180 / M_PI;
        
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04))
    }
    
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedWhenInUse {
            print("We have authorization")
            mapView.showsUserLocation = true
            mapView.userLocation.title = nil
            centerOnDriverLocation(self)
        } else {
            print("We don't have authorization, handle accordingly")
            // locationManager.requestWhenInUseAuthorization()
        }
    }
    
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.isKindOfClass(MKUserLocation) {
            return nil
        }
        
        var annotationViewBase = mapView.dequeueReusableAnnotationViewWithIdentifier("pin")
        
        if annotationViewBase == nil {
            let userAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            
            if annotation.isMemberOfClass(UserAnnotation) {
                userAnnotationView.canShowCallout = true
                
                if annotation.title! == "Pickup Location" {
                    userAnnotationView.pinTintColor = UIColor.greenColor()
                } else if annotation.title! == "Drop off Location" {
                    userAnnotationView.pinTintColor = UIColor.redColor()
                }
            }
            annotationViewBase = userAnnotationView
        } else {
            annotationViewBase?.annotation = annotation
        }
        return annotationViewBase
    }
    
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        if self.routeOverlay == "DriverRoute" {
            let myLineRenderer = MKPolylineRenderer(polyline: self.currentRide!.driverRoute!.polyline)
            myLineRenderer.strokeColor = UIColor(red: 2.0/255, green: 0.0/255, blue: 130.0/255, alpha: 1)
            myLineRenderer.lineWidth = 4
            return myLineRenderer
        }
        
        let myLineRenderer = MKPolylineRenderer(polyline: self.currentRide!.userRoute!.polyline)
        myLineRenderer.strokeColor = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)
        myLineRenderer.lineWidth = 4
        return myLineRenderer
    }
    
    func presentAlert(alert : UIAlertController?) {
        if let alertError = alert {
            alertError.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alertError, animated: true, completion: nil)
        }
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Navigation
    
    @IBAction func segueBackToQueue(sender: AnyObject) {
        if driverCurrentlyOnRide! {
            let alert = UIAlertController(title: "Buzz!", message: "Complete this ride before beginning a new one.", preferredStyle: UIAlertControllerStyle.Alert)
            self.presentAlert(alert)
        } else {
            self.performSegueWithIdentifier("rideToQueue", sender: self)
        }
    }
    
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let segID = segue.identifier
        
        if segID == "rideToQueue" {
            let destinationViewController = segue.destinationViewController as! DriverQueueViewController
            
            destinationViewController.driverName = self.driverName
            destinationViewController.driverEmailAddress = self.driverEmail
            destinationViewController.driverPhoneNumber = self.driverPhoneNumber
            destinationViewController.isDriverActive = self.isDriverActive
        }

        
        
    }

}
