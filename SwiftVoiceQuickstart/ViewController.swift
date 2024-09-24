//
//  ViewController.swift
//  Twilio Voice Quickstart - Swift
//
//  Copyright © 2016 Twilio, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import PushKit
import CallKit
import TwilioVoice
import KeychainAccess
import UserNotifications


let twimlParamTo = "to"

let kRegistrationTTLInDays = 365

let kCachedDeviceToken = "CachedDeviceToken"
let kCachedBindingDate = "CachedBindingDate"

class ViewController: UIViewController {
    
    private var accessToken: String?
    let keychain = Keychain(service: "com.twilio.SwiftVoiceQuickstart")
    var isEmailVerified = false
    
    @IBOutlet weak var qualityWarningsToaster: UILabel!
    @IBOutlet weak var placeCallButton: UIButton!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var outgoingValue: UITextField!
    @IBOutlet weak var callControlView: UIView!
    @IBOutlet weak var muteSwitch: UISwitch!
    @IBOutlet weak var speakerSwitch: UISwitch!
	@IBOutlet weak var messageLabel: UILabel!
	@IBOutlet weak var identityLabel: UILabel!
    
    var incomingPushCompletionCallback: (() -> Void)?
    
    var isSpinning: Bool
    var incomingAlertController: UIAlertController?
    
    
    
    var callKitCompletionCallback: ((Bool) -> Void)? = nil
    var audioDevice = DefaultAudioDevice()
    var activeCallInvites: [String: CallInvite]! = [:]
    var activeCalls: [String: Call]! = [:]
    
    // activeCall represents the last connected call
    var activeCall: Call? = nil
    
    var callKitProvider: CXProvider?
    let callKitCallController = CXCallController()
    var userInitiatedDisconnect: Bool = false
    
    /*
     Custom ringback will be played when this flag is enabled.
     When [answerOnBridge](https://www.twilio.com/docs/voice/twiml/dial#answeronbridge) is enabled in
     the <Dial> TwiML verb, the caller will not hear the ringback while the call is ringing and awaiting
     to be accepted on the callee's side. Configure this flag based on the TwiML application.
     */
    var playCustomRingback = false
    var ringtonePlayer: AVAudioPlayer? = nil
    
    required init?(coder aDecoder: NSCoder) {
        isSpinning = false
        
        super.init(coder: aDecoder)
    }
    
