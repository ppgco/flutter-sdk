import 'dart:async';
import 'dart:developer';

import 'package:pushpushgo_sdk/ppg_liveactivities_channel.dart';
import 'package:pushpushgo_sdk/ppg_liveactivities_models.dart';

/// Handler for taps on a Live Activity (body or action button)
typedef LiveActivityClickHandler = void Function(LiveActivityClick click);

/// PushPushGo Live Activities for Flutter
///
/// Live Activities are real-time, continuously updated notifications driven by
/// the PushPushGo backend: an Android 16 Live Update notification, or an iOS
/// Live Activity on the Lock Screen and Dynamic Island.
///
/// The app only decides *which* live notification to follow — rendering, score
/// and phase updates are handled entirely by the native SDK.
///
/// Example:
/// ```dart
/// // After PushpushgoSdk.initialize() and registerForNotifications()
/// await PPGLiveActivities.instance.initialize(
///   appGroupId: 'group.com.your.app.liveactivities', // iOS only
/// );
///
/// if (await PPGLiveActivities.instance.isSupported()) {
///   await PPGLiveActivities.instance.subscribe('<liveNotificationId>');
/// }
///
/// PPGLiveActivities.instance.statusStream.listen((event) {
///   print('Live Activity: ${event.status}');
/// });
/// ```
///
/// See `LIVE_ACTIVITIES.md` for the full integration guide, including the iOS
/// Widget Extension setup.
class PPGLiveActivities {
  // Private constructor for singleton
  PPGLiveActivities._internal();

  /// Singleton instance
  static final PPGLiveActivities instance = PPGLiveActivities._internal();

  /// Alternative getter for singleton (matches iOS/Android pattern)
  static PPGLiveActivities get shared => instance;

  bool _isInitialized = false;
  LiveActivityClickHandler? _clickHandler;
  StreamSubscription<dynamic>? _eventSubscription;
  StreamController<LiveActivityStatusEvent>? _statusController;

  /// Check if Live Activities support is initialized
  bool get isInitialized => _isInitialized;

  /// Lifecycle events for subscribed live notifications
  ///
  /// The stream is a broadcast stream, so it can be listened to from several
  /// places. Events keep arriving until [dispose] is called.
  Stream<LiveActivityStatusEvent> get statusStream {
    _statusController ??= StreamController<LiveActivityStatusEvent>.broadcast();
    _setupEventListening();
    return _statusController!.stream;
  }

  /// Initialize Live Activities support
  ///
  /// Call this after `PushpushgoSdk.initialize()` — the API key and project id
  /// are taken from the main SDK configuration.
  ///
  /// Parameters:
  /// - [appGroupId]: **iOS only, required there.** App Group shared between the
  ///   app and its Widget Extension (e.g. `group.com.your.app.liveactivities`).
  ///   Team badges and hot-message state are persisted there. Ignored on
  ///   Android.
  /// - [isProduction]: Use production environment (default: true)
  /// - [isDebug]: Enable debug logging (default: false)
  Future<void> initialize({
    String? appGroupId,
    bool isProduction = true,
    bool isDebug = false,
  }) async {
    if (_isInitialized) {
      log('PPGLiveActivities: Already initialized');
      return;
    }

    try {
      await LiveActivitiesChannel.invokeMethod<void>(
        method: LiveActivityMethod.initialize,
        arguments: {
          'appGroupId': appGroupId,
          'isProduction': isProduction,
          'isDebug': isDebug,
        },
      );
      _isInitialized = true;
      _setupEventListening();
      log('PPGLiveActivities: Initialized successfully');
    } catch (e) {
      log('PPGLiveActivities: Initialization failed - $e');
      rethrow;
    }
  }

  /// Whether this device can display Live Activities
  ///
  /// - Android: `true` on Android 16 (API 36) and newer.
  /// - iOS: `true` on iOS 17.2+ when the user has not disabled Live Activities
  ///   for the app.
  ///
  /// Always check this before subscribing — on unsupported devices the
  /// remaining methods are safe to call but do nothing.
  Future<bool> isSupported() async {
    try {
      final result = await LiveActivitiesChannel.invokeMethod<bool>(
        method: LiveActivityMethod.isSupported,
      );
      return result ?? false;
    } catch (e) {
      log('PPGLiveActivities: isSupported failed - $e');
      return false;
    }
  }

  /// Subscribe this device to a live notification
  ///
  /// The device must already be a registered push subscriber — call
  /// `PushpushgoSdk.registerForNotifications()` first.
  ///
  /// From this point on the backend drives everything: it pushes `start`,
  /// `update` and `end` events, and the native SDK renders them. If the
  /// activity is already running when the device subscribes, its current state
  /// is rendered right away.
  ///
  /// Returns the backend subscriber id on Android, `null` on iOS (where the
  /// registration is keyed by an internal installation id).
  Future<String?> subscribe(String liveNotificationId) async {
    _checkInitialized();

    try {
      return await LiveActivitiesChannel.invokeMethod<String>(
        method: LiveActivityMethod.subscribe,
        arguments: {'liveNotificationId': liveNotificationId},
      );
    } catch (e) {
      log('PPGLiveActivities: subscribe failed - $e');
      rethrow;
    }
  }

