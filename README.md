## Twilio Voice Quickstart for iOS

> Please see our [iOS 13 Migration Guide](https://github.com/twilio/twilio-voice-ios/blob/Releases/iOS-13-Migration-Guide.md) for the latest information on iOS 13.

## Get started with Voice on iOS
* [Quickstart](#quickstart) - Run the swift quickstart app
* [Examples](#examples) - Sample applications

## References
* [Access Tokens](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/access-tokens.md) - Using access tokens
* [Managing Audio Interruptions](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/managing-audio-interruptions.md) - Managing audio interruptions
* [Managing Push Credentials](https://github.com/twilio/voice-quickstart-ios/blob/master/Docs/managing-push-credentials.md) - Managing push credentials
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


### <a name="bullet1"></a>1. Install the TwilioVoice framework in XCode

Clone this Server repo to your environment. There are two components in the repo:
    - client (XCode)
    - Server (Twilio serverless)

Go to the location you cloned the repo and open "SwiftVoiceQuickstart.xcodeproj" in XCode. This will show ObjectiveC and Swift versions of the quickstart. We will focus on Swift today

**Swift Package Manager**

Twilio Voice is now distributed via Swift Package Manager. To consume Twilio Voice using Swift Package Manager, add the `https://github.com/twilio/twilio-voice-ios` repository as a `Swift Pacakge`. To add a package dependency to your Xcode project, select File > Swift Packages > Add Package Dependency and enter its repository URL. 


<kbd><img width="500px" src="https://user-images.githubusercontent.com/47675451/124541388-9f8f5a00-de64-11eb-9e0d-09148574c33a.png"/></kbd>

<kbd><img width="500px" src="https://user-images.githubusercontent.com/47675451/124541466-d06f8f00-de64-11eb-8464-10e3fb142240.png"/></kbd>


### <a name="bullet2"></a>2. Use Twilio CLI to deploy access token and TwiML application to Twilio Serverless

You must have the following installed:

* [Node.js v10+](https://nodejs.org/en/download/)
* NPM v6+ (comes installed with newer Node versions)

Run `npm install` to install all dependencies from NPM.

Install [twilio-cli](https://www.twilio.com/docs/twilio-cli/quickstart) with:

    $ npm install -g twilio-cli

Login to the Twilio CLI. You will be prompted for your Account SID and Auth Token, both of which you can find on the dashboard of your [Twilio console](https://twilio.com/console).

    $ twilio login

Once successfully logged in, an API Key, a secret get created and stored in your keychain as the `twilio-cli` password in `SKxxxx|secret` format. Please make a note of these values to use them in the `Server/.env` file.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/Images/keychain-api-key-secret.png"/></kbd>

This app requires the [Serverless plug-in](https://github.com/twilio-labs/plugin-serverless). Install the CLI plugin with:

    $ twilio plugins:install @twilio-labs/plugin-serverless
    
Now go to the location you cloned the repo and create a Server/.env by copying from Server/.env.example

$ cp Server/.env.example Server/.env
    
Update `Server/.env` with your Account SID, auth token, API Key and secret (which you noted in the keychain above)

    ACCOUNT_SID=ACxxxx
    AUTH_TOKEN=xxxxxx
    API_KEY_SID=SKxxxx (step 2 above)
    API_SECRET=xxxxxx (step 2 above)
    APP_SID=APxxxx (available in step 3)
    PUSH_CREDENTIAL_SID=CRxxxx (available in step 6)

The `Server` folder contains a basic server component which can be used to vend access tokens or generate TwiML response for making call to a number or another client. The app is deployed to Twilio Serverless with the `serverless` plug-in:

    $ cd Server
    $ twilio serverless:deploy

The server component that's baked into this quickstart is in Node.js and runs on the Twiliio Functions environment. If you’d like to roll your own or better understand the Twilio Voice server side implementations, please see the list of starter projects in the following supported languages below:

* [voice-quickstart-server-java](https://github.com/twilio/voice-quickstart-server-java)
* [voice-quickstart-server-node](https://github.com/twilio/voice-quickstart-server-node)
* [voice-quickstart-server-php](https://github.com/twilio/voice-quickstart-server-php)
* [voice-quickstart-server-python](https://github.com/twilio/voice-quickstart-server-python)
    
    Note down the url deployed for the `make-call` endpoint.

### <a name="bullet3"></a>3. Create a TwiML application for the Access Token

Next, we need to create a TwiML application. A TwiML application identifies a public URL for retrieving [TwiML call control instructions](https://www.twilio.com/docs/api/twiml). When your iOS app makes a call to the Twilio cloud, Twilio will make a webhook request to this URL, your application server will respond with generated TwiML, and Twilio will execute the instructions you’ve provided.

1) 
Use Twilio CLI to create a new TwiML application with the `make-call` endpoint you have just deployed

    $ twilio api:core:applications:create \
        --friendly-name=my-twiml-app \
        --voice-method=POST \
        --voice-url="https://my-quickstart-dev.twil.io/make-call"

You should receive an Appliciation SID that looks like this

    APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    
Update your .env file with the APxxx SID

### <a name="bullet4"></a>4. Generate an access token for the quickstart

Install the `token` plug-in

    $ twilio plugins:install @twilio-labs/plugin-token

Use the TwiML App SID you just created to generate an access token, replacing `YOUR NAME` and the `APXXXX`. In the example below the token is set up for 1 hour to allow enough time to experiment. You can remove the TTL or set it to a value you prefer.

    $ twilio token:voice --ttl=3600 --identity=<YOUR NAME> --voice-app-sid=APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Copy the access token string. Your iOS app will use this token to connect to Twilio.

### <a name="bullet5"></a>5. Run the Swift Quickstart app

Now let’s go back to XCode and `SwiftVoiceQuickstart.xcodeproj`. Open `ViewController.swift` under `SwiftVoiceQuickstart` and update the placeholder of `accessToken` with access token string you just copied from the Twilio CLI"

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

Build and run the app. (Product->Build & Product->Run). Note: If you get an Error for token under AudioDeviceExample, close the window and open only the `SwiftVoiceQuickstart.xcodeproj` instead.
    
You should now be presented with the following screen in the iPhone emulator:

<kbd><img width="300px" src="https://user-images.githubusercontent.com/47675451/124545192-e9c80980-de6b-11eb-960a-2ed0502bb472.png"/></kbd>

Leave the text field empty and press the call button to start a call. You will hear the congratulatory message. Support for dialing another client or number is described in steps 8 and 9. Tap "Hang Up" to disconnect.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/Images/hang-up.png"/></kbd>

### <a name="bullet6"></a>6. Create a Push Credential with your VoIP Service Certificate

The Programmable Voice SDK uses Apple’s VoIP Services to let your application know when it is receiving an incoming call. If you want your users to receive incoming calls, you’ll need to enable VoIP Services in your application and generate a VoIP Services Certificate.

Go to [Apple Developer portal](https://developer.apple.com/) and generate a VoIP Service Certificate as per theses instructions https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_certificate-based_connection_to_apns
    

Once you have generated the VoIP Services Certificate, you will need to provide the certificate and key to Twilio so that Twilio can send push notifications to your app on your behalf.

Export your VoIP Service Certificate as a `.p12` file from *Keychain Access* and extract the certificate and private key from the `.p12` file using the `openssl` command. 

    $ openssl pkcs12 -in PATH_TO_YOUR_P12 -nokeys -out cert.pem -nodes
    $ openssl pkcs12 -in PATH_TO_YOUR_P12 -nocerts -out key.pem -nodes
    $ openssl rsa -in key.pem -out key.pem

Use Twilio CLI to create a Push Credential using the cert and key.

    $ twilio api:chat:v2:credentials:create \
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

    $ twilio token:voice --ttl=86400 --identity=<YOUR NAME> --voice-app-sid=APxxxx --push-credential-sid=CRxxxxs

### <a name="bullet7"></a>7. Receive an incoming call

You are now ready to receive incoming calls. Update your app with the access token generated from step 6 and rebuild your app. The `TwilioVoiceSDK.register()` method will register your mobile client with the PushKit device token as well as the access token. Once registered, hit your application server's **/place-call** endpoint: `https://my-quickstart-dev.twil.io/place-call?to=<YOUR NAME>`. 
    
This will trigger a Twilio REST API request that will make an inbound call to the identity registered on your mobile app. Once your app accepts the call, you should hear a congratulatory message.

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

- [AudioDevice](AudioDeviceExample) - Provide your own means to playback and record audio using a custom `TVOAudioDevice` and [CoreAudio](https://developer.apple.com/documentation/coreaudio).

## More Documentation

You can find the API documentation of the Voice SDK:

* [TwilioVoice SDK API Doc](https://twilio.github.io/twilio-voice-ios/docs/latest/)

## Twilio Helper Libraries

To learn more about how to use TwiML and the Programmable Voice Calls API, check out our TwiML quickstarts:

* [TwiML Quickstart for Python](https://www.twilio.com/docs/quickstart/python/twiml)
* [TwiML Quickstart for Ruby](https://www.twilio.com/docs/quickstart/ruby/twiml)
* [TwiML Quickstart for PHP](https://www.twilio.com/docs/quickstart/php/twiml)
* [TwiML Quickstart for Java](https://www.twilio.com/docs/quickstart/java/twiml)
* [TwiML Quickstart for C#](https://www.twilio.com/docs/quickstart/csharp/twiml)

## Issues and Support

Please file any issues you find here on Github: [Voice Swift Quickstart](https://github.com/twilio/voice-quickstart-ios).
Please ensure that you are not sharing any
[Personally Identifiable Information(PII)](https://www.twilio.com/docs/glossary/what-is-personally-identifiable-information-pii)
or sensitive account information (API keys, credentials, etc.) when reporting an issue.

For general inquiries related to the Voice SDK you can [file a support ticket](https://support.twilio.com/hc/en-us/requests/new).

## License

MIT
