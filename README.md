# pushpushgo_sdk - PushPushGo for Flutter Apps
![GitHub tag (latest)](https://img.shields.io/github/v/tag/ppgco/flutter-sdk?style=flat-square)
![GitHub Workflow Status (main)](https://img.shields.io/github/actions/workflow/status/ppgco/flutter-sdk/publish.yml?branch=main&style=flat-square)

Official PushPushGo SDK client for Flutter apps (iOS, Android)

## Supported platforms:
 - iOS
 - Android

## Requirements:
Account in PushPushGo with configured Android(FCM/HMS) or iOS environment

## Environment setup
Make sure that you have flutter installed, and `flutter doctor` command pass.

```bash
$ flutter doctor
```

If pass without any exceptions you are ready to go through next steps

# 1. Add SDK to your existing application
## 1.1 Install flutter package
```bash
$ flutter pub add pushpushgo_sdk
```

## 1.2 Add code to your `main.dart` file
### 1.2.1 Import library
```dart
import 'package:pushpushgo_sdk/pushpushgo_sdk.dart';
```

### 1.2.1 Initialize client and run

#### Declare and initialize Initialize
```dart
    final _pushpushgo = PushpushgoSdk({
        "apiToken": "my-api-key-from-pushpushgo-app", 
        "projectId": "my-project-id-from-pushpushgo-app"
    });
```

Then initialize client on app start

```dart
    // In your app state
    // Pass callback when user subscribe for notifications
    _pushpushgo.initialize(onNewSubscriptionHandler: (subscriberId) {
      log(subscriberId);
    });
```

#### Available methods to use with this SDK

```dart
    // Subscribe for notifications
    _pushpushgo.registerForNotifications();

    // Unsubscribe from notitfications
    _pushpushgo.unregisterFromNotifications();

    // Get subscriber id
    _pushpushgo.getSubscriberId();

    // Send beacons for subscriber
    _pushpushgo.sendBeacon(
        Beacon(
            tags: {
                Tag.fromString("my:tag"),
                Tag(
                    key: "myaa",
                    value: "aaaa",
                    strategy: "append",
                    ttl: 1000)
            },
            tagsToDelete: {},
            customId: "my_id",
            selectors: {"my": "data"}
        )
    );
```

# 2. iOS Support
## 2.1 Specify platform in your podfile in `ios/` directory
```pod
platform :ios, '14.0'
```

Add to `target 'Runner' do` on the end of declaration:

```pod
  pod 'PPG_framework', :git => 'https://github.com/ppgco/ios-sdk.git'
```

```bash
$ pod install
```

## 2.2 Open XCode with `ios/` directory
```sh
$ xed ios/
```

### 2.2.1 Enable Push Notification Capabilities in Project Target
1. Select your root item in files tree called "**your_project_name**" with blue icon and select **your_project_name** in **Target** section.
2. Go to Signing & Capabilities tab and click on "**+ Capability**" under tabs.
3. Select **Push Notifications** and **Background Modes**
4. On **Background Modes** select items:
 - Remote notifications
 - Background fetch

### 2.2.2 Add NotificationServiceExtension
1. Go to file -> New -> Target
2. Search for **Notification Service Extension** and choose product name may be for example **NSE**
3. Finish process and on prompt about __Activate “NSE” scheme?__ click **Cancel**
4. Open file NotificationService.swift
5. Paste this code:
```swift
import UserNotifications
import PPG_framework

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else { return }

        // Wait for delivery event result & image fetch before returning from extension
        let group = DispatchGroup()
        group.enter()
        group.enter()

        PPG.notificationDelivered(notificationRequest: request) { _ in
            group.leave()
        }

        DispatchQueue.global().async { [weak self] in
            self?.bestAttemptContent = PPG.modifyNotification(content)
            group.leave()
        }

        group.notify(queue: .main) {
            contentHandler(self.bestAttemptContent ?? content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
```
6. Add to previously used name **NSE** target to `Podfile`:
```pod
target 'NSE' do
  use_frameworks!
  use_modular_headers!
  pod 'PPG_framework', :git => 'https://github.com/ppgco/ios-sdk.git'
end
```

7. (optional) In `Info.plist` add folowing to enable deep linking in flutter
```xml
<key>FlutterDeepLinkingEnabled</key>
<true/>
```

## 2.3 Try to run app and fetch Push Notifications token in debug console
```bash
$ flutter run
```

# 3. Android Support

## 3.1 Add to your root build.gradle jitpack if you don't have already
```groovy
// build.gradle (root) or settings.gradle (dependencyResolutionManagement)
allprojects {
    repositories {
        // jitpack
        maven { url 'https://jitpack.io' }
        // only when use hms
        maven { url 'https://developer.huawei.com/repo/' }
    }
}
```

### 3.1.1 Add classpath dependencies in root build.gradle file:

If you have already configured fcm - omit this step

#### 3.1.1.1 For FCM:
```
classpath 'com.google.gms:google-services:4.3.15'
```
#### 3.1.1.2 For HMS:
```
classpath 'com.huawei.agconnect:agcp:1.6.0.300'
```

## 3.2 Place your `google-services.json` file in `android/app` directory

## 3.3 Add to your `AndroidManifest.xml`

This file is placed in `android/app/src/main/`

### 3.3.1 Activities (on main activity level)

```xml
    <intent-filter>
        <action android:name="APP_PUSH_CLICK" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
```

If you don't have custom application file:

### 3.3.2 Add to your `<application>` tag:
```xml
    <application
        android:name=".MainApplication" 
        ...>
```

And create file called `MainApplication` with content:

```kotlin
package ...;

import com.pushpushgo.pushpushgo_sdk.PushPushGoHelpers
import io.flutter.app.FlutterApplication

class MainApplication: FlutterApplication() {
    override fun onCreate() {
        PushPushGoHelpers.initialize(this)
        super.onCreate()
    }
}
```

Optional if you need deeplinkin add:

```xml
    <meta-data android:name="flutter_deeplinking_enabled" android:value="true" />
```

### 3.3.3 Add logic to your `MainActivity`

```kotlin
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import com.pushpushgo.pushpushgo_sdk.PushPushGoHelpers
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {

    @RequiresApi(api = Build.VERSION_CODES.TIRAMISU)
    private fun requestNotificationsPermission() {
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf<String>(Manifest.permission.POST_NOTIFICATIONS),
                0
            )
        }
    }

   override fun onCreate(savedInstanceState: Bundle?) {
       super.onCreate(savedInstanceState)

       if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
           requestNotificationsPermission();
       }

       PushPushGoHelpers.onCreate(this.application, intent, savedInstanceState)
   }

    override fun onNewIntent(intent: Intent) {
       PushPushGoHelpers.onNewIntent(this.application, intent)
    }

}
```

## 3.4 Modify build.gradle and local.properties:

### 3.4.1 Add to `android/app/local.properties`:
```groovy
flutter.minSdkVersion=21
```

### 3.4.2 Add to `android/app/build.gradle`:
```groovy
def flutterMinSdkVersion = localProperties.getProperty('flutter.minSdkVersion')
if (flutterMinSdkVersion == null) {
    flutterMinSdkVersion = 21
}
```

### 3.4.3 Modify default config
Add minSdkVersion in defaultConfig for android:
```groovy
    defaultConfig {
        minSdkVersion flutterMinSdkVersion
    }
```

### 3.4.5 Add dependencies (app level) and apply plugin

#### 3.4.5.1 For FCM
```groovy
// build.gradle (:app)
dependencies {  
    ...  
    implementation "com.github.ppgco.android-sdk:sdk:2.0.6"
    implementation platform('com.google.firebase:firebase-bom:31.0.1')
    implementation 'com.google.firebase:firebase-messaging'
}
```

On top add **apply plugin**
```groovy
apply plugin: 'com.google.gms.google-services'
```

#### 3.4.5.2 For HMS

```groovy
dependencies {
  ...
    implementation "com.github.ppgco.android-sdk:sdk:2.0.6"
    implementation 'com.huawei.agconnect:agconnect-core:1.7.0.300'
    implementation 'com.huawei.hms:push:6.5.0.300'  
}
```

On top add **apply plugin**
Paste this below `com.android.library`
```groovy
apply plugin: 'com.huawei.agconnect'
```

## 3.4 Try to run app and fetch Push Notifications token in debug console
```bash
$ flutter run
```

# Configure PushPushGo Providers

## 1. iOS
### 1.1. Prepare certificates
 1. Go to [Apple Developer Portal - Identities](https://developer.apple.com/account/resources/identifiers/list) and go to **Identifiers** section
 2. Select from list your appBundleId like `com.example.your_project_name`
 3. Look for PushNotifications and click "**Configure**" button
 4. Select your __Certificate Singing Request__ file
 5. Download Certificates and open in KeyChain Access (double click in macos)
 6. Find this certificate in list select then in context menu (right click) select export and export to .p12 format file with password.
 7. Login into app and add this `Certificate.p12` file with password via UI

## 2. Android FCM
  1. Go to [Firebase Developer Console](https://console.firebase.google.com/)
  2. Select your project and go to **Settings**
  3. On **Cloud Messaging** get data from section **Cloud Messaging API (Legacy)** (turn on if is disabled)
  4. Login into app and add this `sender_id` and `authorization key` data via UI
