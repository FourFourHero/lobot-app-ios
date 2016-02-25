//
//  ViewController.swift
//  lobot
//
//  Created by Andrew Schulak on 2/25/16.
//  Copyright © 2016 Andrew Schulak. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var usernameText: UITextField!
    @IBOutlet weak var greenLabel: UIButton!
    @IBOutlet weak var yellowLabel: UIButton!
    @IBOutlet weak var redLabel: UIButton!
    @IBOutlet weak var connectButton: UIButton!
    
    var alerts : [String]!
    var deviceToken : String!
    var username : String!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.alerts = []
        self.yellowLabel.enabled = false
        self.greenLabel.enabled = false
        self.usernameText.delegate = self
        
        // for debugging
        //self.clearUsernameInKeychain()
        
        // get any stored username from keychain
        self.loadUsernameFromKeychain()
        
        print("signing up for notifications")
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "goodDeviceToken:", name: "goodDeviceToken", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "badDeviceToken:", name: "badDeviceToken", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "registerSuccess:", name: "registerSuccess", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "registerFail:", name: "registerFail", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedPush:", name: "receivedPush", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didBecomeActive:", name: "didBecomeActive", object: nil)
        
        print("did load")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func didBecomeActive(notification:NSNotification) {
        print("did become active")
        if self.username != nil && self.username != "" {
            self.clearBadges()
        }
    }

    func textFieldShouldReturn(userText: UITextField) -> Bool {
        self.usernameText.resignFirstResponder()
        return true
    }

    @IBAction func connectButtonPushed(sender: AnyObject) {
        self.enteredUsername()
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        self.enteredUsername()
    }
    
    func enteredUsername() {
        if self.deviceToken != nil && self.deviceToken != "" {
            self.connecting()
            self.processLoginEvent()
        } else {
            let settings = UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil)
            UIApplication.sharedApplication().registerUserNotificationSettings(settings)
            UIApplication.sharedApplication().registerForRemoteNotifications()
        }
    }
    
    func processLoginEvent() {
        if self.usernameText.text != nil && self.usernameText.text != "" {
            self.usernameText.enabled = false
            self.connectButton.enabled = false
            self.registerDeviceWithServer()
        }
    }

    func clearUsernameInKeychain() {
        print("clear username in keychain")
        self.username = nil
        let latch = Latch(service: "io.cloudcityadmin.lobot")
        latch.removeObjectForKey("username")
    }

    func storeUsernameInKeychain() {
        print("store username in keychain")
        self.username = self.usernameText.text
        print(self.username)
        let latch = Latch(service: "io.cloudcityadmin.lobot")
        latch.setObject(self.username, forKey: "username")
    }
    
    func loadUsernameFromKeychain() {
        print("load username from keychain")
        let latch = Latch(service: "io.cloudcityadmin.lobot")
        let tokenData = latch.dataForKey("username")
        if tokenData != nil {
            self.username = NSString(data: tokenData!, encoding: NSUTF8StringEncoding)! as String
            self.usernameText.text = self.username
            print(self.username)
        }
    }

    func goodDeviceToken(notification:NSNotification) {
        print("vc got good device token note")
        self.deviceToken = notification.userInfo!["deviceToken"] as! String
        self.redLabel.enabled = false
        self.yellowLabel.enabled = true
        self.processLoginEvent()
    }
    
    func badDeviceToken(notification:NSNotification) {
        print("vc got bad device token note")
        let message = String("Error registering with APNS. Please try again.")
        self.alerts.append(message)
        self.showAlerts()
    }

    func connecting() {
        print("connecting")
        self.connectButton.setTitle("Connecting", forState: .Normal)
        self.connectButton.setTitleColor(UIColor.lightGrayColor(), forState: .Normal)
    }

    func registerSuccess(notification:NSNotification) {
        print("register success")
        self.yellowLabel.enabled = false
        self.greenLabel.enabled = true
        self.connectButton.setTitle("Connected", forState: .Normal)
        self.connectButton.setTitleColor(UIColor.lightGrayColor(), forState: .Normal)
        self.usernameText.textColor = UIColor.lightGrayColor()
        self.usernameText.backgroundColor = UIColor.whiteColor().colorWithAlphaComponent(0.25)
        self.storeUsernameInKeychain()
        self.clearBadges()
    }

    func registerFail(notification:NSNotification) {
        print("register fail")
        self.yellowLabel.enabled = true
        self.greenLabel.enabled = false
        self.usernameText.enabled = true
        self.usernameText.textColor = UIColor.blackColor()
        self.usernameText.backgroundColor = UIColor.whiteColor()
        self.connectButton.enabled = true
        self.connectButton.setTitle("Connect", forState: .Normal)
        self.connectButton.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        
        let message = String("Registration with Cloud City Administrator failed. Please try again.")
        self.alerts.append(message)
        self.showAlerts()
    }

    func receivedPush(notification:NSNotification) {
        print("vc received push")
        var message = notification.userInfo!["message"] as! String
        let message_num = notification.userInfo!["message_num"] as! String
        message = message_num + ":" + message
        self.alerts.append(message)
        self.showAlerts()
    }
    
    func registerDeviceWithServer() {
        print("registering device with server")
        print(self.usernameText.text!)
        let timeout = 10 as NSTimeInterval
        let url = NSURL(string: "http://cloudcityadmin.io/lobot/register?os=a&username=\(self.usernameText.text!)&registration_id=\(self.deviceToken)")
        let request: NSURLRequest = NSURLRequest(URL: url!,
            cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringCacheData,
            timeoutInterval: timeout)
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config)
        let task: NSURLSessionDataTask = session.dataTaskWithRequest(request, completionHandler: {
            (data, response, error) in
            if response == nil {
                print("Timeout")
                dispatch_async(dispatch_get_main_queue()) {
                    NSNotificationCenter.defaultCenter().postNotificationName("registerFail", object: nil)
                }
            } else {
                print("done http get")
                if let httpResponse = response as? NSHTTPURLResponse {
                    print("http status: \(httpResponse.statusCode)")
                    print(String(data: data!, encoding: NSUTF8StringEncoding))
                    if httpResponse.statusCode == 200 {
                        dispatch_async(dispatch_get_main_queue()) {
                            NSNotificationCenter.defaultCenter().postNotificationName("registerSuccess", object: nil)
                        }
                    } else {
                        dispatch_async(dispatch_get_main_queue()) {
                            NSNotificationCenter.defaultCenter().postNotificationName("registerFail", object: nil)
                        }
                    }
                }
            }
        })
        task.resume()
    }
    
    func showAlerts() {
        var message_num: String = ""
        if var alertMessage = self.alerts.first {
            if alertMessage.containsString(":") {
                print("alter contains a colon, has the message num:")
                message_num = (alertMessage as NSString).substringToIndex(1) // "Stack"
                alertMessage = (alertMessage as NSString).substringFromIndex(2)
                print("show alert message num \(message_num)")
            } else {
                print("message does not have a colon, no message num")
            }
            let alert = UIAlertController(title: "Lobot", message:alertMessage, preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "OK", style: .Default) { action in
                self.alerts.removeAtIndex(0)
                self.showAlerts()
            }
            alert.addAction(okAction)
            self.presentViewController(alert, animated: true, completion: nil)
        }
        self.clearBadges()
    }
    
    func clearBadges() {
        print("clearing badges")
        let timeout = 10 as NSTimeInterval
        let url = NSURL(string: "http://cloudcityadmin.io/badger/clear?username=\(self.username)&badge_type=1")
        let request: NSURLRequest = NSURLRequest(URL: url!,
            cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringCacheData,
            timeoutInterval: timeout)
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config)
        let task: NSURLSessionDataTask = session.dataTaskWithRequest(request, completionHandler: {
            (data, response, error) in
            if response == nil {
                print("Timeout")
            } else {
                print("badges cleared")
                print(String(data: data!, encoding: NSUTF8StringEncoding))
                dispatch_async(dispatch_get_main_queue()) {
                    UIApplication.sharedApplication().applicationIconBadgeNumber = 0
                }
            }
        })
        task.resume()
    }
}