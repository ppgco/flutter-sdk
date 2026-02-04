# pushpushgo_sdk - PushPushGo for Flutter Apps
![GitHub tag (latest)](https://img.shields.io/github/v/tag/ppgco/flutter-sdk?style=flat-square)
![GitHub Workflow Status (main)](https://img.shields.io/github/actions/workflow/status/ppgco/flutter-sdk/publish.yml?branch=main&style=flat-square)

Official PushPushGo SDK client for Flutter apps (iOS, Android)

> [!IMPORTANT]
> **SPM Support Added (2025):**
>
> This SDK now supports both CocoaPods and Swift Package Manager (SPM) for iOS integration. See the iOS Support section for details on both methods.
>
> New Cocoapods support is available starting from version 3.0.3 (iOS)
> 
> Swift Package Manager (SPM) support for flutter is available starting from version 3.0.0 (iOS)
>
> **Version 1.0.0+ Breaking changes**
>
> - To be able to use v1.0.0+ you will need to add AppGroups capability to your iOS project target.

## Supported platforms:
 - iOS
 - Android

## Requirements
- PPG project
- Access to Firebase Console
- Access to Apple Developers console
- For iOS - Cocoapods (or other package manager)

**Approximate time of integration (without further implementation): 2-3h.**

**Before you start, make sure to remove all previous integrations with other providers.**

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

### 1.2.1 Initialize client

#### Declare and initialize PPG client in your main application class
```dart
    final pushpushgo = PushpushgoSdk({
        "apiToken": "my-api-key-from-pushpushgo-app", 
        "projectId": "my-project-id-from-pushpushgo-app",
        // required from v1.0.0+
        // AppGroup can be received/created in Xcode -> Target Runner -> Signing&Capabilities
        "appGroupId": "your-app-group-id-from-provisioning-profile"
    });
    
    pushpushgo.initialize(onNewSubscriptionHandler: (subscriberId) {
      log(subscriberId);
    });
```

Then fill apiToken and projectId by your credentials from PPG project.

**Note: If you want to see example of integration on test app visit:** https://github.com/ppgco/flutter-example-integration


# 2. iOS Support

> **IMPORTANT: SPM Support Added!**
>
> As of version 1.2.0, this SDK supports both CocoaPods and Swift Package Manager (SPM) for iOS integration. Existing users can continue using CocoaPods, while new users are encouraged to try SPM for a simpler setup. See below for both options.

## 2.1 Option 1: Integrate via CocoaPods (Legacy, Still Supported)

**Make sure your minimum deployment platform version is at least 14.0**

Add to `target 'Runner' do` at the end of the declaration:
```pod
  pod 'PPG_framework', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '3.0.3'
```

After that, in terminal, navigate to yourFlutterProject/ios/ and run:
```bash
$ pod install
```

## 2.2 Option 2: Integrate via Swift Package Manager (Recommended)

1. **Enable SPM support in your Flutter SDK (requires Flutter 3.24+):**
   ```bash
   flutter config --enable-swift-package-manager
   ```
2. **Open your iOS project in Xcode:**
   ```bash
   xed ios/
   ```
3. **Add the PushPushGo iOS SDK as a Swift Package:**
   - In Xcode, go to `File > Add Packages...`
   - Enter the SDK repo URL: `https://github.com/ppgco/ios-sdk.git`
   - Select the version and add it to your app target (and Notification Service Extension if needed)

---

**Note:**
- Both methods are supported. SPM is recommended for new projects or if you want to avoid CocoaPods.
- If you migrate from CocoaPods to SPM, you can safely remove the Podfile and Pods directory after verifying SPM integration works.
- If you encounter issues, ensure your Flutter version is up to date and SPM is enabled with `flutter config --enable-swift-package-manager`.

## 2.3 Continue with Xcode Setup

### 2.2.1 Enable Push Notification Capabilities in Project Target
1. Select your root item in files tree called "**your_project_name**" with blue icon and select **your_project_name** in **Target** section.
2. Go to Signing & Capabilities tab and click on "**+ Capability**" under tabs.
3. Select **Push Notifications**, **Background Modes** and **AppGroups (from v1.0.0+)**
4. On **Background Modes** select items:
 - Remote notifications
 - Background fetch

### 2.2.2 Add Notification Service Extension (NSE) Support

#### 1. Create the NSE Target

1. In Xcode, go to **File > New > Target…**
2. Choose **Notification Service Extension** and give it a name (e.g., `NSE`).
3. When prompted, click **Cancel** on "Activate scheme?".
4. Open the generated `NotificationService.swift` and edit it:

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

            // Fill your app group id
            SharedData.shared.appGroupId = "YOUR APP GROUP ID" 

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

#### 2. Link PPG_framework to NSE Target

##### **A. If using Swift Package Manager (SPM):**
- In Xcode, select the NSE target.
- Go to the **General** tab.
- In **Frameworks, Libraries, and Embedded Content**, click **+**.
- Add **PPG_framework** (from the SPM section).
- Make sure it is set to "Embed & Sign" if required.

##### **B. If using CocoaPods:**
- In your `Podfile`, add:
  ```ruby
  target 'NSE' do
    use_frameworks!
    use_modular_headers!
    pod 'PPG_framework', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '3.0.3'
  end
  ```
- Run:
  ```bash
  cd ios
  pod install
  ```

#### 3. Additional Notes
- The NSE target must always have `PPG_framework` linked, regardless of package manager.
- If you use SPM for the main app, use SPM for NSE for consistency.
- If you use CocoaPods for the main app, use CocoaPods for NSE.
- If you encounter linker errors, double-check that `PPG_framework` is visible in the NSE target's "Linked Frameworks and Libraries" section in Xcode.

---
    
(optional) In `Info.plist` add folowing to enable deep linking in flutter
    ```xml
    <key>FlutterDeepLinkingEnabled</key>
    <true/>
    ```
    
## 2.3 Prepare certificates

 1. Go to [Apple Developer Portal - Identities](https://developer.apple.com/account/resources/identifiers/list) and go to **Identifiers** section
 2. Select from list your appBundleId like `com.example.your_project_name`
 3. Look for PushNotifications and click "**Configure**" button
 4. Select your __Certificate Singing Request__ file
 5. Download Certificates and open in KeyChain Access (double click in macos)
 6. Find this certificate in list select then in context menu (right click) select export and export to .p12 format file with password.
 7. Login into app and add this `Certificate.p12` file with password via UI (https://next.pushpushgo.com/projects/YourProjectID/settings/integration/apns)
 
 For manual certificate generation visit our tutorial - https://docs.pushpushgo.company/application/providers/mobile-push/apns

# 3. Android Support

## 3.1 Firebase CLI
1. Install Firebase CLI - open terminal and run command:
    ```bash
    $ curl -sL https://firebase.tools | bash
    ```
2. Install FlutterFire CLI - open terminal and run command:
    ```bash
   $ dart pub global activate flutterfire_cli
    ```
3. In terminal login to firebase:
    ```bash
   $ firebase login
    ```
4. Navigate to root of your Flutter project and run:
    ```bash
   $ flutterfire configure --project=your-firebase-project-id
    ```
   Follow instructions provided in terminal.

   Note: If you cant use flutterfire command, add **export PATH="$PATH":"$HOME/.pub-cache/bin"** to your .zshrc file.

## 3.2 Add code to your root build.gradle (/android/build.gradle)

Add jitpack and huawei repo
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

For HMS add:
```groovy
dependencies {
    classpath 'com.huawei.agconnect:agcp:1.6.0.300'
}
```

**WARNING: If you will face packagename errors from pushpushgo_sdk add this code:**
```groovy
subprojects { subproject ->
    if (subproject.name == "pushpushgo_sdk") {
        subproject.afterEvaluate {
            subproject.android {
                namespace 'com.pushpushgo.pushpushgo_sdk'
            }
        }
    }
}
```

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

## 3.4 Add logic to your `MainActivity`

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

## 3.4 Modify build.gradle:

Add dependencies in build.gradle (app level)

### 3.4.1 For FCM
```groovy
// build.gradle (:app)
dependencies {  
    ...  
    implementation "com.github.ppgco.android-sdk:sdk:2.2.4"
    implementation platform('com.google.firebase:firebase-bom:33.16.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

### 3.4.2 For HMS

```groovy
dependencies {
  ...
    implementation "com.github.ppgco.android-sdk:sdk:2.2.4"
    implementation 'com.huawei.agconnect:agconnect-core:1.7.0.300'
    implementation 'com.huawei.hms:push:6.5.0.300'  
}
```

On top add:
Paste this below `com.android.library`
```groovy
    id 'com.huawei.agconnect'
```

## 3.5 Generate FCM v1 credentials and upload it in PPG APP:
   * Go to your Firebase console and navigate to project settings
   * Open Cloud Messaging tab
   * Click Manage Service Accounts
   * Click on your service account email
   * Navigate to KEYS tab
   * Click ADD KEY
   * Click CREATE NEW KEY
   * Pick JSON type and click create
   * Download file and upload it in PushPushGo Application (https://next.pushpushgo.com/projects/YourProjectID/settings/integration/fcm)

# Available methods to use with this SDK

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

    // Dynamic Groups (Segments) - assign subscriber to a group
    _pushpushgo.sendBeacon(
        Beacon(
            tags: {},
            tagsToDelete: {},
            customId: "my_id",
            selectors: {},
            assignToGroup: "premium-users"  // groupId
        )
    );

    // Dynamic Groups (Segments) - unassign subscriber from a group
    _pushpushgo.sendBeacon(
        Beacon(
            tags: {},
            tagsToDelete: {},
            customId: "my_id",
            selectors: {},
            unassignFromGroup: "trial-users"  // groupId
        )
    );
```
