# PushPushGo In-App Messages - Flutter SDK

This document describes how to integrate In-App Messages functionality in your Flutter application.

## Requirements

- Flutter SDK >= 2.19.6
- iOS 14.0+
- Android minSdk 26+

## Installation

The In-App Messages SDK is included in the main `pushpushgo_sdk` package. No additional dependencies are required.

## Setup

### 1. Initialize the SDK

Initialize the In-App Messages SDK after your main PushPushGo SDK initialization:

```dart
import 'package:pushpushgo_sdk/pushpushgo_sdk.dart';

// In your app initialization (e.g., initState or main)
await PPGInAppMessages.instance.initialize(
  apiKey: "YOUR_API_KEY",
  projectId: "YOUR_PROJECT_ID",
  isProduction: true,  // false for PPG staging/testing environment
  isDebug: false,      // true to enable debug logs
);
```

### 2. Add NavigatorObserver

To automatically track screen/route changes and display In-App Messages based on routes, add the `InAppMessagesNavigatorObserver` to your `MaterialApp`:

```dart
import 'package:pushpushgo_sdk/ppg_inappmessages_observer.dart';

MaterialApp(
  navigatorObservers: [
    InAppMessagesNavigatorObserver(),
  ],
  routes: {
    '/': (context) => HomeScreen(),
    '/details': (context) => DetailScreen(),
  },
  // ... other configuration
)
```

**Important:** When using `Navigator.push()` with `MaterialPageRoute`, make sure to include `RouteSettings` with a name:

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    settings: const RouteSettings(name: '/details'),  // Required for route tracking
    builder: (context) => const DetailScreen(),
  ),
);
```

## Router Integration Examples

### Standard Navigator

When using Flutter's built-in Navigator with named routes:

```dart
// In MaterialApp
MaterialApp(
  navigatorObservers: [
    InAppMessagesNavigatorObserver(),
  ],
  routes: {
    '/': (context) => HomeScreen(),
    '/details': (context) => DetailScreen(),
    '/settings': (context) => SettingsScreen(),
  },
)

// Navigation with named routes (recommended)
Navigator.pushNamed(context, '/details');

// Navigation with MaterialPageRoute - must include RouteSettings!
Navigator.of(context).push(
  MaterialPageRoute(
    settings: const RouteSettings(name: '/details'),
    builder: (context) => const DetailScreen(),
  ),
);
```

### go_router

```dart
import 'package:go_router/go_router.dart';
import 'package:pushpushgo_sdk/pushpushgo_sdk.dart';

final goRouter = GoRouter(
  observers: [
    // Use custom route extractor for go_router
    InAppMessagesNavigatorObserver(
      routeNameExtractor: (route) {
        // go_router stores the path in route.settings.name
        return route?.settings.name ?? '/';
      },
    ),
  ],
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/details/:id',
      name: 'details',
      builder: (context, state) => DetailScreen(id: state.pathParameters['id']!),
    ),
  ],
);

// In your app
MaterialApp.router(
  routerConfig: goRouter,
)
```

**Alternative: Manual route tracking with go_router**

If the observer doesn't work well with your go_router setup, use manual tracking:

```dart
final goRouter = GoRouter(
  redirect: (context, state) {
    // Notify SDK on every navigation
    PPGInAppMessages.instance.onRouteChanged(state.matchedLocation);
    return null; // No redirect
  },
  routes: [...],
);
```

### auto_route

```dart
import 'package:auto_route/auto_route.dart';
import 'package:pushpushgo_sdk/pushpushgo_sdk.dart';

@AutoRouterConfig()
class AppRouter extends $AppRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: HomeRoute.page, path: '/', initial: true),
    AutoRoute(page: DetailsRoute.page, path: '/details/:id'),
    AutoRoute(page: SettingsRoute.page, path: '/settings'),
  ];
}

// In your app
final _appRouter = AppRouter();

