//
//  DriverProfileViewController.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 8/25/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import UIKit
import CoreLocation
import Firebase

class DriverProfileViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CLLocationManagerDelegate {
    
    // UI Elements
    @IBOutlet weak var changePhotoButton: UIButton!
    @IBOutlet weak var driverPhoto: UIImageView!
    @IBOutlet weak var driverEmailLabel: UILabel!
    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var driverStatusLabel: UILabel!
    @IBOutlet weak var activeDriverSwitch: UISwitch!
    
    // Driver Information
    var driverName : String?
    var driverEmail : String?
    var driverPhoneNumber : String?
    var isDriverActive : Bool?
    var driverPhotoURL : String?
    var driverCurrentLocationAddress : String?
    var isDriverOnRide : String?
    
    // Image Picker
    let imagePicker = UIImagePickerController()
    
    // Firebase References
    var refToDatabase : FIRDatabaseReference!
    var refToDriverData : FIRDatabaseReference!
    var storageRef : FIRStorageReference?
    fileprivate var _refHandle : FIRDatabaseHandle!
    
    // Driver Location
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let storage = FIRStorage.storage()
        storageRef = storage.reference(forURL: "gs://bamboo-d0a7d.appspot.com")

        // status bar configuration
        self.setNeedsStatusBarAppearanceUpdate()
        UIApplication.shared.statusBarStyle = .lightContent // if you want to change this back, implement it to set to the default style in the viewDidDisappear method
        let statusBarFrame = UIApplication.shared.statusBarFrame
        let view = UIView(frame: statusBarFrame)
        view.backgroundColor = UIColor(red: 244/255, green: 250/255, blue: 255/255, alpha: 1.0)
        self.view.addSubview(view)
        
        self.phoneNumberTextField.delegate = self
        self.imagePicker.delegate = self
        
        // Keyboard dismissal gesture recognizer
        let keyboardDismissGesture = UITapGestureRecognizer(target: self, action: #selector(DriverProfileViewController.userTappedBackground))
        self.view.addGestureRecognizer(keyboardDismissGesture)
        
        self.driverEmailLabel.text = driverEmail!
        self.phoneNumberTextField.text = driverPhoneNumber!
        
        if (isDriverActive!) {
            driverStatusLabel.text = "Active"
            driverStatusLabel.textColor = UIColor.green
            self.activeDriverSwitch.isOn = true
            self.refToDriverData = FIRDatabase.database().reference().child("drivers").child("\(self.driverName!)")
        } else {
            driverStatusLabel.text = "Not Active"
            driverStatusLabel.textColor = UIColor.red
            self.activeDriverSwitch.isOn = false
        }
        
        // Set driver photo is it has been saved
        
        if let imageData = UserDefaults.standard.object(forKey: "driverPhoto"),
            let image = UIImage(data: imageData as! Data) {
            driverPhoto.image = image
        } else {
            print("No saved photo")
        }
        
        
        
//        let driverPhotoPersistedURL = NSUserDefaults.standardUserDefaults().objectForKey("driverPhotoURL") as! NSURL?
//        
//        if let photoURL = driverPhotoPersistedURL {
//            let photoData = NSData(contentsOfURL: photoURL)
//            
//            if let data = photoData {
//                driverPhoto.image = UIImage(data: data)
//            }
//        } else {
//            print("No saved photo")
//        }
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.default
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func userTappedBackground() {
        view.endEditing(true)
    }
    
    
    @IBAction func changePhotoButtonTouchDown(_ sender: AnyObject) {
        self.changePhotoButton.backgroundColor = UIColor.blue
    }
    
    
    @IBAction func changePhoto(_ sender: AnyObject) {
        self.changePhotoButton.backgroundColor = UIColor(red: 244/255, green: 250/255, blue: 255/255, alpha: 1.0)
        
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            // upload to firebase storage
            let photoData = UIImageJPEGRepresentation(pickedImage, 0.7)
            
            let storagePath = "\(driverName!).jpeg"
            let photoReference = storageRef?.child("DriversPhotos/\(storagePath)")
            
            let uploadTask = photoReference?.put(photoData!, metadata: nil, completion: { ( metadata, error) in
                if error != nil {
                    print(error?.localizedDescription)
                }
            })
            
            uploadTask!.observe(.success) { snapshot in
                let alert = UIAlertController(title: "Buzz!", message: "Photo upload success.", preferredStyle: UIAlertControllerStyle.alert)
                self.presentAlert(alert)
                self.driverPhoto.image = pickedImage
                self.driverPhotoURL = storagePath
                
                // persist photo locally
                UserDefaults.standard.set(photoData, forKey: "driverPhoto")
                UserDefaults.standard.synchronize()
                
//                let documentsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
//                let imageURL = documentsURL.URLByAppendingPathComponent(storagePath)
//                
//                if photoData!.writeToURL(imageURL, atomically: false)
//                {
//                    print("Error with saving")
//                } else {
//                    print("Saved")
//                    NSUserDefaults.standardUserDefaults().setObject(imageURL, forKey: "driverPhotoURL")
//                    NSUserDefaults.standardUserDefaults().synchronize()
//                }
            }
            
            uploadTask!.observe(.failure) { snapshot in
                guard let storageError = snapshot.error else { return }
                
                let alert = UIAlertController(title: "Buzz!", message: "Photo upload failure.", preferredStyle: UIAlertControllerStyle.alert)
                self.presentAlert(alert)
            }
            
        }
        
        
        
        dismiss(animated: true, completion: nil)
    }
    
