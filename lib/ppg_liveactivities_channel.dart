import 'package:flutter/services.dart';

/// Channel for Live Activities communication with native platforms
class LiveActivitiesChannel {
  static const String _methodChannelName =
      'com.pushpushgo/liveactivities/methods';
  static const String _eventChannelName =
      'com.pushpushgo/liveactivities/events';

  static const Duration _channelTimeout = Duration(seconds: 15);

  static const MethodChannel _methodChannel = MethodChannel(_methodChannelName);
  static const EventChannel _eventChannel = EventChannel(_eventChannelName);

  /// Get the event channel stream for receiving events from native
  static Stream<dynamic> get eventStream =>
      _eventChannel.receiveBroadcastStream();

  /// Invoke a method on the native side
  static Future<T?> invokeMethod<T>({
    required LiveActivityMethod method,
    dynamic arguments,
  }) {
    return _methodChannel
        .invokeMethod<T>(method.name, arguments)
        .timeout(_channelTimeout);
  }
}

/// Available methods for Live Activities
enum LiveActivityMethod {
  initialize,
  isSupported,
  subscribe,
  unsubscribe,
  getSubscriberId,
  isActive,
  getActiveActivities,
  simulatePush,
}

extension LiveActivityMethodExtension on LiveActivityMethod {
  String get name {
    switch (this) {
      case LiveActivityMethod.initialize:
        return 'initialize';
      case LiveActivityMethod.isSupported:
        return 'isSupported';
      case LiveActivityMethod.subscribe:
        return 'subscribe';
      case LiveActivityMethod.unsubscribe:
        return 'unsubscribe';
      case LiveActivityMethod.getSubscriberId:
        return 'getSubscriberId';
      case LiveActivityMethod.isActive:
        return 'isActive';
      case LiveActivityMethod.getActiveActivities:
        return 'getActiveActivities';
      case LiveActivityMethod.simulatePush:
        return 'simulatePush';
    }
  }
}
