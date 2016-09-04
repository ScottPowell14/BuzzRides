//
//  ViewController.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 6/6/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import UIKit
import MapKit
import Firebase

protocol HandleMapSearch {
    func dropPinZoomIn(placemark:MKPlacemark)
}

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UITextFieldDelegate {
    
    // location manager reference
    let locationManager = CLLocationManager()
    
    // UI references
    @IBOutlet weak var mapView: MKMapView!
    var currentAnnotations : [MKAnnotation] = []
    var currentDestinationAnnotations : [MKAnnotation] = []
    @IBOutlet weak var startLocationTextField: UITextField!
    @IBOutlet weak var numberOfPassengersLabel: UILabel!
    var resultSearchController : UISearchController? = nil
    @IBOutlet weak var searchBarContainerView: UIView!
    @IBOutlet weak var userLocationButton: UIButton!
    var selectedPin : MKPlacemark? = nil // used to cache incoming placemarks
    var searchBarReference : UISearchBar? = nil
    var routeOverlay : MKOverlay?
    @IBOutlet weak var requestButton: UIButton!
    @IBOutlet weak var showProfileButton: UIButton!
    
    // Ride Information View UI
    @IBOutlet weak var rideInfoView: UIView!
    @IBOutlet weak var driverNameLabel: UILabel!
    @IBOutlet weak var etaLabel: UILabel!
    @IBOutlet weak var driverImage: UIImageView!
    @IBOutlet weak var queueInfoView: UIView!
    @IBOutlet weak var estimatedWaitTimeLabel: UILabel!
    
    // user information
    var name : String?
    var phoneNumber : String?
    var emailAddress : String?
    var currentPickupLocationPlacemark : CLPlacemark?
    var currentDestinationLocation : CLLocation?
    var userCurrentlyOnRide : Bool?
    
    
    // ride information
    var currentRide : Ride?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setNeedsStatusBarAppearanceUpdate()
        UIApplication.sharedApplication().statusBarStyle = .LightContent
        
        locationManager.delegate = self
        startLocationTextField.delegate = self
        mapView.delegate = self
        // locationManager.desiredAccuracy = kCLLocationAccuracyBest    // if we ever need higher accuracy
        locationManager.requestWhenInUseAuthorization()
        
        // EDIT: Confirm location is accessible and granted
        
        // Keyboard dismissal gesture recognizer
        let keyboardDismissGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.userTappedMapBackground))
        self.mapView.addGestureRecognizer(keyboardDismissGesture)
        
        // UISearchController
        let locationSearchTable = storyboard!.instantiateViewControllerWithIdentifier("LocationSearchTable") as! LocationSearchTable
        resultSearchController = UISearchController(searchResultsController: locationSearchTable)
        resultSearchController?.searchResultsUpdater = locationSearchTable
        locationSearchTable.mapView = mapView
        
        let searchBar = resultSearchController!.searchBar
        searchBar.sizeToFit()
        searchBar.placeholder = "Final Destination"
        searchBar.barTintColor = UIColor(red: 107, green: 185, blue: 240, alpha: 1)
        
        // EDIT -- Try to change frame so that it is comfortably in the view
        searchBar.frame = CGRect(x: 0, y: 0, width: 360, height: 30)
        
        searchBarReference = searchBar
        
        // Color Set up
        startLocationTextField.textColor = UIColor(red: 42.0/255, green: 141.0/255, blue: 243.0/255, alpha: 1)
        userLocationButton.backgroundColor = UIColor(red: 0.0/255, green: 122.0/255, blue: 255.0/255, alpha: 1)
        
        //searchBar.becomeFirstResponder() // EDIT: this means when the view loads it goes right to the end destination search bar -- of course users can escape out of it, but then the UI will be reset properly
        
        //SearchBar Text
        let textFieldInsideUISearchBar = searchBar.valueForKey("searchField") as? UITextField
        textFieldInsideUISearchBar?.textColor = UIColor(red: 42.0/255, green: 141.0/255, blue: 243.0/255, alpha: 1)
        textFieldInsideUISearchBar?.font = UIFont(name: "Gill Sans", size: 17)
        
        //SearchBar Placeholder
        let textFieldInsideUISearchBarLabel = textFieldInsideUISearchBar!.valueForKey("placeholderLabel") as? UILabel
        textFieldInsideUISearchBarLabel?.textColor = UIColor(red: 42.0/255, green: 141.0/255, blue: 243.0/255, alpha: 1)
        textFieldInsideUISearchBarLabel?.font = UIFont(name: "Gill Sans", size: 17)
        
        searchBarContainerView.clipsToBounds = true
        searchBarContainerView.addSubview((resultSearchController?.searchBar)!)
        
        resultSearchController?.hidesNavigationBarDuringPresentation = false
        resultSearchController?.dimsBackgroundDuringPresentation = true
        definesPresentationContext = true
        
        locationSearchTable.handleMapSearchDelegate = self
        
        self.userCurrentlyOnRide = false
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    @IBAction func request(sender: AnyObject) {
        if (requestButton.titleLabel?.text == "Cancel") {
            self.cancelButtonPressed()
            return
        }
        
        if self.currentDestinationLocation == nil || searchBarReference?.text == "" {
            let alert = UIAlertController(title: "Buzz!", message: "Please confirm your destination.", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        self.showProfileButton.hidden = true
        requestButton.setTitle("Cancel", forState: .Normal)
        requestButton.backgroundColor = UIColor.redColor()
        self.startLocationTextField.userInteractionEnabled = false
        self.searchBarReference?.userInteractionEnabled = false
        
        
        // have other method to check these conditions -- EDIT: put checks in the checkifValidRide in Ride class
        // We should have checks for: the pickup and drop off location is valid, there are drivers on the road, it is within the proper time of night interval, there is no special flag enabled for no service, potentially more checks 
        
        self.currentPickupLocationPlacemark?.location
        
        
        currentRide = Ride(name: self.name, phoneNumber: self.phoneNumber, email: self.emailAddress, numberPassengers: self.numberOfPassengersLabel.text, currentLoc: self.locationManager.location, pickUpLoc: self.currentPickupLocationPlacemark?.location, destinationLoc: self.currentDestinationLocation, pickUpLocString: self.startLocationTextField.text, destinationLocString: self.searchBarReference?.text, drivName: nil, driverPhoneNum: nil, driverLoc: nil, arrivalTime: nil, placeQueue: nil)
        
        
        currentRide?.viewController = self
        
        currentRide!.getRoute(currentRide!.passengerPickUpLocation!, endLocation: currentRide!.passengerDestination!, routeType: "userRoute", viewController: "ViewController")
    }
    
    func didReceiveCallbackForUserRouteInformation() {
        if let routePickupToDestination = currentRide!.userRoute {
            
            // distance check (under about 5.5 miles)
            if routePickupToDestination.distance > 8800.0 {
                let alert = UIAlertController(title: "Buzz!", message: "Sorry! We can't take you that far!", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
                cancelButtonPressed()
                return
            }
            
            // add ride here
            currentRide!.addRideToQueue()
            
            self.mapView.addOverlay(routePickupToDestination.polyline)
            routeOverlay = routePickupToDestination.polyline
            let mapRegion = regionForTwoPoints(currentRide!.passengerPickUpLocation!, locationTwo: currentRide!.passengerDestination!)
            mapView.setRegion(mapRegion, animated: true)
        } else {
            print("Error getting route")
        }
    }
    
    func didReceiveCallbackForDriverRouteInformation() {
        if let routeDriverToUser = currentRide!.userRoute {
            currentRide!.eta = currentRide!.getEta(routeDriverToUser.expectedTravelTime)
            print(currentRide!.eta)
            // change UI to include ETA for driver to user
            
        } else {
            print("Error getting route")
        }
    }
    
    func showQueueInfoView() {
        self.queueInfoView.hidden = false
        
        // EDIT -- make this a var and update it every minute
        let estimatedWaitTime = ((currentRide!.queueSize! * 4) / currentRide!.numberOfDrivers!) + 1
        
        self.estimatedWaitTimeLabel.text = "Estimated wait time: \(estimatedWaitTime) minutes"
    }
    
    
    func showRideInfoView() {
        self.queueInfoView.hidden = true
        self.rideInfoView.hidden = false
        self.userCurrentlyOnRide = true
        
        if let eta = currentRide?.eta {
            self.etaLabel.text = "\(eta)"
        }
        
        if let driveName = currentRide?.driverName {
            self.driverNameLabel.text = "\(driveName)"
        } else {
            self.driverNameLabel.text = "Driver on the way!"
        }
        
        if let image = self.currentRide?.driverPhoto {
            self.driverImage.image = image
        }
    }
    
    @IBAction func callDriver(sender: AnyObject) {
        if let curRide = currentRide {
            curRide.callDriver()
        }
    }
    
    @IBAction func messageDriver(sender: AnyObject) {
        if let curRide = currentRide {
            curRide.messageDriver()
        }
    }
    
    func cancelRideDueToNoDrivers() {
        let alert = UIAlertController(title: "Buzz!", message: "Sorry! There are currently no active drivers, which may be because Buzz Rides is not operating right now.", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
        
        self.cancelButtonPressed()
    }
    
    
    func cancelButtonPressed() {
        // first need to remove the ride data from the queue
        currentRide!.removeRideToQueue()
        
        requestButton.setTitle("Request", forState: .Normal)
        requestButton.backgroundColor = UIColor(red: 2.0/255, green: 0.0/255, blue: 130.0/255, alpha: 1)
        self.rideInfoView.hidden = true
        self.queueInfoView.hidden = true
        self.showProfileButton.hidden = false
        self.startLocationTextField.userInteractionEnabled = true
        self.searchBarReference?.userInteractionEnabled = true
        self.userCurrentlyOnRide = false
        
        if let overlay = routeOverlay {
            mapView.removeOverlay(overlay)
        }
        self.centerOnLocation()
    }
    
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @IBAction func userTappedBackground(sender: AnyObject) {
        view.endEditing(true)
    }
    
    func userTappedMapBackground() {
        view.endEditing(true)
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
            centerOnUser(self)
            placeUserAnnotation()
        } else {
            print("We don't have authorization, handle accordingly")
            // locationManager.requestWhenInUseAuthorization()
        }
    }
    
    @IBAction func centerOnUser(sender: AnyObject) {
        centerOnLocation()
        
        
        // IMPROVEMENT: Cache the user's current location locally and only do this work below if there is a significant change.
        if let currentLocation = locationManager.location {
            let geoCoder = CLGeocoder()
            var addressString : String?
            
            geoCoder.reverseGeocodeLocation(currentLocation, completionHandler: { (let placemarks : [CLPlacemark]?, let error : NSError?) -> Void in
                if error != nil {
                    print("Error getting user location")
                    return
                }
                
                // placemarks might contain multiple results, but just using the first one for simplicity
                if let places = placemarks {
                    let userLocPlacemark = places[0]
                    self.currentPickupLocationPlacemark = userLocPlacemark
                    
                    // instantiate MKPlacemark with CLPlacemark data
                    let mkPlacemark = MKPlacemark(placemark: userLocPlacemark)
                    
                    addressString = self.parseAddress(mkPlacemark)
                }
                
                if let address = addressString {
                    print(address)
                    self.startLocationTextField.text = address
                }
                
                })
        } else {
            // might not have location yet...
        }
    }
    
    func centerOnLocation() {
        let mapSpan = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        if let coord = locationManager.location?.coordinate {
            let mapRegion = MKCoordinateRegion(center: coord, span: mapSpan)
            mapView.setRegion(mapRegion, animated: true)
            placeUserAnnotation()
        } else {
            print("Current location unknown")
            // locationManager.requestWhenInUseAuthorization
        }
    }
    
    func placeUserAnnotation() {
        
        mapView.removeAnnotations(currentAnnotations)
        // if the centerOnLocation func calls this, then remove all the current annotation here before placing a new one
        if let coord = locationManager.location?.coordinate {
            let userAnnotation = UserAnnotation(coord: coord, tit: "Pickup Location")
            userAnnotation.accessibilityLabel = "Start"
            
            mapView.viewForAnnotation(userAnnotation)
            mapView.addAnnotation(userAnnotation)
            currentAnnotations.append(userAnnotation)
        } else {
            // User may still not be providing location or another thing is broken 
            // locationManager.requestWhenInUseAuthorization
        }
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.isKindOfClass(MKUserLocation) {
            return nil
        }
        
        var userAnnotationViewBase = mapView.dequeueReusableAnnotationViewWithIdentifier("pin")
        
        if userAnnotationViewBase == nil {
            let userAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin") // new annotation view
            if annotation.isMemberOfClass(UserAnnotation) {
                userAnnotationView.draggable = true
                userAnnotationView.canShowCallout = false
                userAnnotationView.pinTintColor = UIColor.greenColor()
            } else {
                userAnnotationView.draggable = false
                userAnnotationView.canShowCallout = true
            }
            userAnnotationViewBase = userAnnotationView
        } else {
            userAnnotationViewBase?.annotation = annotation
        }
        
        return userAnnotationViewBase
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if newState == .Ending {
            if let newCoord = view.annotation?.coordinate {
                let droppedCoord : CLLocationCoordinate2D = newCoord
                updateStartLocationWithPinLocation(droppedCoord)
            }
        }
    }
    
    func updateStartLocationWithPinLocation(let newCoord : CLLocationCoordinate2D) {
        
        let locationOfCoord = CLLocation(coordinate: newCoord, altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: 0, speed: 0, timestamp: NSDate())
        
        let geoCoder = CLGeocoder()
        var addressString : String?
            
        geoCoder.reverseGeocodeLocation(locationOfCoord, completionHandler: { (let placemarks : [CLPlacemark]?, let error : NSError?) -> Void in
            if error != nil {
                print("Error getting placemark location") // user may have placed the placemark in an illegitimate location... must do checks to make sure it is a valid location and within a reasonable distance to the user as well.
                return
            }
                
            // placemarks might contain multiple results, but just using the first one for simplicity
            if let places = placemarks {
                let userPickupLocPlacemark = places[0]
                self.currentPickupLocationPlacemark = userPickupLocPlacemark
                    
                // instantiate MKPlacemark with CLPlacemark data
                let mkPlacemark = MKPlacemark(placemark: userPickupLocPlacemark)
                    
                addressString = self.parseAddress(mkPlacemark)
            }
                
            if let address = addressString {
                self.startLocationTextField.text = address
            }
                
        })
    }
    
    
    @IBAction func incrementNumberOfPassengers(sender: AnyObject) {
        var numberOfPassengers : Int = 1
        if let currentLabelText = numberOfPassengersLabel.text {
            numberOfPassengers = Int(currentLabelText)!
        }
        
        numberOfPassengers += 1
        if numberOfPassengers > 6 {
            let alert = UIAlertController(title: "Buzz!", message: "We can only fit 6 passengers. Someone's walking!", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            
            numberOfPassengers -= 1
        }
        numberOfPassengersLabel.text = String(numberOfPassengers)
    }
    
    
    @IBAction func decrementNumberOfPassengers(sender: AnyObject) {
        var numberOfPassengers : Int = 1
        if let currentLabelText = numberOfPassengersLabel.text {
            numberOfPassengers = Int(currentLabelText)!
        }
        
        numberOfPassengers -= 1
        if numberOfPassengers < 1 {
            numberOfPassengers += 1
        }
        numberOfPassengersLabel.text = String(numberOfPassengers)
    }
    
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        
        let myLineRenderer = MKPolylineRenderer(polyline: self.currentRide!.userRoute!.polyline)
        myLineRenderer.strokeColor = UIColor(red: 0.0/255, green: 122.0/255, blue: 255.0/255, alpha: 1)
        myLineRenderer.lineWidth = 8
        return myLineRenderer
    }
    
    // MARK: - Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "requestToProfile" {
            let destinationViewController = segue.destinationViewController as! ProfileViewController
            destinationViewController.name = self.name
            destinationViewController.phoneNumber = self.phoneNumber
            destinationViewController.emailAddress = self.emailAddress
        }
    }
    
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension ViewController : HandleMapSearch {
    func dropPinZoomIn(placemark: MKPlacemark) {
        // cache the pin
        selectedPin = placemark
        // clear exiting pins
        mapView.removeAnnotations(currentDestinationAnnotations)
        
        let annotation = MKPointAnnotation() // we want this one not able to be moved
        annotation.coordinate = placemark.coordinate
        annotation.title = placemark.name
        
        if let city = placemark.locality,
            let state = placemark.administrativeArea {
                annotation.subtitle = "\(city) \(state)"
        }
        
        // Change the search bar text to the completed inferred address
        searchBarReference?.text = parseAddress(placemark)
        
        mapView.addAnnotation(annotation)
        currentDestinationAnnotations.append(annotation)
        
        // EDIT: this may be an unsafe move -- check to see if this is assigned effectively
        currentDestinationLocation = placemark.location
        
        
        let span = MKCoordinateSpanMake(0.05, 0.05)
        let region = MKCoordinateRegionMake(placemark.coordinate, span) // this region should include both the user's location placemark and the destination placemark -- maybe even the route between them.
        mapView.setRegion(region, animated: true)
    }
    
    func parseAddress(selectedItem : MKPlacemark) -> String {
        // put a space between "4" and "Melrose Place"
        let firstSpace = (selectedItem.subThoroughfare != nil && selectedItem.thoroughfare != nil) ? " " : ""
        // put a comma between street and city/state
        let comma = (selectedItem.subThoroughfare != nil || selectedItem.thoroughfare != nil) && (selectedItem.subAdministrativeArea != nil || selectedItem.administrativeArea != nil) ? ", " : ""
        // put a space between "Washington" and "DC"
        let secondSpace = (selectedItem.subAdministrativeArea != nil && selectedItem.administrativeArea != nil) ? " " : ""
        let addressLine = String(
            format:"%@%@%@%@%@%@%@",
            // street number
            selectedItem.subThoroughfare ?? "",
            firstSpace,
            // street name
            selectedItem.thoroughfare ?? "",
            comma,
            // city
            selectedItem.locality ?? "",
            secondSpace,
            // state
            selectedItem.administrativeArea ?? ""
        )
        return addressLine
    }
}