    deinit {
        // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
        if let provider = callKitProvider {
            provider.invalidate()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        toggleUIState(isEnabled: false, showCallControl: false)
        outgoingValue.delegate = self
        
        /* Please note that the designated initializer `CXProviderConfiguration(localizedName: String)` has been deprecated on iOS 14. */
        let configuration = CXProviderConfiguration(localizedName: "Voice Quickstart")
        configuration.maximumCallGroups = 2
        configuration.maximumCallsPerCallGroup = 1
        callKitProvider = CXProvider(configuration: configuration)
        if let provider = callKitProvider {
            provider.setDelegate(self, queue: nil)
        }
        
        /*
         * The important thing to remember when providing a TVOAudioDevice is that the device must be set
         * before performing any other actions with the SDK (such as connecting a Call, or accepting an incoming Call).
         * In this case we've already initialized our own `TVODefaultAudioDevice` instance which we will now set.
         */
        TwilioVoiceSDK.audioDevice = audioDevice
        
        /* Example usage of Default logger to print app logs */
        let defaultLogger = TwilioVoiceSDK.logger
        if let params = LogParameters.init(module:TwilioVoiceSDK.LogModule.platform , logLevel: TwilioVoiceSDK.LogLevel.debug, message: "The default logger is used for app logs") {
            defaultLogger.log(params: params)
        }
		
		// Initialize the message label
		updateMessageLabel(with: "No Messages yet")
		
		// Set up the identity label
		updateIdentityLabel()
    }

	func updateMessageLabel(with text: String) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			self.messageLabel?.text = "Messages: \(text)"
			print("Updating messageLabel with text: \(text)")
		}
	}
	
	func updateIdentityLabel() {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			
			if let identity = try? self.keychain.get("identity") {
				self.identityLabel?.text = "Current identity: \(identity)"
			} else {
				self.identityLabel?.text = "No identity set"
			}
		}
	}
    
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		checkForStoredEmail()
		
		// Periodically check access token expiration - every 5 min
		Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
			self?.checkAccessTokenExpiration()
		}
	}
    
    func checkForStoredEmail() {
        print("Checking for stored email...")
        do {
       print("Attempting to access keychain...")
       if let storedEmail = try keychain.get("identity") {
           print("Stored email found: \(storedEmail)")
		   self.registerForPushNotifications(with: storedEmail) { success in
               if success {
                   print("Successfully registered for push notifications with stored email")
               }
           }
       } else {
           print("No stored email found in keychain. Preparing to show email input popover...")
           DispatchQueue.main.async {
               self.performSegue(withIdentifier: "showEmailPopover", sender: nil)
           }
       }
        } catch {
            print("Error accessing keychain: \(error)")
            print("Error details: \(error.localizedDescription)")
            print("Preparing to show email input popover due to error...")
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "showEmailPopover", sender: nil)
            }
        }
        print("Finished checking for stored email.")
    }
    
    @IBAction func changeEmailButtonTapped(_ sender: UIButton) {
        // This method will be called when the "Change Email" button is tapped
        // The segue to the EmailInputViewController is already set up in the storyboard
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showEmailPopover",
           let emailInputVC = segue.destination as? EmailInputViewController {
            emailInputVC.completion = { [weak self] email in
                guard let self = self else { return }

                // Unregister existing push notifications if changing email
                if self.accessToken != nil {
                    self.credentialsInvalidated()
                }

                self.saveEmail(email)
                self.dismiss(animated: true) {
                    self.registerForPushNotifications(with: email) { success in
                        if success {
                            print("Successfully registered for push notifications with new email: \(email)")
                        } else {
                            print("Failed to register for push notifications with new email: \(email)")
                        }
                        self.verifyEmailChange(email)
                    }
                }
            }
        }
    }
    
    func verifyEmailChange(_ newEmail: String) {
        do {
            if let storedEmail = try keychain.get("identity") {
                if storedEmail == newEmail {
                    print("Email successfully updated to: \(newEmail)")
                    // You can show an alert to the user here if you want
                } else {
                    print("Error: Email not updated. Current email: \(storedEmail)")
                    // Handle the error, maybe show an alert to the user
                }
            }
        } catch {
            print("Error verifying email change: \(error)")
        }
    }

    
    func saveEmail(_ email: String) {
        do {
            try keychain.set(email, key: "identity")
            print("Email saved: \(email)")
			updateIdentityLabel()
		} catch {
            print("Error saving email to keychain: \(error)")
        }
    }
    
    func registerForPushNotifications(with identity: String, completion: @escaping (Bool) -> Void) {
        print("Registering for push notifications with identity: \(identity)")
        fetchAccessToken(identity: identity) { [weak self] success in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if success {
                    print("Access token fetched successfully for identity: \(identity)")
                    self.toggleUIState(isEnabled: true, showCallControl: false)

                    // Now that we have the access token, we can initialize PushKit
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        print("Initializing PushKit for identity: \(identity)")
                        appDelegate.initializePushKit()
                        
                        // Check if we have both accessToken and deviceToken
                        guard let accessToken = self.accessToken else {
                            print("Access token is nil. Cannot register for VoIP push notifications.")
                            completion(false)
                            return
                        }
                        
                        guard let deviceToken = appDelegate.voipRegistry.pushToken(for: .voIP) else {
                            print("Device token is nil. Cannot register for VoIP push notifications.")
                            completion(false)
                            return
                        }
                        
                        // Register for VoIP push notifications
                        TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: deviceToken) { error in
                            if let error = error {
                                print("Failed to register for VoIP push notifications: \(error.localizedDescription)")
                                completion(false)
                            } else {
                                print("Successfully registered for VoIP push notifications with identity: \(identity)")
                                completion(true)
                            }
                        }
                    } else {
                        print("Failed to initialize PushKit: AppDelegate not available")
                        completion(false)
                    }
                } else {
                    print("Failed to fetch access token for identity: \(identity)")
                    let alertController = UIAlertController(title: "Error", message: "Failed to fetch access token. The app may not function correctly.", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                    completion(false)
                }
            }
        }
    }
    
    func fetchAccessToken(identity: String, completion: @escaping (Bool) -> Void) {
		guard let serverURLString = Bundle.main.object(forInfoDictionaryKey: "ServerURL") as? String,
			  var urlComponents = URLComponents(string: serverURLString + "/access-token"),
			  let identity = try? keychain.get("identity") else {
			print("Invalid server URL or missing identity")
			completion(false)
			return
		}
		
        // Add identity as a query parameter
        urlComponents.queryItems = [URLQueryItem(name: "identity", value: identity)]
        
        guard let url = urlComponents.url else {
            print("Failed to create URL with identity")
            completion(false)
            return
        }
        
		URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self = self, let data = data, error == nil else {
				print("Error fetching access token: \(error?.localizedDescription ?? "Unknown error")")
				completion(false)
				return
			}
			
			if let accessToken = String(data: data, encoding: .utf8) {
				self.accessToken = accessToken
				print("Access Token successfully fetched")
				DispatchQueue.main.async {
					self.checkAccessTokenExpiration()
				}
				completion(true)
			} else {
				print("Invalid access token data received")
				completion(false)
			}
		}.resume()
    }
	
	func checkAccessTokenExpiration() {
		guard let accessToken = self.accessToken else {
			print("No access token available")
			return
		}
		
		// Assuming the token is a JWT, split it and decode the payload
		let parts = accessToken.components(separatedBy: ".")
		guard parts.count > 1 else {
			print("Invalid access token format")
			return
		}
		
		let payload = parts[1].padding(toLength: ((parts[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)
		guard let data = Data(base64Encoded: payload),
			  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
			  let expirationTimestamp = json["exp"] as? TimeInterval else {
			print("Unable to decode access token payload")
			return
		}
		
		let tokenExpirationDate = Date(timeIntervalSince1970: expirationTimestamp)
		let timeUntilExpiration = tokenExpirationDate.timeIntervalSinceNow
		
		print("Access token expires in \(Int(timeUntilExpiration)) seconds")
		
		if timeUntilExpiration < 300 { // 5 minutes
			print("Access token is about to expire. Refreshing...")
			// Implement token refresh logic here
			refreshAccessToken()
		}
	}
	
	func refreshAccessToken() {
		guard let identity = try? keychain.get("identity") else {
			print("No stored identity for token refresh")
			return
		}
		
		fetchAccessToken(identity: identity) { [weak self] success in
			if success {
				print("Access token refreshed successfully")
				self?.checkAccessTokenExpiration()
			} else {
				print("Failed to refresh access token")
			}
		}
	}
    
    func toggleUIState(isEnabled: Bool, showCallControl: Bool) {
        placeCallButton.isEnabled = isEnabled
        
        if showCallControl {
            callControlView.isHidden = false
            muteSwitch.isOn = getActiveCall()?.isMuted ?? false
            for output in AVAudioSession.sharedInstance().currentRoute.outputs {
                speakerSwitch.isOn = output.portType == AVAudioSession.Port.builtInSpeaker
            }
        } else {
            callControlView.isHidden = true
        }
    }
    
    func showMicrophoneAccessRequest(_ uuid: UUID, _ handle: String) {
        let alertController = UIAlertController(title: "Voice Quick Start",
                                                message: "Microphone permission not granted",
                                                preferredStyle: .alert)
        
        let continueWithoutMic = UIAlertAction(title: "Continue without microphone", style: .default) { [weak self] _ in
            self?.performStartCallAction(uuid: uuid, handle: handle)
        }
        
        let goToSettings = UIAlertAction(title: "Settings", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                      options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: false],
                                      completionHandler: nil)
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.toggleUIState(isEnabled: true, showCallControl: false)
            self?.stopSpin()
        }
        
        [continueWithoutMic, goToSettings, cancel].forEach { alertController.addAction($0) }
        
        present(alertController, animated: true, completion: nil)
    }
    
    func getActiveCall() -> Call? {
        if let activeCall = activeCall {
            return activeCall
        } else if activeCalls.count == 1 {
            // This is a scenario when the only remaining call is still on hold after the previous call has ended
            return activeCalls.first?.value
        } else {
            return nil
        }
    }
    
    @IBAction func mainButtonPressed(_ sender: Any) {
        if !activeCalls.isEmpty {
            guard let activeCall = getActiveCall() else { return }
            userInitiatedDisconnect = true
            performEndCallAction(uuid: activeCall.uuid!)
            return
        }
        
        checkRecordPermission { [weak self] permissionGranted in
            let uuid = UUID()
            let handle = "Voice Bot"
            
            guard !permissionGranted else {
                self?.performStartCallAction(uuid: uuid, handle: handle)
                return
            }
            
            self?.showMicrophoneAccessRequest(uuid, handle)
        }
    }
    
    func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission
        
        switch permissionStatus {
        case .granted:
            // Record permission already granted.
            completion(true)
        case .denied:
            // Record permission denied.
            completion(false)
        case .undetermined:
            // Requesting record permission.
            // Optional: pop up app dialog to let the users know if they want to request.
            AVAudioSession.sharedInstance().requestRecordPermission { granted in completion(granted) }
        default:
            completion(false)
        }
    }
    
    @IBAction func muteSwitchToggled(_ sender: UISwitch) {
        guard let activeCall = getActiveCall() else { return }
        
        activeCall.isMuted = sender.isOn
    }
    
    @IBAction func speakerSwitchToggled(_ sender: UISwitch) {
        toggleAudioRoute(toSpeaker: sender.isOn)
    }
    
    
    // MARK: AVAudioSession
    
    func toggleAudioRoute(toSpeaker: Bool) {
        // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver. Use port override to switch the route.
        audioDevice.block = {
            do {
                if toSpeaker {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                } else {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                }
            } catch {
                NSLog(error.localizedDescription)
            }
        }
        
        audioDevice.block()
    }
    
    
    // MARK: Icon spinning
    
    func startSpin() {
        guard !isSpinning else { return }
        
        isSpinning = true
        spin(options: UIView.AnimationOptions.curveEaseIn)
    }
    
    func stopSpin() {
        isSpinning = false
    }
    
    func spin(options: UIView.AnimationOptions) {
        UIView.animate(withDuration: 0.5, delay: 0.0, options: options, animations: { [weak iconView] in
            if let iconView = iconView {
                iconView.transform = iconView.transform.rotated(by: CGFloat(Double.pi/2))
            }
        }) { [weak self] finished in
            guard let strongSelf = self else { return }
            
            if finished {
                if strongSelf.isSpinning {
                    strongSelf.spin(options: UIView.AnimationOptions.curveLinear)
                } else if options != UIView.AnimationOptions.curveEaseOut {
                    strongSelf.spin(options: UIView.AnimationOptions.curveEaseOut)
                }
            }
        }
    }
	
	
}