  /// Unsubscribe this device from a live notification
  ///
  /// No-op when the device is not subscribed to it.
  Future<void> unsubscribe(String liveNotificationId) async {
    _checkInitialized();

    try {
      await LiveActivitiesChannel.invokeMethod<void>(
        method: LiveActivityMethod.unsubscribe,
        arguments: {'liveNotificationId': liveNotificationId},
      );
    } catch (e) {
      log('PPGLiveActivities: unsubscribe failed - $e');
      rethrow;
    }
  }

  /// The stored subscriber id for a live notification
  ///
  /// Android only — returns `null` on iOS.
  Future<String?> getSubscriberId(String liveNotificationId) async {
    _checkInitialized();

    try {
      final id = await LiveActivitiesChannel.invokeMethod<String>(
        method: LiveActivityMethod.getSubscriberId,
        arguments: {'liveNotificationId': liveNotificationId},
      );
      return (id == null || id.isEmpty) ? null : id;
    } catch (e) {
      log('PPGLiveActivities: getSubscriberId failed - $e');
      return null;
    }
  }

  /// Whether a given live notification is currently rendered on this device
  Future<bool> isActive(String liveNotificationId) async {
    _checkInitialized();

    try {
      final result = await LiveActivitiesChannel.invokeMethod<bool>(
        method: LiveActivityMethod.isActive,
        arguments: {'liveNotificationId': liveNotificationId},
      );
      return result ?? false;
    } catch (e) {
      log('PPGLiveActivities: isActive failed - $e');
      return false;
    }
  }

  /// All Live Activities currently tracked by the native SDK
  Future<List<LiveActivityInfo>> getActiveActivities() async {
    _checkInitialized();

    try {
      final result = await LiveActivitiesChannel.invokeMethod<List<dynamic>>(
        method: LiveActivityMethod.getActiveActivities,
      );

      if (result == null) return <LiveActivityInfo>[];

      final activities = <LiveActivityInfo>[];
      for (final item in result) {
        if (item is Map) {
          activities.add(LiveActivityInfo.fromMap(item));
        }
      }
      return activities;
    } catch (e) {
      log('PPGLiveActivities: getActiveActivities failed - $e');
      return <LiveActivityInfo>[];
    }
  }

  /// Set a handler for taps on a Live Activity
  ///
  /// The handler receives the deep link carried by the tapped element and the
  /// index of the tapped action button (`-1` for the notification body).
  ///
  /// When `PushpushgoSdk.initialize()` was called with
  /// `handleNotificationLink: true` (the default) the SDK already opened the
  /// link — the handler is then informational. Pass `false` to route the link
  /// yourself.
  ///
  /// Example:
  /// ```dart
  /// PPGLiveActivities.instance.setClickHandler((click) {
  ///   if (click.deepLink != null) {
  ///     Navigator.of(context).pushNamed(click.deepLink!);
  ///   }
  /// });
  /// ```
  void setClickHandler(LiveActivityClickHandler handler) {
    _clickHandler = handler;
    _setupEventListening();
  }

  /// Feed a push envelope into the rendering pipeline — testing only
  ///
  /// Android only; a no-op on iOS. Lets you exercise the parse → render
  /// pipeline without a backend. See `LIVE_ACTIVITIES.md` for envelope
  /// examples.
  Future<void> simulatePush(Map<String, String> data) async {
    _checkInitialized();

    try {
      await LiveActivitiesChannel.invokeMethod<void>(
        method: LiveActivityMethod.simulatePush,
        arguments: {'data': data},
      );
    } catch (e) {
      log('PPGLiveActivities: simulatePush failed - $e');
    }
  }

  /// Subscribe to the native event channel once and fan events out
  void _setupEventListening() {
    if (_eventSubscription != null) return;

    _eventSubscription = LiveActivitiesChannel.eventStream.listen(
      (event) {
        if (event is! Map) return;

        final type = event['type'] as String?;

        if (type == 'click') {
          final handler = _clickHandler;
          if (handler != null) {
            handler(LiveActivityClick.fromMap(event));
          }
          return;
        }

        if (type == 'status') {
          final controller = _statusController;
          if (controller != null && !controller.isClosed) {
            controller.add(LiveActivityStatusEvent.fromMap(event));
          }
        }
      },
      onError: (error) {
        log('PPGLiveActivities: Event stream error - $error');
      },
    );
  }

  /// Check if Live Activities support is initialized and throw if not
  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'PPGLiveActivities is not initialized. Call initialize() first.',
      );
    }
  }

  /// Dispose resources (call when app is closing)
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _statusController?.close();
    _statusController = null;
    _clickHandler = null;
  }
}
