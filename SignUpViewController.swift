//
//  SignUpViewController.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 6/27/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import UIKit
import Firebase
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


class SignUpViewController: UIViewController, UITextFieldDelegate {
    
    
    var emailStringFromLogin : String?

    // MARK: - Text Field UI References
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    let MyKeychainWrapper = KeychainWrapper()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setNeedsStatusBarAppearanceUpdate()
        UIApplication.shared.statusBarStyle = .lightContent
        
        nameTextField.delegate = self
        phoneNumberTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self
        
        // Keyboard dismissal gesture recognizer
        let keyboardDismissGesture = UITapGestureRecognizer(target: self, action: #selector(SignUpViewController.userTappedBackground))
        self.view.addGestureRecognizer(keyboardDismissGesture)
        
        if let emailString = emailStringFromLogin {
            emailTextField.text = emailString
        }
        
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
    
    // MARK: - Sign up and Authentication
    
    @IBAction func signUp(_ sender: AnyObject) {
        // 1. Check to validate the text fields and that they contain the proper information and are formatted correctly. If not, then send alert and end method.
        var domain : String = ""
        
        if let email = emailTextField.text {
            if email.characters.count > 8 {
                domain = email.substring(from: email.characters.index(email.endIndex, offsetBy: -8))
            }
        }
        
        var alert : UIAlertController?
        
        // move this to the user initiated queue, then perform a segue on the main queue? -- The user has to be returned for the segue to occur
        // Throw in an activity indicator to show network task is being done
        
        if nameTextField.text == "" || phoneNumberTextField.text == "" || emailTextField.text == "" || passwordTextField.text == "" {
            // Alert for "Please fill in every field."
            print("Empty fields")
            alert = UIAlertController(title: "Buzz!", message: "Please completely enter your information.", preferredStyle: UIAlertControllerStyle.alert)
            self.presentAlert(alert)
        } else if domain != "@unc.edu" && domain != "duke.edu" {
            // Alert for "Please enter a valid duke.edu or unc.edu email address"
            print("Invalid email")
            alert = UIAlertController(title: "Buzz!", message: "Please enter a valid Duke or UNC email.", preferredStyle: UIAlertControllerStyle.alert)
            self.presentAlert(alert)
        } else if phoneNumberTextField.text?.characters.count < 10 {
            // Alert for "Enter a valid phone number"
            print("Invalid number")
            alert = UIAlertController(title: "Buzz!", message: "Please enter a valid phone number.", preferredStyle: UIAlertControllerStyle.alert)
            self.presentAlert(alert)
        } else {
            print("Valid information")
            // Register a user here -- may want to use something off the main thread if this takes too long
            FIRAuth.auth()?.createUser(withEmail: emailTextField.text!, password: passwordTextField.text!) { (user, error) in
                // user is a reference to the newly created user, while error is any error that may have occured
                if error != nil {
                    // Read up on FIRAuthErrors and handle each accordingly:
                    
                    // let firebaseError = error as! FIRAuthErrorCode
                    
                    /*
                    switch error {
                    case FIRAuthErrorCode.ErrorCodeNetworkError:
                        print("Network Error occured")
                        alert = UIAlertController(title: "Buzz!", message: "Network connection is slow right now. Please try again.", preferredStyle: UIAlertControllerStyle.Alert)
                        self.presentAlert(alert)
                        case FIRAuthErrorCode.
                    default:
                        print("No errors during sign up")
                        
                    }
                    */
                    
                    // Maybe this will do the trick, we'll see during testing
                    
                    if let errorMessage = error?.localizedDescription {
                        alert = UIAlertController(title: "Buzz!", message: "\(errorMessage)", preferredStyle: UIAlertControllerStyle.alert)
                        self.presentAlert(alert)
                        print("An error occured: \(error)")
                    }
                    return // end method if there is some sort of error
                }
                
                // cache / save the user information locally
                UserDefaults.standard.setValue(self.nameTextField.text, forKey: "name")
                UserDefaults.standard.setValue(self.emailTextField.text, forKey: "email")
                UserDefaults.standard.setValue(self.phoneNumberTextField.text, forKey: "phoneNumber")
                UserDefaults.standard.set(true, forKey: "hasLoginKey")
                UserDefaults.standard.synchronize()
                
                // set the display name (way to hold information about current user) to be the name and phone number, comma separated
                let changeRequest = user?.profileChangeRequest()
                changeRequest?.displayName = "\(self.nameTextField.text!),\(self.phoneNumberTextField.text!)"
                changeRequest?.commitChanges() { (error) in
                    if let error = error {
                        print(error.localizedDescription)
                        return
                    }
                }
                
                self.MyKeychainWrapper.mySetObject(self.passwordTextField.text, forKey: kSecValueData)
                self.MyKeychainWrapper.writeToKeychain()
                
                
                // perform segue here to the request view
                self.performSegue(withIdentifier: "signUpToRequestView", sender: self)
            }
        }
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
        
        if segID == "signUpToRequestView" {
            let destinationViewController = segue.destination as! ViewController
            
            destinationViewController.name = nameTextField.text
            destinationViewController.phoneNumber = phoneNumberTextField.text
            destinationViewController.emailAddress = emailTextField.text
        }
        
        
    }

}