// MARK: - UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        outgoingValue.resignFirstResponder()
        return true
    }
}


// MARK: - PushKitEventDelegate

extension ViewController: PushKitEventDelegate {
    func credentialsUpdated(credentials: PKPushCredentials) {
		print("Credentials updated. Token length: \(credentials.token.count)")
        guard
            let accessToken = self.accessToken,
            let identity = try? keychain.get("identity"),
            (registrationRequired() || UserDefaults.standard.data(forKey: kCachedDeviceToken) != credentials.token)
        else {
            print("Credentials update not required")
            return
        }
        
        let cachedDeviceToken = credentials.token
        print("Registering for push with identity: \(identity)")
        
        /*
         * Perform registration if a new device token is detected.
         */
        TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: cachedDeviceToken) { error in
            if let error = error {
                NSLog("An error occurred while registering: \(error.localizedDescription)")
            } else {
                NSLog("Successfully registered for VoIP push notifications.")
                
                // Save the device token after successfully registered.
                UserDefaults.standard.set(cachedDeviceToken, forKey: kCachedDeviceToken)
                
                /**
                 * The TTL of a registration is 1 year. The TTL for registration for this device/identity
                 * pair is reset to 1 year whenever a new registration occurs or a push notification is
                 * sent to this device/identity pair.
                 */
                UserDefaults.standard.set(Date(), forKey: kCachedBindingDate)
            }
        }
    }
    
    /**
     * The TTL of a registration is 1 year. The TTL for registration for this device/identity pair is reset to
     * 1 year whenever a new registration occurs or a push notification is sent to this device/identity pair.
     * This method checks if binding exists in UserDefaults, and if half of TTL has been passed then the method
     * will return true, else false.
     */
    func registrationRequired() -> Bool {
        guard
            let lastBindingCreated = UserDefaults.standard.object(forKey: kCachedBindingDate)
        else { return true }
        
        let date = Date()
        var components = DateComponents()
        components.setValue(kRegistrationTTLInDays/2, for: .day)
        let expirationDate = Calendar.current.date(byAdding: components, to: lastBindingCreated as! Date)!
        
        if expirationDate.compare(date) == ComparisonResult.orderedDescending {
            return false
        }
        return true;
    }
    
    func credentialsInvalidated() {
        print("Invalidating credentials")
        guard let deviceToken = UserDefaults.standard.data(forKey: kCachedDeviceToken),
              let accessToken = self.accessToken else { return }
        
        TwilioVoiceSDK.unregister(accessToken: accessToken, deviceToken: deviceToken) { error in
            if let error = error {
                NSLog("An error occurred while unregistering: \(error.localizedDescription)")
            } else {
                NSLog("Successfully unregistered from VoIP push notifications.")
            }
        }
        
        UserDefaults.standard.removeObject(forKey: kCachedDeviceToken)
        
        // Remove the cached binding as credentials are invalidated
        UserDefaults.standard.removeObject(forKey: kCachedBindingDate)
    }
    
    func incomingPushReceived(payload: PKPushPayload) {
        // The Voice SDK will use main queue to invoke `cancelledCallInviteReceived:error:` when delegate queue is not passed
        TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
    }
    
    func incomingPushReceived(payload: PKPushPayload, completion: @escaping () -> Void) {
        NSLog("Received push notification: \(payload.dictionaryPayload)")
		
		checkAccessTokenExpiration()
        
        guard let aps = payload.dictionaryPayload["aps"] as? [String: Any] else {
            NSLog("Error: Invalid push notification payload structure")
            completion()
            return
        }
        
        // The Voice SDK will use main queue to invoke `cancelledCallInviteReceived:error:` when delegate queue is not passed
        TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
        
        if let version = Float(UIDevice.current.systemVersion), version < 13.0 {
            // Save for later when the notification is properly handled.
            incomingPushCompletionCallback = completion
        } else {
            completion()
        }
    }
    
    func incomingPushHandled() {
        guard let completion = incomingPushCompletionCallback else { return }
        
        incomingPushCompletionCallback = nil
        completion()
    }
}


