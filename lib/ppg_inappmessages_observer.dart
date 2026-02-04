import 'package:flutter/widgets.dart';
import 'package:pushpushgo_sdk/ppg_inappmessages.dart';

/// A NavigatorObserver that automatically notifies [PPGInAppMessages]
/// about route changes.
///
/// Add this observer to your [MaterialApp] or [Navigator] to automatically
/// track navigation and display eligible in-app messages.
///
/// Example with MaterialApp:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [
///     InAppMessagesNavigatorObserver(),
///   ],
///   // ... rest of your app
/// )
/// ```
///
/// Example with Navigator:
/// ```dart
/// Navigator(
///   observers: [
///     InAppMessagesNavigatorObserver(),
///   ],
///   // ... rest of your navigator
/// )
/// ```
///
/// By default, the observer uses the route's settings name as the route
/// identifier. You can customize this by providing a [routeNameExtractor].
///
/// Example with custom route name extraction:
/// ```dart
/// InAppMessagesNavigatorObserver(
///   routeNameExtractor: (route) {
///     // Custom logic to extract route name
///     if (route?.settings.name?.contains('product') == true) {
///       return 'product_detail';
///     }
///     return route?.settings.name;
///   },
/// )
/// ```
class InAppMessagesNavigatorObserver extends NavigatorObserver {
  /// Creates an observer that notifies [PPGInAppMessages] about route changes.
  ///
  /// [routeNameExtractor] - Optional function to extract custom route names
  /// from routes. By default uses `route.settings.name`.
  InAppMessagesNavigatorObserver({
    this.routeNameExtractor,
  });

  /// Optional function to extract route name from a Route.
  /// If not provided, uses route.settings.name.
  final String? Function(Route<dynamic>? route)? routeNameExtractor;

  /// Extract route name using custom extractor or default logic
  String? _extractRouteName(Route<dynamic>? route) {
    if (routeNameExtractor != null) {
      return routeNameExtractor!(route);
    }
    return route?.settings.name;
  }

  /// Notify SDK about route change
  void _notifyRouteChange(Route<dynamic>? route) {
    final routeName = _extractRouteName(route);
    if (routeName != null && routeName.isNotEmpty) {
      if (PPGInAppMessages.instance.isInitialized) {
        // SDK is ready - send route change immediately
        PPGInAppMessages.instance.onRouteChanged(routeName);
      } else {
        // SDK not yet initialized - buffer the route for later
        PPGInAppMessages.instance.bufferRoute(routeName);
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _notifyRouteChange(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // When popping, the previous route becomes active
    _notifyRouteChange(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _notifyRouteChange(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    // When removing, the previous route becomes active
    _notifyRouteChange(previousRoute);
  }
}