MaterialApp.router(
  routerDelegate: _appRouter.delegate(
    navigatorObservers: () => [
      InAppMessagesNavigatorObserver(
        routeNameExtractor: (route) {
          // auto_route uses route.settings.name with the route path
          return route?.settings.name ?? '/';
        },
      ),
    ],
  ),
  routeInformationParser: _appRouter.defaultRouteParser(),
)
```

**Alternative: Using AutoRouteObserver**

```dart
class PPGRouteObserver extends AutoRouteObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    final routeName = route.settings.name;
    if (routeName != null) {
      PPGInAppMessages.instance.onRouteChanged(routeName);
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    final routeName = previousRoute?.settings.name;
    if (routeName != null) {
      PPGInAppMessages.instance.onRouteChanged(routeName);
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final routeName = newRoute?.settings.name;
    if (routeName != null) {
      PPGInAppMessages.instance.onRouteChanged(routeName);
    }
  }
}

// Use in router
MaterialApp.router(
  routerDelegate: _appRouter.delegate(
    navigatorObservers: () => [PPGRouteObserver()],
  ),
  routeInformationParser: _appRouter.defaultRouteParser(),
)
```

### Beamer

```dart
import 'package:beamer/beamer.dart';
import 'package:pushpushgo_sdk/pushpushgo_sdk.dart';

class MyBeamerDelegate extends BeamerDelegate {
  MyBeamerDelegate() : super(
    locationBuilder: RoutesLocationBuilder(
      routes: {
        '/': (context, state, data) => const HomeScreen(),
        '/details/:id': (context, state, data) => DetailScreen(
          id: state.pathParameters['id']!,
        ),
      },
    ),
  );

  @override
  void update({bool rebuild = true}) {
    super.update(rebuild: rebuild);
    // Notify SDK on route changes
    PPGInAppMessages.instance.onRouteChanged(
      configuration.location ?? '/',
    );
  }
}

final routerDelegate = MyBeamerDelegate();

MaterialApp.router(
  routerDelegate: routerDelegate,
  routeInformationParser: BeamerParser(),
)
```

### Custom Route Name Extraction

For any routing solution, you can provide a custom route name extractor:

```dart
InAppMessagesNavigatorObserver(
  routeNameExtractor: (route) {
    // Custom logic to extract route name
    // Examples:
    
    // 1. Use route settings name
    if (route?.settings.name != null) {
      return route!.settings.name!;
    }
    
    // 2. Extract from route type
    if (route is MaterialPageRoute) {
      // Custom extraction logic
    }
    
    // 3. Use route arguments
    final args = route?.settings.arguments;
    if (args is Map && args.containsKey('routeName')) {
      return args['routeName'] as String;
    }
    
    return '/unknown';
  },
)
```

## Manual Route Tracking

If you're not using `NavigatorObserver`, you can manually notify the SDK about route changes:

```dart
PPGInAppMessages.instance.onRouteChanged('/home');
```

## Custom Triggers

You can trigger In-App Messages based on custom events:

```dart
PPGInAppMessages.instance.showMessagesOnTrigger(
  key: "action",
  value: "purchase_completed",
);
```

## Custom Code Actions

Handle custom code actions from In-App Message buttons:

```dart
PPGInAppMessages.instance.setCustomCodeActionHandler((code) {
  print("Custom code received: $code");
  
  // Handle custom actions
  switch (code) {
    case "open_settings":
      Navigator.pushNamed(context, '/settings');
      break;
    case "apply_discount":
      applyDiscount();
      break;
  }
});
```

## Clear Message Cache

To force fresh data fetch:

```dart
await PPGInAppMessages.instance.clearMessageCache();
```

## iOS Specific Setup

### CocoaPods

The `PPG_InAppMessages` pod is automatically included when you add `pushpushgo_sdk` to your Flutter project.

If using manual CocoaPods integration, add to your `Podfile`:

```ruby
pod 'PPG_InAppMessages', :git => 'https://github.com/ppgco/ios-sdk.git', :tag => '4.1.2'
```

### Swift Package Manager

If using SPM, the `PPG_InAppMessages` library is included in the ios-sdk package.

## Android Specific Setup

### 1. Add meta-data to AndroidManifest.xml

Add the following configuration inside your `<application>` tag in `android/app/src/main/AndroidManifest.xml`:

```xml
<application ...>
    <!-- In-App Messages Configuration -->
    <meta-data 
        android:name="com.pushpushgo.inapp.projectId" 
        android:value="YOUR_PROJECT_ID" />
    <meta-data 
        android:name="com.pushpushgo.inapp.apiKey" 
        android:value="YOUR_API_KEY" />
    <meta-data 
        android:name="com.pushpushgo.inapp.isDebug" 
        android:value="false" />
    <!-- Optional: Use staging API -->
    <!-- <meta-data 
        android:name="com.pushpushgo.inapp.baseUrl" 
        android:value="https://api.master1.qappg.co/" /> -->
    
    <!-- ... rest of your application -->