// MARK: - TVONotificaitonDelegate

extension ViewController: NotificationDelegate {
    func callInviteReceived(callInvite: CallInvite) {
		NSLog("callInviteReceived:")
		NSLog("TVOCallInvite Parameters:")
		NSLog("- Custom Parameters: \(String(describing: callInvite.customParameters))")
				
        guard let _ = self.accessToken else {
            NSLog("Error: Access token not available when receiving call invite")
            return
        }
        
        /**
         * The TTL of a registration is 1 year. The TTL for registration for this device/identity
         * pair is reset to 1 year whenever a new registration occurs or a push notification is
         * sent to this device/identity pair.
         */
        UserDefaults.standard.set(Date(), forKey: kCachedBindingDate)
        
        let callerInfo: TVOCallerInfo = callInvite.callerInfo
        if let verified: NSNumber = callerInfo.verified {
            if verified.boolValue {
                NSLog("Call invite received from verified caller number!")
            }
        }
		
		// Safely extract custom display name if available
		let displayName: String
		if let customParameters = callInvite.customParameters,
			   let customDisplayName = customParameters["displayName"] {
				displayName = customDisplayName
			NSLog("Using custom display name: \(displayName)")
		} else {
			// Use the custom display name or fall back to the original "from" logic
				displayName = (callInvite.from ?? "Voice Bot").replacingOccurrences(of: "client:", with: "")
			NSLog("Using default display name: \(displayName)")
		}

        // Always report to CallKit
        reportIncomingCall(from: displayName, uuid: callInvite.uuid)
        activeCallInvites[callInvite.uuid.uuidString] = callInvite
    }
    
