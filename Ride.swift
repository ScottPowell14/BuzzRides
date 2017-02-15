//
//  Ride.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 7/6/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit
import Firebase


class Ride {
    // Passenger Information
    var passengerName : String?
    var passengerPhoneNumber : String?
    var passengerEmail : String?
    var numberOfPassengers : Int?
    var passengerLocation : CLLocation?
    var passengerPickUpLocation : CLLocation?
    var passengerDestination : CLLocation?
    var passengerPickUpLocationString : String?
    var passengerDestinationString : String?
    
    // Driver's Information
    var driverOnRide : Bool?
    var driverName : String?
    var driverPhoneNumber : String?
    var driverAddressString : String?
    var driverLocation : CLLocation?
    var driverPhoto : UIImage?
    
    // Ride Information
    var eta : Int? // in minutes
    var placeInQueue : Int?
    var userRoute : MKRoute?
    var driverRoute : MKRoute?
    var estimatedWaitTime : Int?
    let messageComposer = MessageComposer()
    
    // Queue Information
    var numberOfDrivers : Int?
    var queueSize : Int?
    
    // View Controller reference
    var viewController : ViewController?
    var rideInfoViewController : RideInfoViewController?
    
    
    // Database references
    var ref : FIRDatabaseReference!
    var refToRideData : FIRDatabaseReference!
    var rideDatabaseKey : String?
    fileprivate var _refForDriverHandle : FIRDatabaseHandle!
    fileprivate var _refForRideHandle : FIRDatabaseHandle!
    var storageRef : FIRStorageReference?
    
    
    // multiple initializers -- or atleast setters for multiple properties that will be bundled together
    init(name: String?, phoneNumber : String?, email : String?, numberPassengers : String?, currentLoc : CLLocation?, pickUpLoc : CLLocation?, destinationLoc : CLLocation?, pickUpLocString : String?, destinationLocString : String?, drivName : String?, driverPhoneNum : String?, driverLoc : CLLocation?, arrivalTime : Int?, placeQueue : Int?) {
        
        passengerName = name
        passengerPhoneNumber = phoneNumber
        passengerEmail = email
        numberOfPassengers = Int(numberPassengers!)
        passengerLocation = currentLoc
        passengerPickUpLocation = pickUpLoc
        passengerDestination = destinationLoc
        passengerPickUpLocationString = pickUpLocString
        passengerDestinationString = destinationLocString
        
        driverName = drivName
        driverPhoneNumber = driverPhoneNum
        driverLocation = driverLoc
        
        eta = arrivalTime
        placeInQueue = placeQueue
    }
    
    // init with Firebase ride snapshot
    init(rideContents : FIRDataSnapshot) {
        rideDatabaseKey = rideContents.key
        
        let rideData : [String : String] = rideContents.value as! [String : String]
        
        for rideElement in rideData {
            if rideElement.0 == "driverOnRide" {
                driverName = rideElement.1
                if driverName == "None" {
                    driverOnRide = false
                } else {
                    driverOnRide = true
                }
            } else if rideElement.0 == "endAdd" {
                passengerDestinationString = rideElement.1
            } else if rideElement.0 == "name" {
                passengerName = rideElement.1
            } else if rideElement.0 == "partySize" {
                let partySize : String = rideElement.1
                numberOfPassengers = Int(partySize)
            } else if rideElement.0 == "phone" {
                passengerPhoneNumber = rideElement.1
            } else if rideElement.0 == "startAdd" {
                passengerPickUpLocationString = rideElement.1
            }
        }
    }
    
    // update location data
    func updateLocationData(_ newPassengerLoc : CLLocation, newPickUpLoc : CLLocation, newDestination : CLLocation, driverLoc : CLLocation) {
        self.passengerLocation = newPassengerLoc
        self.passengerPickUpLocation = newPickUpLoc
        self.passengerDestination = newDestination
        self.driverLocation = driverLoc
        
        // should call an update eta and potentially the place in the queue
    }
    
