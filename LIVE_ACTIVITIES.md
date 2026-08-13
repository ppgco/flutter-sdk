# Live Activities

Live Activities are real-time, continuously updated notifications driven entirely
by the PushPushGo backend — an **Android 16 Live Update** notification, or an
**iOS Live Activity** on the Lock Screen and Dynamic Island.

Your app decides only *which* live notification to follow. Score, phase and
timing updates arrive as pushes and are rendered by the native SDK: no polling,
no foreground service, no app code driving the state.

The first available template is **`FOOTBALL_MATCH_TRACKING`**: a football match
tracker with team crests, live score, match phase, a running game clock and
action buttons.

## Requirements

| | Android | iOS |
|---|---|---|
| Minimum OS | Android 16 (API 36) | iOS 17.2 |
| Extra setup in your app | **none** | App Group + Widget Extension (see below) |
| Push transport | FCM data messages | ActivityKit push-to-start / push-to-update |
| Integration path | any | Swift Package Manager (see [CocoaPods](#cocoapods)) |

On unsupported devices every method is safe to call and does nothing — always
gate your UI on `isSupported()`.

Both platforms additionally require that push notifications already work
(see the main [README](README.md)) and that the device is a registered
subscriber.

## How it works

```
PPG dashboard / API          your backend                     mobile SDK
─────────────────────        ─────────────────────────        ───────────────────────────────
create & submit live    ──►  update score/phase        ──►    push (start/update/end)
notification campaign        (PUT /live-data),                 │
                             publish hot messages              ▼
                                                              renders & updates the
              ▲                                               notification / Live Activity,
              │                                               reports analytics
   device subscribes to the live notification  ◄──────────────┘
   (PPGLiveActivities.subscribe — done by the SDK)
```

If the device subscribes **after** the activity already started, the SDK fetches
the current state and renders it immediately, so a late joiner sees the running
match without waiting for the next update.

## Quick start

```dart
import 'package:pushpushgo_sdk/pushpushgo_sdk.dart';

// 1. The push SDK must be initialized first — Live Activities reuse its
//    credentials.
await pushpushgo.initialize(
  onNewSubscriptionHandler: (subscriberId) { /* ... */ },
);
await pushpushgo.registerForNotifications();

// 2. Initialize Live Activities.
//    appGroupId is required on iOS and ignored on Android; it defaults to the
//    App Group already configured for push notifications.
await PPGLiveActivities.instance.initialize(
  appGroupId: 'group.com.your.app',
);

// 3. Follow lifecycle events (optional).
PPGLiveActivities.instance.statusStream.listen((event) {
  print('Live Activity ${event.liveNotificationId}: ${event.status}');
});

// 4. Handle taps (optional).
PPGLiveActivities.instance.setClickHandler((click) {
  if (click.deepLink != null) {
    Navigator.of(context).pushNamed(click.deepLink!);
  }
});

// 5. Subscribe when the user chooses to follow a match.
if (await PPGLiveActivities.instance.isSupported()) {
  await PPGLiveActivities.instance.subscribe('<liveNotificationId>');
}

// Later:
await PPGLiveActivities.instance.unsubscribe('<liveNotificationId>');
```

## Android setup

**Nothing to do.** The SDK declares the required
`POST_PROMOTED_NOTIFICATIONS` permission, registers its dismiss receiver, and
the Flutter plugin already intercepts Live Activity taps in both cold and warm
starts — you do **not** need to touch `MainActivity`.

Standard `POST_NOTIFICATIONS` runtime permission still applies, exactly as for
regular pushes.

## iOS setup

Live Activities are rendered by a **Widget Extension** that runs in its own
process. Flutter cannot create that target for you, so it is a one-time manual
step in Xcode. A complete working example lives in
[`example/ios/LiveActivityWidget`](example/ios/LiveActivityWidget).

### 1. Enable an App Group

The widget cannot share memory with your app — team badges and hot-message state
travel through a shared App Group container.

1. Apple Developer portal → enable an App Group on **both** your app's bundle id
   and the widget extension bundle id (e.g. `group.com.your.app`).
2. Xcode → both targets → *Signing & Capabilities* → **+ Capability → App Groups**
   and tick the same group.

If you already configured an App Group for the Notification Service Extension,
reuse it — `PPGLiveActivities.initialize()` falls back to it automatically.

### 2. Update `Runner/Info.plist`

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.pushpushgo.liveactivities</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>ppg-la</string>
        </array>
    </dict>
</array>
```

`NSSupportsLiveActivities` enables the feature; the `ppg-la` scheme is how
`CLOSE` action buttons reach the SDK.

### 3. Add the Widget Extension

1. Xcode → *File → New → Target…* → **Widget Extension**. Name it
   `LiveActivityWidget`, untick *Include Configuration Intent*.
2. Set the new target's **iOS Deployment Target to 17.2**.
3. Add `PPG_LiveActivities` to the widget target:
   *File → Add Package Dependencies…* → `https://github.com/ppgco/ios-sdk` →
   select the **PPG_LiveActivities** product → add it to `LiveActivityWidget`.
4. Replace the generated source with:

```swift
import ActivityKit
import PPG_LiveActivities
import SwiftUI
import WidgetKit

@main
struct MatchLiveActivityWidget: Widget {
    init() {
        // The widget runs in its own process and inherits nothing from the
        // app — wire up the same App Group.
        LiveActivitiesSDK.configureWidgetExtension(
            appGroupId: "group.com.your.app"
        )
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            PPGMatchLockScreenView(context: context)
        } dynamicIsland: { context in
            PPGMatchDynamicIsland(context: context).body()
        }
    }
}
```

Both views ship with the SDK, so this file is the entire extension.

### CocoaPods

The plugin links `PPG_LiveActivities` automatically through **Swift Package
Manager**, which is the recommended path.

On CocoaPods you add it yourself. The plugin cannot declare it as a dependency
because `PPG_LiveActivities` is not published to the CocoaPods trunk — doing so
would break `pod install` for every app that does not use Live Activities. Add
it to your own `Podfile`, pinned to the same tag as the rest of the native SDK:

```ruby
target 'Runner' do
  # ...
  pod 'PPG_LiveActivities', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.4.0'
end

target 'LiveActivityWidget' do
  platform :ios, '17.2'
  pod 'PPG_LiveActivities', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.4.0'
end
```

Without it the plugin still builds and runs — Live Activities simply report as
unsupported.

> [!WARNING]
> Do not mix the two integration paths for the same module. CocoaPods links an
> app extension's pods into the host app as well, so adding a pod that the
> Swift Package already provides makes the app load two copies of every class
> (`Class … is implemented in both …` at launch). The bundled example uses
> Swift Package Manager for all three targets — app, NSE and widget — and keeps
> its `Podfile` free of PPG pods.

## Handling taps

```dart
PPGLiveActivities.instance.setClickHandler((click) {
  print(click.liveNotificationId);
  print(click.deepLink);    // link carried by the tapped element
  print(click.actionIndex); // -1 = body, 0/1 = action buttons
});
```

Both platforms report the same three fields, including which action button was
tapped. A tap that launched the app is replayed to the handler as soon as you
register it, so registering it late — even after `initialize()` — cannot lose a
cold-start click.

Who opens the link differs:

- **Android** follows the `handleNotificationLink` flag you passed to
  `PushpushgoSdk.initialize()`, exactly like a regular push click. Pass `false`
  to route every link yourself.
- **iOS** ignores that flag. Taps arrive as an SDK-owned `ppg-la://` URL, which
  the plugin consumes to count the tap and then forwards to the destination that
  URL carries: `http(s)` opens in the browser, and a custom scheme is re-opened
  so your app's own routing — or another deep-link plugin — receives it. Your
  handler is notified either way, with that destination as `deepLink`. URLs that
  are not `ppg-la://` are left completely untouched.

## API reference

| Method | Description |
|---|---|
| `initialize({appGroupId, isProduction, isDebug})` | Prepares Live Activities. Call after `PushpushgoSdk.initialize()` |
| `isSupported()` | `true` when the device can render Live Activities |
| `subscribe(liveNotificationId)` | Follows a live notification; returns the subscriber id on Android |
| `unsubscribe(liveNotificationId)` | Stops following it |
| `getSubscriberId(liveNotificationId)` | Stored subscriber id (Android only) |
| `isActive(liveNotificationId)` | Whether it is currently rendered |
| `getActiveActivities()` | All tracked activities as `List<LiveActivityInfo>`. Score / team / phase fields are Android only — iOS exposes identifiers only |
| `statusStream` | Lifecycle events (`LiveActivityStatusEvent`) |
| `setClickHandler(handler)` | Taps on the activity (`LiveActivityClick`) |
| `simulatePush(data)` | Feeds a push envelope into the pipeline — Android, testing only |
| `dispose()` | Releases the event subscription |

### Status events

| Status | Android | iOS |
|---|---|---|
| `registered` | ✓ | ✓ |
| `started` | only on late-join catch-up | ✓ |
| `tokenRegistered` | — | ✓ (diagnostic) |
| `ended` | — | ✓ |
| `unsubscribed` | ✓ | ✓ |
| `error` | ✓ | ✓ |

Android renders `start` / `update` / `end` pushes without surfacing individual
events — the notification is always the source of truth there.

## What the activity shows

Everything below comes from the campaign configuration; no app code is involved.

- **Teams and score** with alternating team crests.
- **Match phase and clock**, ticking every second, e.g. `1 : 0 · First half · 23:17'`.
  Phase labels come from the campaign's `statusLabels`.
- **Pre-match countdown** when the campaign defines one.
- **Progress bar** for halves and breaks, in the campaign's colors (Android).
- **Hot messages** — transient banners (e.g. `GOAL!`) that temporarily take over
  and then revert automatically.
- **Action buttons** of type `OPEN_APP`, `REDIRECT` and `CLOSE` (max 3 on Android).
- **End state** — the final score stays briefly, then the activity clears itself.

### Match phases

`PRE_MATCH`, `FIRST_HALF`, `FIRST_HALF_ADDED_TIME`, `HALF_TIME_BREAK`,
`SECOND_HALF`, `SECOND_HALF_ADDED_TIME`, `FULL_TIME`, `EXTRA_TIME_BREAK`,
`EXTRA_TIME_FIRST_HALF`, `EXTRA_TIME_FIRST_HALF_ADDED_TIME`,
`EXTRA_TIME_HALF_TIME_BREAK`, `EXTRA_TIME_SECOND_HALF`,
`EXTRA_TIME_SECOND_HALF_ADDED_TIME`, `PENALTY_SHOOTOUT`, `MATCH_ENDED`, `OTHER`.

## Analytics

Reported automatically — no integration needed:

| Event | When |
|---|---|
| `started` | The activity is rendered (including late-join catch-up) |
| `clicked` | Tap on the activity body |
| `clicked_1` / `clicked_2` | Tap on the first / second action button |
| `closed` | The user dismissed it (swipe or `CLOSE` button) |

## Testing without a backend

`simulatePush` drives the parse → render pipeline locally on Android:

```dart
await PPGLiveActivities.instance.simulatePush({
  'type': 'live_notification',
  'liveNotificationId': 'demo-match-1',
  'event': 'start', // start | update | end
  'template': 'FOOTBALL_MATCH_TRACKING',
  'configuration': configurationJson, // static config; required on start
  'liveData': liveDataJson,           // score / status / statusChangedAt
  // 'hotMessage': hotMessageJson,    // optional transient message
});
```

Complete envelope examples live in the native Android SDK sample
(`sample/src/main/java/com/pushpushgo/sample/activity/LiveActivityDemoActivity.kt`).

## Troubleshooting

**Nothing appears on Android** — confirm the device runs Android 16 (API 36);
`isSupported()` returns `false` below that. Check that `POST_NOTIFICATIONS` is
granted and that the device is a registered push subscriber.

**Nothing appears on iOS** — check in order:
1. `isSupported()` — covers both the OS version and the user's Live Activities setting.
2. The Widget Extension is embedded in the app and includes `PPG_LiveActivities`.
3. `NSSupportsLiveActivities` is `YES` in `Runner/Info.plist`.
4. The same App Group is enabled on the app **and** the widget, and matches the
   `appGroupId` you passed to `initialize()`.
5. Run with `isDebug: true` and read the native logs.

**Badges are missing on iOS** — almost always an App Group mismatch between
`PPGLiveActivities.initialize()` and `configureWidgetExtension()`.
