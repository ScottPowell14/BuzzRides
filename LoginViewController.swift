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
    fileprivate var _refHandle : FIRDatabaseHandle!
    var contractedDrivers : [FIRDataSnapshot]! = [] // list of the contracted drivers
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setNeedsStatusBarAppearanceUpdate()
        UIApplication.shared.statusBarStyle = .lightContent
        
        // check if user's login info is saved for auto login
        if UserDefaults.standard.bool(forKey: "hasLoginKey") {
            // authenticate user method -- nah just do it separately
            let emailUserName = UserDefaults.standard.object(forKey: "email") as! String
            let password = MyKeychainWrapper.myObject(forKey: "v_Data") as! String
            
            self.emailTextField.text = emailUserName
            self.passwordTextField.text = password
            
            FIRAuth.auth()?.signIn(withEmail: emailUserName, password: password) { (user, error) in
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func userTappedBackground() {
        view.endEditing(true)
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    // MARK: Check if driver for login
    
    func checkDriverStatus(_ userName : String) {
        // get the substring before "@"
        let splitIndex = userName.characters.index(of: "@")
        let user = userName.substring(to: splitIndex!)
        
        
        ref = FIRDatabase.database().reference()
        let driverListRef = ref.child("contractedDrivers")
        
        _refHandle = driverListRef.observe(.value, with: { (snapshot) -> Void in
            
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
    
    func segueBasedOnDriverStatus(_ isDriver : Bool) {
        if (isDriver) {
            self.performSegue(withIdentifier: "loginToQueue", sender: self)
        } else {
            self.performSegue(withIdentifier: "loginToRequestView", sender: self)
        }
    }
    
    
    // MARK: - Login
    
    @IBAction func login(_ sender: AnyObject) {
        var alert : UIAlertController?
        
        if emailTextField.text == "" || passwordTextField.text == "" {
            // Alert for "Please fill in every field."
            print("Empty fields")
            alert = UIAlertController(title: "Buzz!", message: "Please enter your login information.", preferredStyle: UIAlertControllerStyle.alert)
            self.presentAlert(alert)
        } else {
            // Authenticate user
            FIRAuth.auth()?.signIn(withEmail: emailTextField.text!, password: passwordTextField.text!) { (user, error) in
                if error != nil {
                    // handle errors accordingly -- might have to have a switch statement to test all of them -- EDIT
                    if let errorMessage = error?.localizedDescription {
                        alert = UIAlertController(title: "Buzz!", message: "\(errorMessage)", preferredStyle: UIAlertControllerStyle.alert)
                        self.presentAlert(alert)
                        print("An error occured: \(error)")
                    }
                    return
                }
                
                // if we get the name and phone number here from the Firebase DB then we can just save those to NSUserDefaults right here
                
                if let nameAndNumber = user?.displayName {
                    let index = nameAndNumber.characters.index(of: ",")
                    let name = nameAndNumber.substring(to: index!)
                    var number = nameAndNumber.substring(from: index!)
                    number.remove(at: number.startIndex)
                    
                    self.saveUserInformation(name, userNumber: number)
                    
                } else {
                    // if for some reason they do not have a display name, then have the user confirm their information
                    let infoAlert = UIAlertController(title: "Confirm Information", message: "Please confirm your name and phone number.", preferredStyle: .alert)
                
                    infoAlert.addTextField(configurationHandler: { (nameTextField) -> Void in
                        nameTextField.text = ""
                        nameTextField.placeholder = "Name"
                    })
                
                    infoAlert.addTextField(configurationHandler: { (numberTextField) -> Void in
                        numberTextField.text = ""
                        numberTextField.placeholder = "Phone number"
                    })
                
                    infoAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
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
                            alert = UIAlertController(title: "Buzz!", message: "Please login again and confirm your name and number.", preferredStyle: UIAlertControllerStyle.alert)
                            self.presentAlert(alert)
                        } else {
                            self.saveUserInformation(name, userNumber: number)
                        }
                    }))
                
                    self.present(infoAlert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func saveUserInformation(_ userName : String, userNumber : String) {
        UserDefaults.standard.setValue(self.emailTextField.text, forKey: "email")
        UserDefaults.standard.setValue(userName, forKey: "name")
        UserDefaults.standard.setValue(userNumber, forKey: "phoneNumber")
        UserDefaults.standard.set(true, forKey: "hasLoginKey")
        UserDefaults.standard.synchronize()
        
        self.MyKeychainWrapper.mySetObject(self.passwordTextField.text, forKey: kSecValueData)
        self.MyKeychainWrapper.writeToKeychain()
        
        self.checkDriverStatus(self.emailTextField.text!)
    }
    
    
    func presentAlert(_ alert : UIAlertController?) {
        if let alertError = alert {
            alertError.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            self.present(alertError, animated: true, completion: nil)
        }
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let segID = segue.identifier
        
        if segID == "signUpSegue" {
            let destinationViewController = segue.destination as! SignUpViewController
            if let currentEmailString = emailTextField.text {
                destinationViewController.emailStringFromLogin = currentEmailString
            }
        }
        
        if segID == "loginToRequestView" {
            let destinationViewController = segue.destination as! ViewController
            
            var userName = ""
            var phoneNumber = ""
            var emailAddress = ""
            
            if let emailText = emailTextField.text {
                emailAddress = emailText
            }
            
            
            if (UserDefaults.standard.bool(forKey: "hasLoginKey")) {
                userName = UserDefaults.standard.object(forKey: "name") as! String
                phoneNumber = UserDefaults.standard.object(forKey: "phoneNumber") as! String
                emailAddress = UserDefaults.standard.object(forKey: "email") as! String
            } else {
                // there is no saved user defaults login information
                // The name and phone number are saved from the DB into the defaults during login
            }
            
            destinationViewController.name = userName
            destinationViewController.phoneNumber = phoneNumber
            destinationViewController.emailAddress = emailAddress
        }
        
        if segID == "loginToQueue" {
            let destinationViewController = segue.destination as! DriverQueueViewController
            
            var driverName = ""
            var phoneNumber = ""
            var emailAddress = ""
            
            if let emailText = emailTextField.text {
                emailAddress = emailText
            }
            
            if (UserDefaults.standard.bool(forKey: "hasLoginKey")) {
                driverName = UserDefaults.standard.object(forKey: "name") as! String
                phoneNumber = UserDefaults.standard.object(forKey: "phoneNumber") as! String
                emailAddress = UserDefaults.standard.object(forKey: "email") as! String
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
