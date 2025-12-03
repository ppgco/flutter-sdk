import 'dart:async';
import 'dart:developer';

import 'package:pushpushgo_sdk/ppg_inappmessages_channel.dart';

/// Handler for custom code actions from in-app message buttons
typedef CustomCodeActionHandler = void Function(String customCode);

/// PushPushGo In-App Messages SDK for Flutter
/// 
/// Use this class to display in-app messages in your Flutter app.
/// 
/// Example:
/// ```dart
/// // Initialize in your app
/// await PPGInAppMessages.instance.initialize(
///   apiKey: 'your-api-key',
///   projectId: 'your-project-id',
/// );
/// 
/// // Notify route changes
/// PPGInAppMessages.instance.onRouteChanged('home');
/// 
/// // Show messages on custom triggers
/// PPGInAppMessages.instance.showMessagesOnTrigger(
///   key: 'purchase_completed',
///   value: 'product_123',
/// );
/// ```
class PPGInAppMessages {
  // Private constructor for singleton
  PPGInAppMessages._internal();

  /// Singleton instance
  static final PPGInAppMessages instance = PPGInAppMessages._internal();

  /// Alternative getter for singleton (matches iOS/Android pattern)
  static PPGInAppMessages get shared => instance;

  bool _isInitialized = false;
  CustomCodeActionHandler? _customCodeHandler;
  StreamSubscription<dynamic>? _eventSubscription;
  String? _pendingRoute;

  /// Check if SDK is initialized
  bool get isInitialized => _isInitialized;
  
  /// Buffer a route change that occurred before initialization
  /// Called by NavigatorObserver when SDK is not yet initialized
  void bufferRoute(String route) {
    _pendingRoute = route;
  }

  /// Initialize the In-App Messages SDK
  /// 
  /// Must be called before using any other methods.
  /// 
  /// Parameters:
  /// - [apiKey]: Your PushPushGo API key
  /// - [projectId]: Your PushPushGo project ID
  /// - [isProduction]: Use production environment (default: true)
  /// - [isDebug]: Enable debug logging (default: false)
  Future<void> initialize({
    required String apiKey,
    required String projectId,
    bool isProduction = true,
    bool isDebug = false,
  }) async {
    if (_isInitialized) {
      log('PPGInAppMessages: Already initialized');
      return;
    }

    try {
      await InAppMessagesChannel.invokeMethod(
        method: InAppMethod.initialize,
        arguments: {
          'apiKey': apiKey,
          'projectId': projectId,
          'isProduction': isProduction,
          'isDebug': isDebug,
        },
      );
      _isInitialized = true;
      log('PPGInAppMessages: Initialized successfully');
      
      // Process any buffered route from NavigatorObserver
      if (_pendingRoute != null) {
        await onRouteChanged(_pendingRoute!);
        _pendingRoute = null;
      }
    } catch (e) {
      log('PPGInAppMessages: Initialization failed - $e');
      rethrow;
    }
  }

  /// Notify the SDK about a route/screen change
  /// 
  /// Call this when the user navigates to a new screen.
  /// The SDK will check for eligible messages to display.
  /// 
  /// Example:
  /// ```dart
  /// PPGInAppMessages.instance.onRouteChanged('home');
  /// PPGInAppMessages.instance.onRouteChanged('product_detail');
  /// ```
  Future<void> onRouteChanged(String route) async {
    _checkInitialized();
    
    try {
      await InAppMessagesChannel.invokeMethod(
        method: InAppMethod.onRouteChanged,
        arguments: {'route': route},
      );
    } catch (e) {
      log('PPGInAppMessages: onRouteChanged failed - $e');
    }
  }

  /// Show messages matching a custom trigger
  /// 
  /// Use this to display messages based on custom events in your app.
  /// 
  /// Parameters:
  /// - [key]: The trigger key (e.g., 'purchase_completed', 'level_up')
  /// - [value]: The trigger value (e.g., 'product_123', '10')
  /// 
  /// Example:
  /// ```dart
  /// // After purchase
  /// PPGInAppMessages.instance.showMessagesOnTrigger(
  ///   key: 'purchase_completed',
  ///   value: 'order_123',
  /// );
  /// 
  /// // On level completion
  /// PPGInAppMessages.instance.showMessagesOnTrigger(
  ///   key: 'level_completed',
  ///   value: '5',
  /// );
  /// ```
  Future<void> showMessagesOnTrigger({
    required String key,
    required String value,
  }) async {
    _checkInitialized();
    
    try {
      await InAppMessagesChannel.invokeMethod(
        method: InAppMethod.showMessagesOnTrigger,
        arguments: {
          'key': key,
          'value': value,
        },
      );
    } catch (e) {
      log('PPGInAppMessages: showMessagesOnTrigger failed - $e');
    }
  }

  /// Set a handler for custom code actions
  /// 
  /// When a user clicks a button with a custom code action (JS type),
  /// your handler will be called with the custom code string.
  /// 
  /// Example:
  /// ```dart
  /// PPGInAppMessages.instance.setCustomCodeActionHandler((code) {
  ///   if (code == 'navigate_to_shop') {
  ///     Navigator.pushNamed(context, '/shop');
  ///   } else if (code == 'apply_discount') {
  ///     applyDiscount();
  ///   }
  /// });
  /// ```
  void setCustomCodeActionHandler(CustomCodeActionHandler handler) {
    _customCodeHandler = handler;
    _setupEventListening();
    
    // Notify native side that we want to receive events
    InAppMessagesChannel.invokeMethod(
      method: InAppMethod.setCustomCodeActionHandler,
      arguments: {'enabled': true},
    ).catchError((e) {
      log('PPGInAppMessages: setCustomCodeActionHandler failed - $e');
    });
  }

  /// Clear the message cache
  /// 
  /// Forces fresh data fetch on next API call.
  /// Useful for testing or troubleshooting.
  /// 
  /// Note: This method is only available on iOS.
  Future<void> clearMessageCache() async {
    _checkInitialized();
    
    try {
      await InAppMessagesChannel.invokeMethod(
        method: InAppMethod.clearMessageCache,
      );
      log('PPGInAppMessages: Cache cleared');
    } catch (e) {
      log('PPGInAppMessages: clearMessageCache failed - $e');
    }
  }

  /// Setup event listening for custom code actions
  void _setupEventListening() {
    // Cancel existing subscription if any
    _eventSubscription?.cancel();
    
    _eventSubscription = InAppMessagesChannel.eventStream.listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;
          final code = event['code'] as String?;
          
          if (type == 'customCode' && code != null && _customCodeHandler != null) {
            _customCodeHandler!(code);
          }
        }
      },
      onError: (error) {
        log('PPGInAppMessages: Event stream error - $error');
      },
    );
  }

  /// Check if SDK is initialized and throw if not
  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'PPGInAppMessages is not initialized. Call initialize() first.',
      );
    }
  }

  /// Dispose resources (call when app is closing)
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _customCodeHandler = null;
  }
}