    func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        NSLog("cancelledCallInviteCanceled:error:, error: \(error.localizedDescription)")
        
        guard let activeCallInvites = activeCallInvites, !activeCallInvites.isEmpty else {
            NSLog("No pending call invite")
            return
        }
        
        let callInvite = activeCallInvites.values.first { invite in invite.callSid == cancelledCallInvite.callSid }
        
        if let callInvite = callInvite {
            performEndCallAction(uuid: callInvite.uuid)
            self.activeCallInvites.removeValue(forKey: callInvite.uuid.uuidString)
        }
    }
}


// MARK: - TVOCallDelegate

extension ViewController: CallDelegate {
    func callDidStartRinging(call: Call) {
        NSLog("CallDelegate:callDidStartRinging:")
        
        placeCallButton.setTitle("Ringing", for: .normal)
        
        /*
         When [answerOnBridge](https://www.twilio.com/docs/voice/twiml/dial#answeronbridge) is enabled in the
         <Dial> TwiML verb, the caller will not hear the ringback while the call is ringing and awaiting to be
         accepted on the callee's side. The application can use the `AVAudioPlayer` to play custom audio files
         between the `[TVOCallDelegate callDidStartRinging:]` and the `[TVOCallDelegate callDidConnect:]` callbacks.
         */
        if playCustomRingback {
            playRingback()
        }
    }
    
