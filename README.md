## Twilio Voice Quickstart for iOS

> Please see our [iOS 13 Migration Guide](https://github.com/twilio/twilio-voice-ios/blob/Releases/iOS-13-Migration-Guide.md) for the latest information on iOS 13.

## Get started with Voice on iOS

* [Quickstart](#quickstart) - Run the swift quickstart app
* [Examples](#examples) - Sample applications

## References

* [Access Tokens](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/access-tokens.md) - Using access tokens
* [Managing Audio Interruptions](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/managing-audio-interruptions.md) - Managing audio interruptions
* [Managing Push Credentials](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/managing-push-credentials.md) - Managing push credentials
* [Managing Regional Push Credentials using Notify Credential Resource API](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/push-credentials-via-notify-api.md) - Create or update push credentials for regional usage
* [More Documentation](#more-documentation) - More documentation related to the Voice iOS SDK
* [Issues and Support](#issues-and-support) - Filing issues and general support

## Voice iOS SDK Versions

* [Migration Guide from 5.x to 6.x](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/migration-guide-5.x-6.x.md) - Migrating from 5.x to 6.x
* [Migration Guide from 4.x to 5.x](https://github.com/twilio/twilio-voice-ios/blob/Releases/iOS-13-Migration-Guide.md) - Migrating from 4.x to 5.x
* [4.0 New Features](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/new-features-4.0.md) - New features in 4.0
* [Migration Guide from 3.x to 4.x](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/migration-guide-3.x-4.x.md) - Migrating from 3.x to 4.x
* [3.0 New Features](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/new-features-3.0.md) - New features in 3.0
* [Migration Guide from 2.x to 3.x](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/migration-guide-2.x-3.x.md) - Migrating from 2.x to 3.x

## Quickstart

To get started with the quickstart application follow these steps. Steps 1-5 will enable the application to make a call. The remaining steps 6-9 will enable the application to receive incoming calls in the form of push notifications using Apple’s VoIP Service.

1. [Install the TwilioVoice framework](#bullet1)
2. [Use Twilio CLI to deploy access token and TwiML application to Twilio Serverless](#bullet2)
3. [Create a TwiML application for the access token](#bullet3)
4. [Generate an access token for the quickstart](#bullet4)
5. [Run the Swift Quickstart app](#bullet5)
6. [Create a Push Credential with your VoIP Service Certificate](#bullet6)
7. [Receive an incoming call](#bullet7)
8. [Make client to client call](#bullet8)
9. [Make client to PSTN call](#bullet9)

### <a name="bullet1"></a>1. Install the TwilioVoice framework

**Swift Package Manager**

Twilio Voice is now distributed via Swift Package Manager. To consume Twilio Voice using Swift Package Manager, add the `https://github.com/twilio/twilio-voice-ios` repository as a `Swift Pacakge`.

### <a name="bullet2"></a>2. Use Twilio CLI to deploy access token and TwiML application to Twilio Serverless

You must have the following installed:

* [Node.js v16+](https://nodejs.org/en/download/)
* NPM v10+ (comes installed with newer Node versions)

Run `npm install` to install all dependencies from NPM.

Install [twilio-cli](https://www.twilio.com/docs/twilio-cli/quickstart) with:

$ npm install -g twilio-cli
Login to the Twilio CLI. You will be prompted for your Account SID and Auth Token, both of which you can find on the dashboard of your [Twilio console](https://twilio.com/console).

$ twilio login
Once successfully logged in, an API Key, a secret get created and stored in your keychain as the `twilio-cli` password in `SKxxxx|secret` format. Please make a note of these values to use them in the `Server/.env` file.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/Images/keychain-api-key-secret.png"/></kbd>

This app requires the [Serverless plug-in](https://github.com/twilio-labs/plugin-serverless). Install the CLI plugin with:

$ twilio plugins:install @twilio-labs/plugin-serverless
Before deploying, create a `Server/.env` by copying from `Server/.env.example`

$ cp Server/.env.example Server/.env
Update `Server/.env` with your Account SID, auth token, API Key and secret

ACCOUNT_SID=ACxxxx
AUTH_TOKEN=xxxxxx
API_KEY_SID=SKxxxx
API_SECRET=xxxxxx
APP_SID=APxxxx (available in step 3)
PUSH_CREDENTIAL_SID=CRxxxx (available in step 6)
The `Server` folder contains a basic server component which can be used to vend access tokens or generate TwiML response for making call to a number or another client. The app is deployed to Twilio Serverless with the `serverless` plug-in:

$ cd Server
$ twilio serverless:deploy
The server component that's baked into this quickstart is in Node.js. If you’d like to roll your own or better understand the Twilio Voice server side implementations, please see the list of starter projects in the following supported languages below:

* [voice-quickstart-server-java](https://github.com/twilio/voice-quickstart-server-java)
* [voice-quickstart-server-node](https://github.com/twilio/voice-quickstart-server-node)
* [voice-quickstart-server-php](https://github.com/twilio/voice-quickstart-server-php)
* [voice-quickstart-server-python](https://github.com/twilio/voice-quickstart-server-python)

Follow the instructions in the project's README to get the application server up and running locally and accessible via the public Internet.

### <a name="bullet3"></a>3. Create a TwiML application for the Access Token

Next, we need to create a TwiML application. A TwiML application identifies a public URL for retrieving [TwiML call control instructions](https://www.twilio.com/docs/voice/twiml). When your iOS app makes a call to the Twilio cloud, Twilio will make a webhook request to this URL, your application server will respond with generated TwiML, and Twilio will execute the instructions you’ve provided.

Use Twilio CLI to create a TwiML app with the `make-call` endpoint you have just deployed (**Note: replace the value of `--voice-url` parameter with your `make-call` endpoint you just deployed to Twilio Serverless**)

$ twilio api:core:applications:create \
    --friendly-name=my-twiml-app \
    --voice-method=POST \
    --voice-url="https://my-quickstart-dev.twil.io/make-call"
You should receive an Appliciation SID that looks like this

APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

### <a name="bullet4"></a>4. Generate an access token for the quickstart

#### Swift Quickstart ####
For the Swift Quickstart, you no longer need to manually generate an access token. The updated version will automatically generate the token using the above server /access_token endpoint within XCode Swift code. The only requirement is to update the info.plist with the Server URL

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    :
    :
    </array>
    <key>ServerURL</key>
    <string>https://my-quickstart-dev.twil.io</string>
</dict>
</plist>
```
NOTE: In the above config, we have chosen alice as the identity. You can replace it with any other identity you want to use. This will now fetch the access token from the serverless function you deployed in step 2. The access token will be fetched every time the application is started and last for 1 hour by default.

#### ObjectiveC and AudioExample ####

For the ObjectiveC and AudioExample versions, please still follow the below process:

Install the `token` plug-in

$ twilio plugins:install @twilio-labs/plugin-token
Use the TwiML App SID you just created to generate an access token

$ twilio token:voice --identity=alice --voice-app-sid=APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Copy the access token string. Your iOS app will use this token to connect to Twilio.

Now let’s go back to the `VoiceQuickstart.xcworkspace`. Update the placeholder of `accessToken` with access token string you just copied

```swift
import UIKit
import AVFoundation
import PushKit
import CallKit
import TwilioVoice

let accessToken = "PASTE_YOUR_ACCESS_TOKEN_HERE"
let twimlParamTo = "to"

let kCachedDeviceToken = "CachedDeviceToken"

class ViewController: UIViewController {
    ...
}
```
Build and run the app.

### <a name="bullet5"></a>5. Run the Swift Quickstart app

Build and run the app. Leave the text field empty and press the call button to start a call. You will hear the congratulatory message. Support for dialing another client or number is described in steps 8 and 9. Tap "Hang Up" to disconnect.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/Images/hang-up.png"/></kbd>

### <a name="bullet6"></a>6. Create a Push Credential with your VoIP Service Certificate

The Programmable Voice SDK uses Apple’s VoIP Services to let your application know when it is receiving an incoming call. If you want your users to receive incoming calls, you’ll need to enable VoIP Services in your application and generate a VoIP Services Certificate.

Go to [Apple Developer portal](https://developer.apple.com/) and generate a VoIP Service Certificate.

Once you have generated the VoIP Services Certificate, you will need to provide the certificate and key to Twilio so that Twilio can send push notifications to your app on your behalf.

Export your VoIP Service Certificate as a `.p12` file from *Keychain Access* and extract the certificate and private key from the `.p12` file using the `openssl` command.

$ openssl pkcs12 -in PATH_TO_YOUR_P12 -nokeys -out cert.pem -nodes -legacy
$ openssl x509 -in cert.pem -out cert.pem
$ openssl pkcs12 -in PATH_TO_YOUR_P12 -nocerts -out key.pem -nodes -legacy
$ openssl rsa -in key.pem -out key.pem

NOTE: using the -legacy flag is necessary to ensure that the certificate and key are in the correct format for Twilio.

Use Twilio CLI to create a Push Credential using the cert and key.

$ twilio api:conversations:v1:credentials:create \
    --type=apn \
    --sandbox \
    --friendly-name="voice-push-credential (sandbox)" \
    --certificate="$(cat PATH_TO_CERT_PEM)" \
    --private-key="$(cat PATH_TO_KEY_PEM)"
This will return a Push Credential SID that looks like this

CRxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
The `--sandbox` option tells Twilio to send the notification requests to the sandbox endpoint of Apple's APNS service. Once the app is ready for distribution or store submission, create a separate Push Credential with a new VoIP Service certificate **without** the `--sandbox` option.

**Note: we strongly recommend using different Twilio accounts (or subaccounts) to separate VoIP push notification requests for development and production apps.**

Now let's generate another access token and add the Push Credential to the Voice Grant.

$ twilio token:voice \
    --identity=alice \
    --voice-app-sid=APxxxx \
    --push-credential-sid=CRxxxxs
### <a name="bullet7"></a>7. Receive an incoming call

You are now ready to receive incoming calls. Update your app with the access token generated from step 6 and rebuild your app. The `TwilioVoiceSDK.register()` method will register your mobile client with the PushKit device token as well as the access token. Once registered, hit your application server's **/place-call** endpoint: `https://my-quickstart-dev.twil.io/place-call?to=alice`. This will trigger a Twilio REST API request that will make an inbound call to the identity registered on your mobile app. Once your app accepts the call, you should hear a congratulatory message.

Register your mobile client with the PushKit device token:

```.swift
    TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: cachedDeviceToken) { error in
        if let error = error {
            NSLog("An error occurred while registering: \(error.localizedDescription)")
        } else {
            NSLog("Successfully registered for VoIP push notifications.")              
        }
    }
```
Please note that your application must have `voip` enabled in the `UIBackgroundModes` of your app's plist in order to be able to receive push notifications.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/Images/incoming-call.png"/></kbd>

### <a name="bullet8"></a>8. Make client to client call

To make client to client calls, you need the application running on two devices. To run the application on an additional device, make sure you use a different identity in your access token when registering the new device.

Use the text field to specify the identity of the call receiver, then tap the "Call" button to make a call. The TwiML parameters used in `TwilioVoice.connect()` method should match the name used in the server.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/Images/client-to-client.png"/></kbd>

### <a name="bullet9"></a>9. Make client to PSTN call

To make client to number calls, first get a verified Twilio number to your account via https://www.twilio.com/console/phone-numbers/verified. Update your server code and replace the `callerNumber` variable with the verified number. Restart the server so it uses the new value.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/Images/client-to-pstn.png"/></kbd>

## <a name="examples"></a> Examples

You will also find additional examples that provide more advanced use cases of the Voice SDK:

- [AudioDevice](https://github.com/twilio/voice-quickstart-ios/tree/master/AudioDeviceExample) - Provide your own means to playback and record audio using a custom `TVOAudioDevice` and [CoreAudio](https://developer.apple.com/documentation/coreaudio).
- [Making calls from history](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/call-from-history.md) - Use the `INStartAudioCallIntent` in the user activity delegate method to start a call from the history.

## More Documentation

You can find the API documentation of the Voice SDK:

* [TwilioVoice SDK API Doc](https://twilio.github.io/twilio-voice-ios/docs/latest/)

## Twilio Helper Libraries

To learn more about how to use TwiML and the Programmable Voice Calls API, check out our TwiML quickstarts:

* [TwiML Quickstart for Python](https://www.twilio.com/docs/voice/quickstart/python)
* [TwiML Quickstart for Ruby](https://www.twilio.com/docs/voice/quickstart/ruby)
* [TwiML Quickstart for PHP](https://www.twilio.com/docs/voice/quickstart/php)
* [TwiML Quickstart for Java](https://www.twilio.com/docs/voice/quickstart/java)
* [TwiML Quickstart for C#](https://www.twilio.com/docs/voice/quickstart/csharp)

# Custom Message Handling in iOS Voice Client

This update implements custom message handling for the Twilio Voice iOS SDK. It allows the iOS client to receive and process messages sent from the server during an active call.

## Changes Made

1. Updated `ViewController.swift` to implement the `CallMessageDelegate` protocol.
2. Modified `performVoiceCall` and `performAnswerVoiceCall` functions to set the message delegate.
3. Implemented the `callDidReceiveMessage` method to handle incoming messages.

### Code to Add

To enable custom message handling in your iOS Voice client, add the following code:

1. In `ViewController.swift`, add the `CallMessageDelegate` extension:

```swift
// MARK: - CallMessageDelegate

extension ViewController: CallMessageDelegate {
    func callDidReceiveMessage(call: Call, message callMessage: CallMessage) {
        NSLog("callDidReceiveMessage method called for call SID: \(call.sid)")
        NSLog("Received message: \(callMessage)")
        
        if let jsonData = callMessage.content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
           let message = json["message"] as? String {
            NSLog("Parsed message: \(message)")
            // Handle the received message here
        } else {
            NSLog("Failed to parse message or unexpected format. Raw content: \(callMessage.content)")
        }
    }
}
```
Update the performVoiceCall function in your ViewController:

```swift
func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Void) {
    guard let accessToken = self.accessToken else {
        print("Access token not available")
        completionHandler(false)
        return
    }
    
    let connectOptions = ConnectOptions(accessToken: accessToken) { builder in
        builder.params = [twimlParamTo: self.outgoingValue.text ?? ""]
        builder.uuid = uuid
        builder.messageDelegate = self  // Add this line
```

Update the performAnswerVoiceCall function in your ViewController:

```swift
func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Void) {
    guard let callInvite = activeCallInvites[uuid.uuidString] else {
        NSLog("No CallInvite matches the UUID")
        completionHandler(false)
        return
    }
    
    let acceptOptions = AcceptOptions(callInvite: callInvite) { builder in
        builder.uuid = callInvite.uuid
        builder.messageDelegate = self  // Add this line
```

On the server side, you can send a message to the client during an active call using the send-message.js file once you have the call SID

# Distribution #
The next section will describe how to distribute the application via Testflight. This allows you to bundle up the package and distribute it to your testers. We will use external testers for this example.

1. set the version <DIAGRAM> and do a build clean
2. Archive the application once done you will see the application in the Organizer <INSERT DIAGRAM HERE>
3. Click the Distribute App button and select App Store Connect (This allows for external testers)
4. Click distribute
5. Once uploaded go to https://appstoreconnect.apple.com/ and log in using your Apple Developer creds
6. Click on the App Icon
7. Click on the Testflight tab
8. Click on the build you just uploaded under the version
9. Click on the external testers tab
10. Click on the plus button to add a new group of users or individual tester
11. Add the email address of the tester
12. Click on the add button
13. Click on the save button
14. Click on the save button again
15. Click on the notify button
16. Click on the notify external testers button
17. The tester will receive an email with a link to download the application
18. The tester will need to download the Testflight app from the App Store
19. The tester will need to click on the link in the email to download the application
20. The tester will need to open the Testflight app and install the application
21. The tester will need to open the application and test it
22. The tester will need to provide feedback to the developer

NOTE: Push notifications uses the Production certificate, rather than the Sandbox version, so you need to go to the Twilio Console and uncheck "sandbox."

1. Go to the Twilio Console
2. Click on admin (right hand side)
3. Click on Account Management
4. Got to Keys & Credentials -> Credentials
4. Click on the Push Credentials
5. Click on the Push Credential you created
6. Uncheck the Sandbox box
7. Click on the Save button

This will now use the same Credential SID, but via the Production path, which TestFlight needs. See here: Reference: https://www.twilio.com/docs/voice/ios/quickstart#push-credential
& https://fluffy.es/remote-push-notification-testflight-app-store/


## Issues and Support

Please file any issues you find here on Github: [Voice Swift Quickstart](https://github.com/twilio/voice-quickstart-ios).
Please ensure that you are not sharing any
[Personally Identifiable Information(PII)](https://www.twilio.com/docs/glossary/what-is-personally-identifiable-information-pii)
or sensitive account information (API keys, credentials, etc.) when reporting an issue.

For general inquiries related to the Voice SDK you can [file a support ticket](https://support.twilio.com/hc/en-us/requests/new).

## License

MIT