    func presentAlert(_ alert : UIAlertController?) {
        if let alertError = alert {
            alertError.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            self.present(alertError, animated: true, completion: nil)
        }
    }
    
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func updatePhoneNumber(_ sender: AnyObject) {
        if self.phoneNumberTextField.text == "" {
            let alert = UIAlertController(title: "Buzz!", message: "Please enter your name and phone number.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        // send these variables back to the request page
        self.driverPhoneNumber = self.phoneNumberTextField.text
        
        // update user defaults
        UserDefaults.standard.setValue(self.driverPhoneNumber, forKey: "phoneNumber")
        UserDefaults.standard.synchronize()
        
        // update firebase database
        let user = FIRAuth.auth()?.currentUser
        let changeRequest = user?.profileChangeRequest()
        
        changeRequest?.displayName = "\(self.driverName!),\(self.driverPhoneNumber!)"
        changeRequest?.commitChanges() { (error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
        }
        
        let alert = UIAlertController(title: "Buzz!", message: "Your information has been updated.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    
    @IBAction func driverStatusSwitched(_ sender: AnyObject) {
        if activeDriverSwitch.isOn {
            driverStatusLabel.text = "Active"
            driverStatusLabel.textColor = UIColor.green
            self.isDriverActive = true
            self.isDriverOnRide = "false"
            self.getDriversCurrentAddress()
        } else {
            driverStatusLabel.text = "Not Active"
            driverStatusLabel.textColor = UIColor.red
            self.removeInactiveDriverFromDatabase(false)
            self.isDriverActive = false
        }
    }
    
    
    func addActiveDriverToDatabase(_ driverLocationAddress : String) {
        self.refToDatabase = FIRDatabase.database().reference()
        
        self.driverCurrentLocationAddress = driverLocationAddress
        
        let driverData : [String : String] = ["name" : self.driverName!, "phone" : self.driverPhoneNumber!, "currentAddress" : self.driverCurrentLocationAddress!, "driverOnRide" : isDriverOnRide!, "eta" : "none"]
        
        self.refToDatabase.child("drivers").child("\(self.driverName!)").setValue(driverData, withCompletionBlock: { (error, dataRef) in
            if error != nil {
                print(error?.localizedDescription)
                return
            }
            self.refToDriverData = dataRef
        })
        
        // update the numberOfDrivers section of the database
        let numberOfDriversRef = self.refToDatabase.child("rideInfo").child("numberOfDrivers")
        
        numberOfDriversRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
            if snapshot.key == "numberOfDrivers" {
                var numberOfDrivers = snapshot.value as! Int
                numberOfDrivers += 1
                numberOfDriversRef.setValue(numberOfDrivers)
            }
        })
        
    }
    
    
    func removeInactiveDriverFromDatabase(_ logoff: Bool) {
        self.refToDatabase = FIRDatabase.database().reference()
        
        if self.refToDriverData != nil {
            self.refToDriverData.removeValue()
            
            let numberOfDriversRef = self.refToDatabase.child("rideInfo").child("numberOfDrivers")
            
            if isDriverActive! {
                numberOfDriversRef.observeSingleEvent(of: .value, with: { (snapshot) -> Void in
                    if snapshot.key == "numberOfDrivers" {
                        var numberOfDrivers = snapshot.value as! Int
                        numberOfDrivers -= 1
                        numberOfDriversRef.setValue(numberOfDrivers)
                    }
                
                    if logoff {
                        self.completeLogout()
                    }
                })
            } else {
                if logoff {
                    self.completeLogout()
                }
            }
            
        } else {
            if logoff {
                self.completeLogout()
            }
        }
    }
    
    func getDriversCurrentAddress() {
        if let currentLocation = locationManager.location {
            let geoCoder = CLGeocoder()
            
            geoCoder.reverseGeocodeLocation(currentLocation, completionHandler: { (placemarks, error) in
                if error != nil {
                    print("Error getting user location")
                    self.addActiveDriverToDatabase("Unknown")
                    return
                }
                
                if let places = placemarks {
                    let locPlacemark = places[0]
                    self.addActiveDriverToDatabase(self.parseAddress(locPlacemark))
                    return
                }
            })
        } else {
           self.addActiveDriverToDatabase("Unknown")
        }
    }
    
    func parseAddress(_ selectedItem : CLPlacemark) -> String {
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
    
    
    
    
    @IBAction func logout(_ sender: AnyObject) {
        UserDefaults.standard.set(false, forKey: "hasLoginKey")
        self.removeInactiveDriverFromDatabase(true)
    }
    
    func completeLogout() {
        do {
            try FIRAuth.auth()!.signOut()
            self.performSegue(withIdentifier: "driverProfileToLogin", sender: self)
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let segID = segue.identifier
        
        if segID == "driverProfileToQueue" {
            let destinationViewController = segue.destination as! DriverQueueViewController
            
            destinationViewController.driverName = self.driverName
            destinationViewController.driverPhoneNumber = self.driverPhoneNumber
            destinationViewController.driverEmailAddress = self.driverEmail
            destinationViewController.isDriverActive = self.isDriverActive
        }
        
        if segID == "driverProfileToLogin" {
            // Automatically make driver not active in the database
        }
        
    }

}