    // call when the driver selects the Ride object from the realtime database
    func updateDriverData(_ newName : String?, newPhoneNumber : String?, driverLoc : CLLocation?, driverPhoto : URL?) {
        driverName = newName
        driverPhoneNumber = newPhoneNumber
        driverLocation = driverLoc
    }
    
    // may be able to get the route out of this as well.
    func getRoute() {
        let directionsRequest = MKDirectionsRequest()
        
        // var route : MKRoute?
        
        if let curDriveLocation = driverLocation, let pickupLocation = passengerPickUpLocation {
            let driverPlacemark = MKPlacemark(coordinate: curDriveLocation.coordinate, addressDictionary: nil)
            let userPlacemark = MKPlacemark(coordinate: pickupLocation.coordinate, addressDictionary: nil)
            
            directionsRequest.source = MKMapItem(placemark: driverPlacemark)
            directionsRequest.destination = MKMapItem(placemark: userPlacemark)
            directionsRequest.transportType = MKDirectionsTransportType.automobile
            directionsRequest.requestsAlternateRoutes = false
                
            let directions = MKDirections(request: directionsRequest)
            
            directions.calculate(completionHandler: { response, error in
                if error != nil {
                    print("Error calculating direcitons")
                    return
                }
                self.userRoute = response!.routes[0] as MKRoute
                self.viewController!.didReceiveCallbackForUserRouteInformation()
            })
        } else {
            print("Unable to get driver and/or user's location")
            return
        }
    }
    
    func getRoute(_ startLocation : CLLocation, endLocation : CLLocation, routeType : String, viewController : String) {
        let directionsRequest = MKDirectionsRequest()
        
        // var route : MKRoute?
        let startPlacemark = MKPlacemark(coordinate: startLocation.coordinate, addressDictionary: nil)
        let endPlacemark = MKPlacemark(coordinate: endLocation.coordinate, addressDictionary: nil)
            
        directionsRequest.source = MKMapItem(placemark: startPlacemark)
        directionsRequest.destination = MKMapItem(placemark: endPlacemark)
        directionsRequest.transportType = MKDirectionsTransportType.automobile
        directionsRequest.requestsAlternateRoutes = false
            
        let directions = MKDirections(request: directionsRequest)
            
        directions.calculate(completionHandler: { response, error in
            if error != nil {
                print("Error calculating direcitons")
                return
            }
            
            if routeType == "userRoute" {
                self.userRoute = response!.routes[0] as MKRoute
                if viewController == "ViewController" {
                    self.viewController!.didReceiveCallbackForUserRouteInformation()
                } else {
                    self.rideInfoViewController?.didReceiveCallbackForUserRouteInformation()
                }
            } else {
                self.driverRoute = response!.routes[0] as MKRoute
                self.rideInfoViewController!.didReceiveCallbackForDriverRouteInformation()
            }
        })
    }
    
    
    func getEta(_ travelTimeSeconds : TimeInterval) -> Int {
        return Int(travelTimeSeconds / 60)
    }
    
    func getMiles(_ distanceInMeters : CLLocationDistance) -> Double {
        return Double(round(distanceInMeters * 0.000621371 * 100)/100)
    }
    
    func callDriver() {
        if let phoneNumber = self.driverPhoneNumber, let url = URL(string: "tel://\(phoneNumber)")  {
            UIApplication.shared.openURL(url)
        }
    }
    