</application>
```

| Meta-data key | Description |
|---------------|-------------|
| `com.pushpushgo.inapp.projectId` | Your PushPushGo project ID |
| `com.pushpushgo.inapp.apiKey` | Your PushPushGo API key |
| `com.pushpushgo.inapp.isDebug` | Enable debug logs (`true`/`false`) |
| `com.pushpushgo.inapp.baseUrl` | Optional: Custom API base URL (for staging) |

### 2. Minimum SDK Version

Make sure your `minSdk` is at least 26 in your app's `build.gradle`:

```gradle
android {
    defaultConfig {
        minSdk 26
    }
}
```

### 3. Dependencies

The In-App Messages SDK is automatically included. Make sure you have the following in your root `build.gradle`:

```gradle
allprojects {
    repositories {
        maven { url 'https://jitpack.io' }
    }
}
```

## Example

See the [example app](example/) for a complete integration example.

```dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:pushpushgo_sdk/pushpushgo_sdk.dart';
import 'package:pushpushgo_sdk/ppg_inappmessages_observer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    // Initialize In-App Messages SDK
    await PPGInAppMessages.instance.initialize(
      apiKey: "YOUR_API_KEY",
      projectId: "YOUR_PROJECT_ID",
      isDebug: true,
    );

    // Set up custom code action handler
    PPGInAppMessages.instance.setCustomCodeActionHandler((code) {
      log("Custom code action received: $code");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [
        InAppMessagesNavigatorObserver(),
      ],
      home: const HomeScreen(),
    );
  }
}
```

## Troubleshooting

### In-App Message not showing

1. **Check initialization**: Ensure `PPGInAppMessages.instance.initialize()` is called before any route changes
2. **Check route names**: Make sure `RouteSettings(name: '/your-route')` is set when pushing routes
3. **Enable debug logs**: Set `isDebug: true` in initialization to see detailed logs
4. **Check message configuration**: Verify the In-App Message is enabled and configured for the correct route/trigger in PushPushGo dashboard

### Route changes not detected

Make sure:
1. `InAppMessagesNavigatorObserver` is added to `MaterialApp.navigatorObservers`
2. Routes have names set via `RouteSettings`
3. SDK is initialized before first navigation

## API Reference

### PPGInAppMessages

| Method | Description |
|--------|-------------|
| `initialize(apiKey, projectId, isProduction, isDebug)` | Initialize the SDK |
| `onRouteChanged(route)` | Notify about route/screen change |
| `showMessagesOnTrigger(key, value)` | Trigger messages by custom event |
| `setCustomCodeActionHandler(handler)` | Handle custom code actions |
| `clearMessageCache()` | Clear cached messages |
| `isInitialized` | Check if SDK is initialized |

### InAppMessagesNavigatorObserver

| Parameter | Description |
|-----------|-------------|
| `routeNameExtractor` | Optional custom function to extract route names |
