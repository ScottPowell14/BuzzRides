//
//  ProfileViewController.swift
//  UserLocationAndRouting
//
//  Created by Scott Powell on 7/26/16.
//  Copyright © 2016 Scott Powell. All rights reserved.
//

import UIKit
import Firebase

class ProfileViewController: UIViewController, UITextFieldDelegate {
    
    // text fields references
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    
    // user information
    var name : String?
    var phoneNumber : String?
    var emailAddress : String?
    
    
    // preserve state of request view?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setNeedsStatusBarAppearanceUpdate()
        let statusBarFrame = UIApplication.sharedApplication().statusBarFrame
        
        let view = UIView(frame: statusBarFrame)
        view.backgroundColor = UIColor(red: 244/255, green: 250/255, blue: 255/255, alpha: 1.0)
        
        self.view.addSubview(view)
        
        
        self.phoneTextField.delegate = self
        self.nameTextField.delegate = self
        
        // Keyboard dismissal gesture recognizer
        let keyboardDismissGesture = UITapGestureRecognizer(target: self, action: #selector(ProfileViewController.userTappedBackground))
        self.view.addGestureRecognizer(keyboardDismissGesture)
        
        
        self.nameTextField.text = name!
        self.phoneTextField.text = phoneNumber!
        self.emailTextField.text = emailAddress!
        
        self.emailTextField.userInteractionEnabled = false
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.Default
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func userTappedBackground() {
        view.endEditing(true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func updateChanges(sender: AnyObject) {
        if self.nameTextField.text == "" || self.phoneTextField.text == "" {
            let alert = UIAlertController(title: "Buzz!", message: "Please enter your name and phone number.", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        // send these variables back to the request page
        self.name = self.nameTextField.text
        self.phoneNumber = self.phoneTextField.text
        
        // update user defaults
        NSUserDefaults.standardUserDefaults().setValue(self.name, forKey: "name")
        NSUserDefaults.standardUserDefaults().setValue(self.phoneNumber, forKey: "phoneNumber")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        
        // update firebase database
        let user = FIRAuth.auth()?.currentUser
        let changeRequest = user?.profileChangeRequest()
        
        changeRequest?.displayName = "\(self.name!),\(self.phoneNumber!)"
        changeRequest?.commitChangesWithCompletion() { (error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
        }
        
        
        let alert = UIAlertController(title: "Buzz!", message: "Your information has been updated.", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    

    @IBAction func logOut(sender: AnyObject) {
        NSUserDefaults.standardUserDefaults().setBool(false, forKey: "hasLoginKey")
        do {
            try FIRAuth.auth()!.signOut()
            self.performSegueWithIdentifier("profileToLogin", sender: self)
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
        
    }
    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "profileToRequest" {
            let destinationViewController = segue.destinationViewController as! ViewController
            
            destinationViewController.name = self.name!
            destinationViewController.phoneNumber = self.phoneNumber!
            destinationViewController.emailAddress = self.emailAddress!
        }
        
    }

}
