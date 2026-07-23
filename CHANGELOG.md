## 0.0.1
WIP Release - iOS and Android support based on our native SDK

## 0.0.2
Android switch to version 2.0.1 to fix beacon tags format
Fix beacons (tags, selectors) passing to server

## 0.0.3
Add readme md with instructions
Cleanup example code

## 0.0.4
Change link to repository in to pubspec

## 0.0.5
Change description in pubspec

## 0.0.6
iOS now support strategy and ttl in tags
ios-sdk set to 1.2.0

## 0.0.7
Update android-sdk to 2.0.2 version
Fix issue with "crashing app" on initial run

## 0.0.8
VERSION REDACTED

## 0.0.9
Update android-sdk to 2.0.6 version
Fix issue with "crashing app" on background run

## 1.0.1
Update ios-sdk to 2.0.1 version
Fix issue with delivered events on ios apps
Breaking changes: requires AppGroups capability on ios App target

## 1.0.2
Fix ios sdk versioning

## 1.0.3
Add PPG.registerNotificationsDeliveredFromUserInfo() into PushPushGoSdkPlugin.swift

## 1.0.4
Pre release test version for fixing delivery events on app killed

## 1.1.0
Fix async completion handler issue in PPG.registerNotificationsDeliveredFromUserInfo()
Fix delivered event issue

## 1.2.0
Add support for Swift Package Manager (SPM)
Add support for push notification buttons
Fix error for channeling methods not from main thread

## 1.2.1
Fix support of cocoapods (change path to plugin, change podfile version)

## 1.2.2
Cocoapods supported for ios from version 3.0.3
Add Universal Links support

## 1.2.3
Update android and firebase libraries
Fix sdk namespace problem

## 1.2.4-beta.1
Add onNotificationClicked event handler
Example Android app migration to new version 

## 1.2.4-beta.2
Add handleNotificationLink option to control automatic URL opening on notification click
Update Android SDK to 3.0.2

## 1.3.0
### New Features
- **In-App Messages** - Display targeted messages within your app based on routes or custom triggers
  - Route-based message triggering with `InAppMessagesNavigatorObserver`
  - Custom event triggers via `showMessagesOnTrigger()`
  - Custom code action handlers for button clicks
  - Support for multiple routers (Navigator, go_router, auto_route, Beamer)
  - Separate documentation in `IN_APP_MESSAGES.md`
- **Notification Click Handler** - Handle push notification clicks directly in Flutter
  - New `onNotificationClickedHandler` callback in `initialize()` method
  - New `handleNotificationLink` option to control automatic URL opening
  - Access to notification payload (link, campaign, project)

### Improvements
- iOS: Fix cold start notification handling with `pendingNotificationData` mechanism
- Updated documentation with In-App Messages guide and notification handler examples
- Update PPG Android SDK to 3.0.2
- Update PPG In-App Messages SDK to 3.0.2


## 1.3.1
### Bug Fixes
- **Android: Fix cold-start crash** - Added `PushPushGoContentProvider` for early SDK initialization
  - Prevents `PushPushException: You have to initialize PushPushGo with context first!` on first app install
  - SDK now initializes via ContentProvider before FCM can trigger `onNewToken()`
  - Supports credentials from AndroidManifest meta-data or SharedPreferences

## 1.3.2
### New Features
- **Dynamic Groups (Segments)** - Assign/unassign subscribers to dynamic groups via Beacon
  - New `assignToGroup` property in Beacon for assigning subscribers to dynamic groups
  - New `unassignFromGroup` property in Beacon for unassigning subscribers from dynamic groups
  - Requires ios-sdk 4.2.0+ and android-sdk 3.1.0+

## 1.3.3
### Bug Fixes
- **Android: Fix release build crash (R8/ProGuard)** - Added consumer ProGuard rules for Huawei HMS classes
  - Fixes `Missing class com.huawei.agconnect.AGConnectOptions` and related R8 errors during release build
  - Apps using only GMS (without HMS) no longer fail on `minifyReleaseWithR8`

## 1.3.4
### Bug Fixes
- **Android: Fix in-app messages not displaying** - Fixed `currentActivity` being null in `InAppUIController` when SDK is initialized from Dart (after the first `Activity.onResume`). The SDK registers `ActivityLifecycleCallbacks` too late to capture the initial resume, so the current activity is now injected directly via reflection at initialization time and before each trigger/route change.
- **Android: Fix Kotlin 2.x compilation error** - Fixed `onSuccess` signature in `PushpushgoSdkPlugin` to match updated interface definition

## 1.3.5
### Bug Fixes
- **Android: Fix missing click events when `handleNotificationLink: false`** - Notification click tracking (`handleBackgroundNotificationClick`) was incorrectly gated by the `handleNotificationLink` flag in `PushPushGoHelpers.onCreate`/`onNewIntent`, so apps that opted out of native link opening to handle deeplinks themselves stopped reporting click events to PPG entirely. Click tracking is now always invoked; the `handleNotificationLink` flag continues to control only whether the native SDK opens the URL (via the no-op `notificationHandler` override).
- **Android: Apply `notificationHandler` override in early init paths** - The no-op handler is now also applied from `PushPushGoContentProvider` and `PushPushGoHelpers.initialize` based on the persisted flag, so link opening stays suppressed even on cold-starts triggered by a notification click before the Flutter side initializes.

## 1.3.6
### Bug Fixes
- **Android: Fix cold-start crash on FCM callbacks (`PushPushException: You have to initialize PushPushGo with context first!`)** - Bumped native android-sdk from 3.1.0 to 3.2.0. In 3.1.0 the internal `logDebug()` called `PushPushGo.getInstance()` without an initialization guard, so any FCM callback (`onNewToken`/`onMessageReceived`) arriving before SDK initialization crashed the app before the `isInitialized()` check could run - typically on the first launch after a fresh install, when SharedPreferences are still empty and AndroidManifest meta-data credentials are not configured. FCM callbacks arriving before initialization are now safely ignored. Configuring the AndroidManifest meta-data is still recommended so that pushes received on cold start are actually displayed.


## 1.3.7
### Bug Fixes
- **iOS: Fix notification click not delivered on cold start** - The `UNUserNotificationCenter` delegate was registered only during `initialize()` (called from Dart after the Flutter engine starts), which is after the app finishes launching - too late for iOS to reliably deliver the tap that launched the app. As a result, `onNotificationClickedHandler` (and native link opening) did not fire when the app was fully closed. The delegate is now registered at plugin registration time (during `didFinishLaunching`), and a tap that arrives before `initialize()` completes is cached natively and replayed right after initialization.
