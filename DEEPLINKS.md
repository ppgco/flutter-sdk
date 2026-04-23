# Deep links, Universal Links and AASA in PushPushGo Flutter SDK

This document describes how `pushpushgo_sdk` routes URLs delivered inside
push notifications on both platforms, and what you have to configure at the
Dart, Android-native and iOS-native layers.

The plugin is a thin bridge on top of:

- **Android** — `com.pushpushgo:sdk` (see `android-sdk` repository, file
  `DEEPLINKS.md` for the underlying behavior).
- **iOS** — `PPG_framework` (see `ios-sdk` repository, file `DEEPLINKS.md`
  for the underlying behavior, AASA setup and `UL` flag).

Read those two documents first if you need the full native payload
reference — this guide only describes the parts that are specific to the
Flutter plugin.

---

## Table of contents

- [Overview](#overview)
- [Dart API](#dart-api)
- [`handleNotificationLink: true` — native SDK opens the URL](#handlenotificationlink-true--native-sdk-opens-the-url)
- [`handleNotificationLink: false` — Dart handles everything](#handlenotificationlink-false--dart-handles-everything)
- [`onNotificationClickedHandler` payload shape](#onnotificationclickedhandler-payload-shape)
- [Android-side setup](#android-side-setup)
- [iOS-side setup](#ios-side-setup)
  - [Custom URL schemes](#custom-url-schemes)
  - [Universal Links and AASA](#universal-links-and-aasa)
- [Integrating with popular routers](#integrating-with-popular-routers)
- [Troubleshooting](#troubleshooting)

---

## Overview

When the user taps a PushPushGo notification:

1. The **native** SDK tracks the click and sends analytics (`clicked` event
   with optional button index).
2. The plugin forwards the notification payload to Dart via the
   `onNotificationClicked` method call (if you registered a handler).
3. Depending on the `handleNotificationLink` initializer option, the native
   SDK **either** opens the URL itself **or** leaves that responsibility to
   Dart.

Both behaviors are controlled from a single boolean argument to
`PushpushgoSdk.initialize(...)`.

---

## Dart API

```dart
final sdk = PushpushgoSdk({
  'apiToken':  'YOUR_API_TOKEN',
  'projectId': 'YOUR_PROJECT_ID',
  'appGroupId': 'group.com.example.myapp', // iOS only
});

await sdk.initialize(
  onNewSubscriptionHandler: (subscriberId) {
    debugPrint('Subscribed: $subscriberId');
  },
  onNotificationClickedHandler: (data) {
    // Called for every notification tap, regardless of handleNotificationLink
    debugPrint('Notification tapped: $data');
    _handleDeepLink(data);
  },
  handleNotificationLink: true, // default
);
```

Signatures:

```dart
typedef NotificationClickHandler = Function(Map<String, dynamic> notificationData);

Future<void> initialize({
  required SubscriptionHandler onNewSubscriptionHandler,
  NotificationClickHandler? onNotificationClickedHandler,
  bool handleNotificationLink = true,
  bool isProduction = true,
  bool isDebug = false,
});
```

---

## `handleNotificationLink: true` — native SDK opens the URL

This is the **default** and the simplest option. The native SDK handles URL
opening exactly as it does in a pure native app:

- **Android:** builds an `Intent.parseUri(url, 0)` and calls `startActivity`
  with `FLAG_ACTIVITY_NEW_TASK`. This resolves `https://`, App Links, and
  any custom scheme that your app declares via `<intent-filter>`.
- **iOS:** calls `PPG.getUrlFromNotificationResponse(...)` and then either
  `UIApplication.shared.open(url)` or `NSUserActivity` (Universal Link),
  based on the `UL` flag in the payload.

In addition, `onNotificationClickedHandler` is still called with the full
notification payload, so you can log analytics, refresh a list, etc. — but
you do **not** need to do the actual navigation from Dart.

---

## `handleNotificationLink: false` — Dart handles everything

Use this when you want your Flutter app (typically a router such as
`go_router`, `auto_route`, `beamer`, ...) to own navigation end-to-end.

Behavior per platform:

- **Android** — the plugin overrides the SDK's `notificationHandler` so that
  it **does not** call `startActivity`. The click is still tracked, the
  intent still reaches your launcher activity, and `onNotificationClicked`
  still fires in Dart.
- **iOS** — the plugin skips the `open(url)` / `NSUserActivity` branch in
  its own `UNUserNotificationCenterDelegate` implementation. The click is
  still tracked and forwarded to Dart.

Example:

```dart
await sdk.initialize(
  onNewSubscriptionHandler: (subscriberId) {},
  handleNotificationLink: false,
  onNotificationClickedHandler: (data) {
    final url = (data['redirectLink'] ?? data['link'] ?? _pickIosUrl(data)) as String?;
    if (url != null) GoRouter.of(context).go(_mapUrlToRoute(url));
  },
);
```

> When `handleNotificationLink: false`, the plugin becomes the single source
> of truth for navigation. If you forget to implement
> `onNotificationClickedHandler`, nothing will happen on tap.

---

## `onNotificationClickedHandler` payload shape

The map you receive reflects the **native payload** (passed through, with
only basic serializable types kept) plus a couple of plugin-added helpers.

### Android

On Android, the plugin reads the click Intent's extras and forwards only
`String`, `Number` or `Boolean` values. Expect keys such as:

| Key             | Meaning                                                       |
|-----------------|---------------------------------------------------------------|
| `project`       | PushPushGo project id                                         |
| `subscriber`    | Subscriber id                                                 |
| `campaign`      | Campaign id                                                   |
| `notification`  | Full raw notification JSON (stringified)                      |
| `actions`       | Raw actions JSON (stringified), present if payload had actions|
| `link`          | URL as extracted by the native SDK (`LINK_EXTRA`)             |
| `redirectLink`  | URL from the top-level `redirectLink` field                   |
| `button`        | Button index — `0` for body tap, `1..N` for action buttons    |
| `notification_id` | Local id of the system notification                         |
| `image`, `icon` | Media URLs if provided in the payload                         |

### iOS

On iOS, the plugin copies every key from
`response.notification.request.content.userInfo`, plus:

| Key                | Meaning                                          |
|--------------------|--------------------------------------------------|
| `actionIdentifier` | `"UNNotificationDefaultActionIdentifier"`, `"button_1"` or `"button_2"` |
| `title`            | Notification title                               |
| `body`             | Notification body                                |
| `aps`              | Original `aps` dictionary (contains `url-args`)  |
| `actions`          | Array of action dictionaries with per-button `url` and optional `UL` |
| `UL`               | Root-level Universal Link flag                   |
| `campaign`         | Campaign id                                      |

Handy helpers when you consume the payload in Dart:

```dart
String? extractUrl(Map<String, dynamic> data) {
  // Android-style fields
  final link = (data['redirectLink'] as String?)?.trim();
  if (link != null && link.isNotEmpty) return link;
  final genericLink = (data['link'] as String?)?.trim();
  if (genericLink != null && genericLink.isNotEmpty) return genericLink;

  // iOS-style fields
  final aps = data['aps'];
  if (aps is Map) {
    final urlArgs = aps['url-args'];
    if (urlArgs is List && urlArgs.isNotEmpty && urlArgs.first is String) {
      return urlArgs.first as String;
    }
  }
  return null;
}

bool tappedActionButton(Map<String, dynamic> data) {
  // iOS
  final id = data['actionIdentifier'] as String?;
  if (id != null && (id == 'button_1' || id == 'button_2')) return true;
  // Android
  final button = data['button'];
  return button is int && button > 0;
}
```

---

## Android-side setup

Same as for the native Android SDK (see `android-sdk/DEEPLINKS.md`):

1. The launcher activity **must** be `android:launchMode="singleTop"`. The
   plugin registers `addOnNewIntentListener` for you, but Android only
   delivers the new intent to an existing activity when `singleTop` (or
   `singleTask`) is set.

   ```xml
   <activity
       android:name=".MainActivity"
       android:launchMode="singleTop"
       android:exported="true">
       <intent-filter>
           <action android:name="android.intent.action.MAIN" />
           <category android:name="android.intent.category.LAUNCHER" />
       </intent-filter>
   </activity>
   ```

2. For custom-scheme deep links (e.g. `myapp://...`) add a standard
   `<intent-filter>` on your Flutter activity:

   ```xml
   <intent-filter>
       <action android:name="android.intent.action.VIEW" />
       <category android:name="android.intent.category.DEFAULT" />
       <category android:name="android.intent.category.BROWSABLE" />
       <data android:scheme="myapp" />
   </intent-filter>
   ```

3. For `https://` App Links, declare the domain in the intent-filter with
   `android:autoVerify="true"` and host a `/.well-known/assetlinks.json`.

The plugin does **not** need any additional Android configuration.

> Note: You do **not** need to call `handleBackgroundNotificationClick`
> manually from Dart or Kotlin — the Flutter plugin already does that
> internally (`PushpushgoSdkPlugin.handleIntent`).

---

## iOS-side setup

The plugin's iOS side wraps `PPG_framework`. All configuration described in
`ios-sdk/DEEPLINKS.md` applies verbatim.

### Custom URL schemes

1. Register the scheme in the app's `Info.plist`:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array><string>myapp</string></array>
     </dict>
   </array>
   ```

2. Whitelist it in `PPG_framework` via the same `Info.plist`:

   ```xml
   <key>PPGSupportedURLSchemes</key>
   <array>
       <string>http</string>
       <string>https</string>
       <string>myapp</string>
   </array>
   ```

   Omitting the key falls back to `["http", "https", "app"]`. Setting it
   **replaces** the defaults, so always re-add `http`/`https` if you want
   them.

3. If `handleNotificationLink: true` (default), the OS will deliver the URL
   through standard iOS hooks — on Flutter this typically surfaces as
   `AppLinks` / `uni_links` / your preferred deep-link package.

   If `handleNotificationLink: false`, read the URL from the
   `onNotificationClickedHandler` payload instead (see
   [iOS payload shape](#ios)).

### Universal Links and AASA

To route an `https://example.com/...` URL directly into the app:

1. Host the AASA file at
   `https://example.com/.well-known/apple-app-site-association` — plain
   JSON, no redirects. Minimal example:

   ```json
   {
     "applinks": {
       "details": [
         {
           "appIDs": ["ABCDE12345.com.example.myapp"],
           "components": [{ "/": "/product/*" }]
         }
       ]
     }
   }
   ```

2. Add the `Associated Domains` capability in Xcode (open
   `ios/Runner.xcworkspace`) and declare `applinks:example.com`. Make sure
   the same capability is enabled on the App ID in the Apple Developer
   portal.

3. `UL: true` parameter is set in the payload if you have configured Universal Links in the PushPushGo dashboard.

4. When `handleNotificationLink: true`, `PPG_framework` forwards the URL as
   an `NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)`. iOS in
   turn hands it to your AppDelegate:

   ```swift
   // ios/Runner/AppDelegate.swift
   override func application(
       _ application: UIApplication,
       continue userActivity: NSUserActivity,
       restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
   ) -> Bool {
       return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
   }
   ```

   From there, pick your favorite Flutter deep-link package (`app_links`,
   `uni_links`, ...) to surface the URL in Dart, or bridge through a
   dedicated `MethodChannel`.

   If `handleNotificationLink: false`, the SDK skips the NSUserActivity
   path — read the URL from `onNotificationClickedHandler` and navigate
   directly with your Dart router.

---

## Integrating with popular routers

**`go_router`** (with `handleNotificationLink: false`):

```dart
await sdk.initialize(
  handleNotificationLink: false,
  onNewSubscriptionHandler: (_) {},
  onNotificationClickedHandler: (data) {
    final url = extractUrl(data);
    if (url != null) {
      final uri = Uri.parse(url);
      _router.go('${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}');
    }
  },
);
```

**`app_links` / `uni_links`** (with `handleNotificationLink: true`):

- Keep the default behavior — the OS delivers the URL to
  `application(_:continue:restorationHandler:)` on iOS or launches the
  intent filter on Android.
- `app_links` (or `uni_links`) already listens for those events and exposes
  them as a Dart stream. Nothing PushPushGo-specific is needed.

---

## Troubleshooting

- **`onNotificationClickedHandler` never fires.**
  - Android: check that your launcher activity is `singleTop`, the plugin
    is attached to the Flutter engine, and the notification payload
    actually contains the PushPushGo extras (`project`, `campaign`).
  - iOS: ensure `PPG_framework` is the `UNUserNotificationCenter.delegate`
    — this is configured automatically when you `initialize` the plugin.

- **URL is opened twice** (once natively, once from Dart).
  You probably forwarded the URL from `onNotificationClickedHandler` while
  `handleNotificationLink: true`. Either navigate from Dart **or** let the
  native SDK do it, not both.

- **Custom scheme works on Android but not on iOS.**
  Missing `PPGSupportedURLSchemes` entry — the native iOS SDK silently
  drops URLs whose scheme is not whitelisted.

- **Universal Link opens Safari instead of the app.**
  Check AASA reachability, Associated Domains capability, and the `UL`
  flag in the payload. See `ios-sdk/DEEPLINKS.md` for the full checklist.

- **Initial notification (cold start) is missed.**
  The plugin caches the pending notification intent if it arrives before
  `initialize(...)` runs and replays it once initialization completes
  (`pendingNotificationData` / `trySendPendingNotification` on Android,
  standard `UNUserNotificationCenter` behavior on iOS). Make sure you
  register `onNotificationClickedHandler` in the same `initialize` call.
