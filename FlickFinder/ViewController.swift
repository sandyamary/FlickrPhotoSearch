//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(_ sender: AnyObject) {
        
        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String?] =
                [Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                 Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                 Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                 Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                 Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                 Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback,
                 Constants.FlickrParameterKeys.Text: self.phraseTextField.text
            ]
            
            displayImageFromFlickrBySearch(methodParameters as [String : AnyObject])
            
            
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(_ sender: AnyObject) {
        
        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String?] =
                [Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                 Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                 Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                 Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                 Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                 Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback,
                 Constants.FlickrParameterKeys.BoundingBox: latlonString()
            ]
            
            displayImageFromFlickrBySearch(methodParameters as [String : AnyObject])
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func latlonString() -> String {
        let minLogitude = max(Double(longitudeTextField.text!)! - (Constants.Flickr.SearchBBoxHalfHeight), Constants.Flickr.SearchLonRange.0)
        let minLatitude = max(Double(latitudeTextField.text!)! - (Constants.Flickr.SearchBBoxHalfHeight), Constants.Flickr.SearchLatRange.0)
        let maxLogitude = min(Double(longitudeTextField.text!)! + (Constants.Flickr.SearchBBoxHalfHeight), Constants.Flickr.SearchLonRange.1)
        let maxLatitude = min(Double(latitudeTextField.text!)! + (Constants.Flickr.SearchBBoxHalfHeight), Constants.Flickr.SearchLatRange.1)
        
        return "\(minLogitude),\(minLatitude),\(maxLogitude),\(maxLatitude)"
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(_ methodParameters: [String: AnyObject]) {
        
        let session = URLSession.shared
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        
        let task = session.dataTask(with: request) { (data, response, error) in
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No Photo Returned, try again."
                    self.photoImageView.image = nil
                }
            }
            
            //GUARD: Was there an error?
            guard (error == nil) else {
                displayError(error: "There was an error with your request: \(error)")
                return
            }
            
            //GUARD: Did we get a successful 2xx response?
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError(error: "your request returned an status code other than 2xx")
                return
            }
            
            // GUARD: Was there any data returned?
            guard let data = data else {
                displayError(error: "No data was returned by your request: \(error)")
                return
            }
            
            //Parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError(error: "could not parse data as JSON: \(data)")
                return
            }
            
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError(error: "Flickr returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            //GUARD: is the photos key in the parsed result, the flickr response. Also is the key "photo" in photosDictionary
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: AnyObject], let numOfPages = photosDictionary["pages"] as? Int else {
                displayError(error: "There was an error finding the key 'photos' or 'pages'")
                return
            }
            
            //Pick a random page
            if numOfPages == 0 {
                displayError(error: "total pages returned is 0 in the response")
                return
            } else {
                let maxPages = min(numOfPages, 40)
                let randomPage = Int(arc4random_uniform(UInt32(maxPages)))
                self.displayImageFromFlickrBySearch(methodParameters: methodParameters as [String : AnyObject], withPageNumber: randomPage)
            }
            
        }
        task.resume()
        
    }
    
    
    private func displayImageFromFlickrBySearch(methodParameters: [String: AnyObject], withPageNumber: Int) {
        var methodParameters = methodParameters
        let session = URLSession.shared
        methodParameters[Constants.FlickrParameterKeys.Page] = "\(withPageNumber)" as AnyObject?
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        
        let task = session.dataTask(with: request) { (data, response, error) in
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No Photo Returned, try again."
                    self.photoImageView.image = nil
                }
            }
            
            //GUARD: Was there an error?
            guard (error == nil) else {
                displayError(error: "There was an error with your request: \(error)")
                return
            }
            
            //GUARD: Did we get a successful 2xx response?
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError(error: "your request returned an status code other than 2xx")
                return
            }
            
            // GUARD: Was there any data returned?
            guard let data = data else {
                displayError(error: "No data was returned by your request: \(error)")
                return
            }
            
            //Parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError(error: "could not parse data as JSON: \(data)")
                return
            }
            
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError(error: "Flickr returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            //GUARD: is the photos key in the parsed result, the flickr response. Also is the key "photo" in photosDictionary
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: AnyObject], let arrayOfPhotoDictionaries = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                displayError(error: "There was an error finding the key 'photos' or 'photo'")
                return
            }
        
            if arrayOfPhotoDictionaries.count == 0 {
                displayError(error: "No photos were returned by the flickr response on the given page. Search again.")
                return
            } else {
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(arrayOfPhotoDictionaries.count)))
                let photoDictionary = arrayOfPhotoDictionaries[randomPhotoIndex] as [String:AnyObject]
                
                //GUARD: Does our photo have a key url_m
                guard let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String, let photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String else {
                    displayError(error: "could not find key 'url_m' or 'title'")
                    return
                }
                
                //if an image exists at the url, set label and image
                let imageURL = URL(string: imageUrlString)
                if let imageData = try? Data(contentsOf: imageURL!) {
                    performUIUpdatesOnMain {
                        self.photoImageView.image = UIImage(data: imageData)
                        self.photoTitleLabel.text = photoTitle
                        self.setUIEnabled(true)
                    }
                } else {
                    displayError(error: "Image does not exist at: \(imageURL)")
                }
                
            }
            
            
        }
        task.resume()
        
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(_ parameters: [String: AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    func isTextFieldValid(_ textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!), !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    func isValueInRange(_ value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

private extension ViewController {
    
    func setUIEnabled(_ enabled: Bool) {
        photoTitleLabel.isEnabled = enabled
        phraseTextField.isEnabled = enabled
        latitudeTextField.isEnabled = enabled
        longitudeTextField.isEnabled = enabled
        phraseSearchButton.isEnabled = enabled
        latLonSearchButton.isEnabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

private extension ViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