    func callDidConnect(call: Call) {
		NSLog("CallDelegate:callDidConnect called for call SID: \(call.sid)")

		
		
        if playCustomRingback {
            stopRingback()
        }
        
        if let callKitCompletionCallback = callKitCompletionCallback {
            callKitCompletionCallback(true)
        }
        
        placeCallButton.setTitle("Hang Up", for: .normal)
        
        stopSpin()
        toggleAudioRoute(toSpeaker: true)
        toggleUIState(isEnabled: true, showCallControl: true)
    }
    
    func callIsReconnecting(call: Call, error: Error) {
        NSLog("CallDelegate:call:isReconnectingWithError:")
        
        placeCallButton.setTitle("Reconnecting", for: .normal)
        
        toggleUIState(isEnabled: false, showCallControl: false)
    }
    
    func callDidReconnect(call: Call) {
        NSLog("CallDelegate:callDidReconnect:")
        
        placeCallButton.setTitle("Hang Up", for: .normal)
        
        toggleUIState(isEnabled: true, showCallControl: true)
    }
    
    func callDidFailToConnect(call: Call, error: Error) {
        NSLog("CallDelegate:Call failed to connect: \(error.localizedDescription)")
        
        if let completion = callKitCompletionCallback {
            completion(false)
        }
        
        if let provider = callKitProvider {
            provider.reportCall(with: call.uuid!, endedAt: Date(), reason: CXCallEndedReason.failed)
        }
        
        callDisconnected(call: call)
    }
    
    func callDidDisconnect(call: Call, error: Error?) {
        if let error = error {
            NSLog("CallDelegate:Call failed: \(error.localizedDescription)")
        } else {
            NSLog("CallDelegate:Call disconnected")
        }
        
        if !userInitiatedDisconnect {
            var reason = CXCallEndedReason.remoteEnded
            
            if error != nil {
                reason = .failed
            }
            
            if let provider = callKitProvider {
                provider.reportCall(with: call.uuid!, endedAt: Date(), reason: reason)
            }
        }
        
        callDisconnected(call: call)
    }
    
    func callDisconnected(call: Call) {
        if call == activeCall {
            activeCall = nil
        }
        
        activeCalls.removeValue(forKey: call.uuid!.uuidString)
        
        userInitiatedDisconnect = false
        
        if playCustomRingback {
            stopRingback()
        }
        
        stopSpin()
        if activeCalls.isEmpty {
            toggleUIState(isEnabled: true, showCallControl: false)
            placeCallButton.setTitle("Call", for: .normal)
        } else {
            guard let activeCall = getActiveCall() else { return }
            toggleUIState(isEnabled: true, showCallControl: true)
        }
		
		updateMessageLabel(with: "")
	}
    
    func callDidReceiveQualityWarnings(call: Call, currentWarnings: Set<NSNumber>, previousWarnings: Set<NSNumber>) {
        /**
         * currentWarnings: existing quality warnings that have not been cleared yet
         * previousWarnings: last set of warnings prior to receiving this callback
         *
         * Example:
         *   - currentWarnings: { A, B }
         *   - previousWarnings: { B, C }
         *   - intersection: { B }
         *
         * Newly raised warnings = currentWarnings - intersection = { A }
         * Newly cleared warnings = previousWarnings - intersection = { C }
         */
        var warningsIntersection: Set<NSNumber> = currentWarnings
        warningsIntersection = warningsIntersection.intersection(previousWarnings)
        
        var newWarnings: Set<NSNumber> = currentWarnings
        newWarnings.subtract(warningsIntersection)
        if newWarnings.count > 0 {
            qualityWarningsUpdatePopup(newWarnings, isCleared: false)
        }
        
        var clearedWarnings: Set<NSNumber> = previousWarnings
        clearedWarnings.subtract(warningsIntersection)
        if clearedWarnings.count > 0 {
            qualityWarningsUpdatePopup(clearedWarnings, isCleared: true)
        }
    }
    
