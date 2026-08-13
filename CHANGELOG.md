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

## 1.4.0
### Features
- **Live Activities** - Real-time, backend-driven notifications on both platforms: Android 16 Live Updates (`ProgressStyle`) and iOS Live Activities on the Lock Screen and Dynamic Island, with the `FOOTBALL_MATCH_TRACKING` template. New `PPGLiveActivities` API: `initialize`, `isSupported`, `subscribe`, `unsubscribe`, `getSubscriberId`, `isActive`, `getActiveActivities`, `simulatePush`, plus a `statusStream` of lifecycle events and `setClickHandler` for taps. See [Live Activities Guide](LIVE_ACTIVITIES.md).
- **Android: No host-app code required** - The plugin intercepts Live Activity clicks on both cold start and `onNewIntent`, so unlike the native SDK integration nothing has to be added to `MainActivity`. Clicks arriving before the Flutter engine is ready are buffered and replayed. Deep link opening follows the existing `handleNotificationLink` flag.
- **iOS: Widget Extension integration** - Live Activities are rendered by a Widget Extension in the host app, using the Lock Screen and Dynamic Island views shipped by the native SDK. The plugin reuses the App Group and credentials already configured for push notifications, handles late-join bootstrap (subscribing to an already running activity), and prefetches team badges into the App Group. Taps arrive as SDK-owned `ppg-la://` URLs: the plugin consumes them to report the click to Dart (live notification id, deep link and action button index) and lets the native SDK forward the tap to its real destination — `http(s)` to the browser, a custom scheme back to the app so your own routing sees it, `ppg-la://close` to end the activity. URLs that are not `ppg-la://` are left untouched, so universal links and other deep-link plugins are unaffected. A complete working example was added in `example/ios/LiveActivityWidget`.

### Bug Fixes
- **Live Activity clicks are no longer lost on cold start** - A tap that launches the app is delivered by the native side as soon as the event channel opens, which is typically before the app registers its click handler (any widget touching `statusStream` opens the channel first). Those clicks were dropped. They are now buffered on the Dart side and replayed the moment `setClickHandler` is called, so handler registration order no longer matters. Status events published before the first `statusStream` listener attaches are replayed the same way.
- **iOS: correct click payload** - `liveNotificationId` was empty for every tap except `CLOSE` buttons, and `deepLink` carried the SDK-internal `ppg-la://click?…` wrapper instead of the real destination. Both are now read from the wrapper, and `actionIndex` reports the tapped action button (`0` / `1`) instead of always `-1`, matching Android.
- **iOS: no more spurious clicks** - Any URL opened while a Live Activity was on screen (universal links, OAuth callbacks, other plugins' deep links) was reported as a Live Activity tap. Only the SDK-owned `ppg-la://` scheme is inspected now.
- **Android: `isSupported()` no longer depends on SDK initialization** - It returned `false` on a supported Android 16+ device whenever `PushpushgoSdk.initialize()` had not completed, conflating "not initialized" with "unsupported device". It now falls back to the OS version check.
- **Android: invalid credentials no longer brick the app** - `PushPushGo.getInstance()` only validates while it builds its singleton, so credentials passed to a later `initialize()` were accepted unchecked and written to SharedPreferences. The next cold start rebuilt the SDK from those values, threw during validation inside `PushPushGoHelpers.initialize()`, and killed `Application.onCreate` — an unrecoverable crash loop until the user cleared app data. Credentials are now validated before they are stored (`initialize()` fails with `INVALID_CREDENTIALS` instead), and startup initialization no longer throws: unusable stored credentials are logged, dropped and the app starts normally.
- **CocoaPods: a missing `:git` source now fails instead of silently downgrading** - The podspec depended on `PPG_framework` / `PPG_InAppMessages` without a version floor. The 4.x native SDK is served from GitHub, but the CocoaPods trunk still carries `PPG_framework 3.0.3` (June 2025), so an app that forgot the `:git`/`:tag` line in its `Podfile` resolved that copy and quietly built against a native SDK four minor versions behind. Both dependencies now require `~> 4.3`, so CocoaPods reports `None of your spec sources contain a spec satisfying the dependency` instead. The README also spells out that both pods are required, even for push-only apps.

### Dependencies
- **iOS: native ios-sdk 4.2.0 → 4.4.0** (adds the `PPG_LiveActivities` product), linked through Swift Package Manager. On CocoaPods, apps opt in by adding `pod 'PPG_LiveActivities', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.4.0'` to their own `Podfile`; the plugin cannot declare the dependency itself, because the pod is not on the CocoaPods trunk and doing so would break `pod install` for apps that never use Live Activities. The plugin builds and runs with or without the module; without it, Live Activities report as unsupported.
- **Android: no change** - native android-sdk 3.2.0 already ships Live Activities.