    func messageDriver() {
        if let phoneNumber = self.driverPhoneNumber {
            self.messageComposer.textMessageRecipient = phoneNumber
            if (messageComposer.canSendText()) {
                let messageComposeVC = messageComposer.configuredMessageComposeViewController()
                self.viewController?.present(messageComposeVC, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Buzz!", message: "Your device is unable to send text messages right now.", preferredStyle: UIAlertControllerStyle.alert)
                self.viewController?.presentAlert(alert)
            }
        }
    }
    
    
    // EDIT: method to check validity of a ride to see if the request process should go through
    func checkIfValidRide() -> Bool {
        // if valid ride
        return true
        
        
        // if not valid ride
        // return false
    }
    
    
    func addRideToQueue() {
        ref = FIRDatabase.database().reference()
        
        let data : [String : String] = ["name" : self.passengerName!, "phone" : self.passengerPhoneNumber!, "partySize" : String(self.numberOfPassengers!), "startAdd" : self.passengerPickUpLocationString!, "endAdd" : self.passengerDestinationString!, "driverOnRide" : "None"]
        self.ref.child("queue").childByAutoId().setValue(data, withCompletionBlock: { (error, dataRef) in
            if error != nil {
                print(error?.localizedDescription)
                return
            }
            self.refToRideData = dataRef
            self.updateListenerForDriver()
            })
    }
    
    func updateListenerForDriver() {
        // Calculate estimated wait time while in queue, before driver accepts ride
        self.ref.child("rideInfo").observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            
            let queueData : [String : Int] = snapshot.value as! [String : Int]
            
            for each in queueData {
                if each.0 == "numberOfDrivers" {
                    self.numberOfDrivers = each.1
                } else if each.0 == "queueSize" {
                    self.queueSize =  each.1
                }
            }
            
            // if the number of drivers is 0, then Buzzrides service is not operating and the user will not get a ride
            if self.numberOfDrivers == 0 {
                self.viewController?.cancelRideDueToNoDrivers()
            } else {
                // Hard coded values if there is an error attaining number of drivers / queue size
                if self.numberOfDrivers == nil {
                    self.numberOfDrivers = 2
                }
            
                if self.queueSize == nil {
                    self.queueSize = 3
                }
            
                self.viewController?.showQueueInfoView()
            }
            })
        
        
        
        _refForDriverHandle = self.refToRideData.observe(.childChanged, with: { (snapshot) -> Void in
            
            if snapshot.key == "driverOnRide" {
                let driverName = snapshot.value as! String
                self.driverName = driverName
                self.driverOnRide = true
                self.updateRideWithDriverInfo()
            }
        })
        
        
    }
    
    func updateRideWithDriverInfo() {
        // update the rest of the driver info on the ride object with database information
        self.ref.child("drivers").child("\(self.driverName!)").observeSingleEvent(of: .value, with: { (snapshot) -> Void in
        
            let driverData = snapshot.value as! [String : String]
            
            for driverInfo in driverData {
                if driverInfo.0 == "currentAddress" {
                    self.driverAddressString = driverInfo.1
                } else if driverInfo.0 == "phone" {
                    self.driverPhoneNumber = driverInfo.1
                } else if driverInfo.0 == "placeInQueue" {
                    self.placeInQueue = NumberFormatter().number(from: driverInfo.1) as? Int
                } else if driverInfo.0 == "eta" {
                    self.eta = NumberFormatter().number(from: driverInfo.1) as? Int
                }
            }
        
            let storage = FIRStorage.storage()
            self.storageRef = storage.reference(forURL: "gs://bamboo-d0a7d.appspot.com")
            let storagePath = "\(self.driverName!).jpeg"
            let photoReference = self.storageRef?.child("DriversPhotos/\(storagePath)")
            
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let imageURL = documentsURL.appendingPathComponent(storagePath)
            
            // have a placeholder image in place, if there is an issue downloading driver photo
            photoReference?.data(withMaxSize: 1000000, completion: { (data, error) in
                if error != nil {
                    print("Error downloading image: \(error)")
                    self.driverPhoto = UIImage(named: "defaultDriverImage")
                } else {
                    if let photoData = data {
                        self.driverPhoto = UIImage(data: photoData)
                    } else {
                        self.driverPhoto = UIImage(named: "defaultDriverImage")
                    }
                }
                self.viewController?.showRideInfoView()
            })
        })
        
        _refForRideHandle = self.refToRideData.observe(.childRemoved, with: { (snapshot) -> Void in
            // this might mean that the driver cancelled the ride -- In which case, ride is over, show modal view
            if self.viewController!.userCurrentlyOnRide! {
                self.viewController?.cancelButtonPressed()
                self.viewController?.showRideCompletedView()
            }
        })
        
    }
    
    func removeRideToQueue() {
        if self.refToRideData != nil {
            self.refToRideData.removeValue()
        }
    }
}