    func qualityWarningsUpdatePopup(_ warnings: Set<NSNumber>, isCleared: Bool) {
        var popupMessage: String = "Warnings detected: "
        if isCleared {
            popupMessage = "Warnings cleared: "
        }
        
        let mappedWarnings: [String] = warnings.map { number in warningString(Call.QualityWarning(rawValue: number.uintValue)!)}
        popupMessage += mappedWarnings.joined(separator: ", ")
        
        qualityWarningsToaster.alpha = 0.0
        qualityWarningsToaster.text = popupMessage
        UIView.animate(withDuration: 1.0, animations: {
            self.qualityWarningsToaster.isHidden = false
            self.qualityWarningsToaster.alpha = 1.0
        }) { [weak self] finish in
            guard let strongSelf = self else { return }
            let deadlineTime = DispatchTime.now() + .seconds(5)
            DispatchQueue.main.asyncAfter(deadline: deadlineTime, execute: {
                UIView.animate(withDuration: 1.0, animations: {
                    strongSelf.qualityWarningsToaster.alpha = 0.0
                }) { (finished) in
                    strongSelf.qualityWarningsToaster.isHidden = true
                }
            })
        }
    }
    
    func warningString(_ warning: Call.QualityWarning) -> String {
        switch warning {
        case .highRtt: return "high-rtt"
        case .highJitter: return "high-jitter"
        case .highPacketsLostFraction: return "high-packets-lost-fraction"
        case .lowMos: return "low-mos"
        case .constantAudioInputLevel: return "constant-audio-input-level"
        default: return "Unknown warning"
        }
    }
    
    
    // MARK: Ringtone
    
    func playRingback() {
        let ringtonePath = URL(fileURLWithPath: Bundle.main.path(forResource: "ringtone", ofType: "wav")!)
        
        do {
            ringtonePlayer = try AVAudioPlayer(contentsOf: ringtonePath)
            ringtonePlayer?.delegate = self
            ringtonePlayer?.numberOfLoops = -1
            
            ringtonePlayer?.volume = 1.0
            ringtonePlayer?.play()
        } catch {
            NSLog("CallDelegate:Failed to initialize audio player")
        }
    }
    
    func stopRingback() {
        guard let ringtonePlayer = ringtonePlayer, ringtonePlayer.isPlaying else { return }
        
        ringtonePlayer.stop()
    }
}

// MARK: - TVOCallMessageDelegate

extension ViewController: CallMessageDelegate {
	func callDidReceiveMessage(call: Call, message callMessage: CallMessage) {
		NSLog("callDidReceiveMessage method called for call SID: \(call.sid)")
		NSLog("Received message: \(callMessage)")
		
		if let jsonData = callMessage.content.data(using: .utf8),
		   let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
			if let message = json["message"] as? String {
				NSLog("Parsed message: \(message)")
				updateMessageLabel(with: message)
			} else {
				NSLog("Parsed JSON: \(json)")
				updateMessageLabel(with: callMessage.content)
			}
		} else {
			NSLog("Message content: \(callMessage.content)")
			updateMessageLabel(with: callMessage.content)
		}
	}
}


// MARK: - CXProviderDelegate

