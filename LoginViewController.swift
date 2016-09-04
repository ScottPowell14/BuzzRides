//
//  LoginViewController.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 6/19/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import UIKit
import Firebase

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    let MyKeychainWrapper = KeychainWrapper()
    
    // var successfulLogin : Bool?
    
    // Database references
    var ref : FIRDatabaseReference!
    private var _refHandle : FIRDatabaseHandle!
    var contractedDrivers : [FIRDataSnapshot]! = [] // list of the contracted drivers
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setNeedsStatusBarAppearanceUpdate()
        UIApplication.sharedApplication().statusBarStyle = .LightContent
        
        // check if user's login info is saved for auto login
        if NSUserDefaults.standardUserDefaults().boolForKey("hasLoginKey") {
            // authenticate user method -- nah just do it separately
            let emailUserName = NSUserDefaults.standardUserDefaults().objectForKey("email") as! String
            let password = MyKeychainWrapper.myObjectForKey("v_Data") as! String
            
            self.emailTextField.text = emailUserName
            self.passwordTextField.text = password
            
            FIRAuth.auth()?.signInWithEmail(emailUserName, password: password) { (user, error) in
                if error != nil {
                    // handle errors accordingly -- might have to have a switch statement to test all of them
                    if let errorMessage = error?.localizedDescription {
                        print("An error occured: \(errorMessage)")
                    }
                } else {
                    // Here is where we should check if the user is a driver or not, and direct their login accordingly
                    self.checkDriverStatus(emailUserName)
                }
            }
        }
        
        emailTextField.delegate = self
        passwordTextField.delegate = self

        // Keyboard dismissal gesture recognizer
        let keyboardDismissGesture = UITapGestureRecognizer(target: self, action: #selector(LoginViewController.userTappedBackground))
        self.view.addGestureRecognizer(keyboardDismissGesture)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func userTappedBackground() {
        view.endEditing(true)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    // MARK: Check if driver for login
    
    func checkDriverStatus(userName : String) {
        // get the substring before "@"
        let splitIndex = userName.characters.indexOf("@")
        let user = userName.substringToIndex(splitIndex!)
        
        
        ref = FIRDatabase.database().reference()
        let driverListRef = ref.child("contractedDrivers")
        
        _refHandle = driverListRef.observeEventType(.Value, withBlock: { (snapshot) -> Void in
            
            for driverData in snapshot.children {
                let driverDataSnapshot = driverData as! FIRDataSnapshot
                
                if user == driverDataSnapshot.key {
                    print("This is a driver")
                    self.segueBasedOnDriverStatus(true)
                }
            }
            self.segueBasedOnDriverStatus(false)
        })
    }
    
    func segueBasedOnDriverStatus(isDriver : Bool) {
        if (isDriver) {
            self.performSegueWithIdentifier("loginToQueue", sender: self)
        } else {
            self.performSegueWithIdentifier("loginToRequestView", sender: self)
        }
    }
    
    
    // MARK: - Login
    
    @IBAction func login(sender: AnyObject) {
        var alert : UIAlertController?
        
        if emailTextField.text == "" || passwordTextField.text == "" {
            // Alert for "Please fill in every field."
            print("Empty fields")
            alert = UIAlertController(title: "Buzz!", message: "Please enter your login information.", preferredStyle: UIAlertControllerStyle.Alert)
            self.presentAlert(alert)
        } else {
            // Authenticate user
            FIRAuth.auth()?.signInWithEmail(emailTextField.text!, password: passwordTextField.text!) { (user, error) in
                if error != nil {
                    // handle errors accordingly -- might have to have a switch statement to test all of them -- EDIT
                    if let errorMessage = error?.localizedDescription {
                        alert = UIAlertController(title: "Buzz!", message: "\(errorMessage)", preferredStyle: UIAlertControllerStyle.Alert)
                        self.presentAlert(alert)
                        print("An error occured: \(error)")
                    }
                    return
                }
                
                // if we get the name and phone number here from the Firebase DB then we can just save those to NSUserDefaults right here
                
                if let nameAndNumber = user?.displayName {
                    let index = nameAndNumber.characters.indexOf(",")
                    let name = nameAndNumber.substringToIndex(index!)
                    var number = nameAndNumber.substringFromIndex(index!)
                    number.removeAtIndex(number.startIndex)
                    
                    self.saveUserInformation(name, userNumber: number)
                    
                } else {
                    // if for some reason they do not have a display name, then have the user confirm their information
                    let infoAlert = UIAlertController(title: "Confirm Information", message: "Please confirm your name and phone number.", preferredStyle: .Alert)
                
                    infoAlert.addTextFieldWithConfigurationHandler({ (nameTextField) -> Void in
                        nameTextField.text = ""
                        nameTextField.placeholder = "Name"
                    })
                
                    infoAlert.addTextFieldWithConfigurationHandler({ (numberTextField) -> Void in
                        numberTextField.text = ""
                        numberTextField.placeholder = "Phone number"
                    })
                
                    infoAlert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
                        var name = ""
                        var number = ""
                    
                        if let tempNameText = infoAlert.textFields![0].text {
                            name = tempNameText
                            print(name)
                        }
                        
                        if let tempNumberText = infoAlert.textFields![1].text {
                            number = tempNumberText
                            print(number)
                        }
                    
                        if name == "" || number == "" {
                            alert = UIAlertController(title: "Buzz!", message: "Please login again and confirm your name and number.", preferredStyle: UIAlertControllerStyle.Alert)
                            self.presentAlert(alert)
                        } else {
                            self.saveUserInformation(name, userNumber: number)
                        }
                    }))
                
                    self.presentViewController(infoAlert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func saveUserInformation(userName : String, userNumber : String) {
        NSUserDefaults.standardUserDefaults().setValue(self.emailTextField.text, forKey: "email")
        NSUserDefaults.standardUserDefaults().setValue(userName, forKey: "name")
        NSUserDefaults.standardUserDefaults().setValue(userNumber, forKey: "phoneNumber")
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasLoginKey")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        self.MyKeychainWrapper.mySetObject(self.passwordTextField.text, forKey: kSecValueData)
        self.MyKeychainWrapper.writeToKeychain()
        
        self.checkDriverStatus(self.emailTextField.text!)
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

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let segID = segue.identifier
        
        if segID == "signUpSegue" {
            let destinationViewController = segue.destinationViewController as! SignUpViewController
            if let currentEmailString = emailTextField.text {
                destinationViewController.emailStringFromLogin = currentEmailString
            }
        }
        
        if segID == "loginToRequestView" {
            let destinationViewController = segue.destinationViewController as! ViewController
            
            var userName = ""
            var phoneNumber = ""
            var emailAddress = ""
            
            if let emailText = emailTextField.text {
                emailAddress = emailText
            }
            
            
            if (NSUserDefaults.standardUserDefaults().boolForKey("hasLoginKey")) {
                userName = NSUserDefaults.standardUserDefaults().objectForKey("name") as! String
                phoneNumber = NSUserDefaults.standardUserDefaults().objectForKey("phoneNumber") as! String
                emailAddress = NSUserDefaults.standardUserDefaults().objectForKey("email") as! String
            } else {
                // there is no saved user defaults login information
                // The name and phone number are saved from the DB into the defaults during login
            }
            
            destinationViewController.name = userName
            destinationViewController.phoneNumber = phoneNumber
            destinationViewController.emailAddress = emailAddress
        }
        
        if segID == "loginToQueue" {
            let destinationViewController = segue.destinationViewController as! DriverQueueViewController
            
            var driverName = ""
            var phoneNumber = ""
            var emailAddress = ""
            
            if let emailText = emailTextField.text {
                emailAddress = emailText
            }
            
            if (NSUserDefaults.standardUserDefaults().boolForKey("hasLoginKey")) {
                driverName = NSUserDefaults.standardUserDefaults().objectForKey("name") as! String
                phoneNumber = NSUserDefaults.standardUserDefaults().objectForKey("phoneNumber") as! String
                emailAddress = NSUserDefaults.standardUserDefaults().objectForKey("email") as! String
            } else {
                // there is no saved user defaults login information
                // The name and phone number are saved from the DB into the defaults during login
            }
            
            destinationViewController.driverName = driverName
            destinationViewController.driverPhoneNumber = phoneNumber
            destinationViewController.driverEmailAddress = emailAddress
            destinationViewController.isDriverActive = false
        }
        
    }

}