extension ViewController: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        NSLog("CXProviderDelegate:providerDidReset:")
        audioDevice.isEnabled = false
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        NSLog("CXProviderDelegate:providerDidBegin")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        NSLog("CXProviderDelegate:provider:didActivateAudioSession:")
        audioDevice.isEnabled = true
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NSLog("CXProviderDelegate:provider:didDeactivateAudioSession:")
        audioDevice.isEnabled = false
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        NSLog("CXProviderDelegate:provider:timedOutPerformingAction:")
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        NSLog("CXProviderDelegate:provider:performStartCallAction:")
        
        toggleUIState(isEnabled: false, showCallControl: false)
        startSpin()
        
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        
        performVoiceCall(uuid: action.callUUID, client: "") { success in
            if success {
                NSLog("CXProviderDelegate:performVoiceCall() successful")
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
            } else {
                NSLog("CXProviderDelegate:performVoiceCall() failed")
            }
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NSLog("CXProviderDelegate:provider:performAnswerCallAction:")
        
        performAnswerVoiceCall(uuid: action.callUUID) { success in
            if success {
                NSLog("CXProviderDelegate:performAnswerVoiceCall() successful")
            } else {
                NSLog("CXProviderDelegate:performAnswerVoiceCall() failed")
            }
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NSLog("CXProviderDelegate:provider:performEndCallAction:")
        
        if let invite = activeCallInvites[action.callUUID.uuidString] {
            invite.reject()
            activeCallInvites.removeValue(forKey: action.callUUID.uuidString)
        } else if let call = activeCalls[action.callUUID.uuidString] {
            call.disconnect()
        } else {
            NSLog("CXProviderDelegate:Unknown UUID to perform end-call action with")
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        NSLog("CXProviderDelegate:provider:performSetHeldAction:")
        
        if let call = activeCalls[action.callUUID.uuidString] {
            call.isOnHold = action.isOnHold
            
            /** Explicitly enable the TVOAudioDevice.
             * This is workaround for an iOS issue where the `provider(_:didActivate:)` method is not called
             * when un-holding a VoIP call after an ended PSTN call.
             */ https://developer.apple.com/forums/thread/694836
            if !call.isOnHold {
                audioDevice.isEnabled = true
                activeCall = call
            }
            
            toggleUIState(isEnabled: true, showCallControl: true)
            
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        NSLog("CXProviderDelegate:provider:performSetMutedAction:")
        
        if let call = activeCalls[action.callUUID.uuidString] {
            call.isMuted = action.isMuted
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    
    // MARK: Call Kit Actions
    func performStartCallAction(uuid: UUID, handle: String) {
        guard let provider = callKitProvider else {
            NSLog("performStartCallAction:CallKit provider not available")
            return
        }
        
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)
        
        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("performStartCallAction:StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }
            
            NSLog("performStartCallAction:StartCallAction transaction request successful")
            
            let callUpdate = CXCallUpdate()
            
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false
            
            provider.reportCall(with: uuid, updated: callUpdate)
        }
    }
    
    func reportIncomingCall(from: String, uuid: UUID) {
        guard let provider = callKitProvider else {
            NSLog("CallKit provider not available")
            return
        }
        
        let callHandle = CXHandle(type: .generic, value: from)
        let callUpdate = CXCallUpdate()
        
        callUpdate.remoteHandle = callHandle
		callUpdate.localizedCallerName = from  // This should now be our custom display name
		NSLog("Reporting incoming call with name: \(from)")
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false
        
        provider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if let error = error {
                NSLog("Failed to report incoming call successfully: \(error.localizedDescription).")
            } else {
                NSLog("Incoming call successfully reported.")
            }
        }
    }
    
    func performEndCallAction(uuid: UUID) {
        
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("EndCallAction transaction request failed: \(error.localizedDescription).")
            } else {
                NSLog("EndCallAction transaction request successful")
            }
        }
    }
    
    func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Void) {
        guard let accessToken = self.accessToken else {
            print("Access token not available")
            completionHandler(false)
            return
        }
        
        let connectOptions = ConnectOptions(accessToken: accessToken) { builder in
            builder.params = [twimlParamTo: self.outgoingValue.text ?? ""]
            builder.uuid = uuid
			builder.callMessageDelegate = self  // Add this line
        }
        
        let call = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        activeCall = call
        activeCalls[call.uuid!.uuidString] = call
        callKitCompletionCallback = completionHandler
    }
    
    func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Void) {
        guard let callInvite = activeCallInvites[uuid.uuidString] else {
            NSLog("No CallInvite matches the UUID")
			completionHandler(false)
            return
        }
        
        let acceptOptions = AcceptOptions(callInvite: callInvite) { builder in
            builder.uuid = callInvite.uuid
			builder.callMessageDelegate = self  // Add this line
        }
        
		let call = callInvite.accept(options: acceptOptions, delegate: self)
		NSLog("Call accepted with UUID: \(call.uuid?.uuidString ?? "unknown")")
		activeCall = call
		activeCalls[call.uuid!.uuidString] = call
		callKitCompletionCallback = completionHandler
		
		
        
        activeCallInvites.removeValue(forKey: uuid.uuidString)
        
        guard #available(iOS 13, *) else {
            incomingPushHandled()
            return
        }
    }
}


// MARK: - AVAudioPlayerDelegate

extension ViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            NSLog("Audio player finished playing successfully");
        } else {
            NSLog("Audio player finished playing with some error");
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            NSLog("Decode error occurred: \(error.localizedDescription)")
        }
    }
}
