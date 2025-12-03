import 'package:flutter/services.dart';

/// Channel for In-App Messages communication with native platforms
class InAppMessagesChannel {
  static const String _methodChannelName = 'com.pushpushgo/inappmessages/methods';
  static const String _eventChannelName = 'com.pushpushgo/inappmessages/events';
  
  static const Duration _channelTimeout = Duration(seconds: 15);
  
  static const MethodChannel _methodChannel = MethodChannel(_methodChannelName);
  static const EventChannel _eventChannel = EventChannel(_eventChannelName);

  /// Get the event channel stream for receiving events from native
  static Stream<dynamic> get eventStream => _eventChannel.receiveBroadcastStream();

  /// Invoke a method on the native side
  static Future<T?> invokeMethod<T>({
    required InAppMethod method,
    dynamic arguments,
  }) {
    return _methodChannel
        .invokeMethod<T>(method.name, arguments)
        .timeout(_channelTimeout);
  }
}

/// Available methods for In-App Messages
enum InAppMethod {
  initialize,
  onRouteChanged,
  showMessagesOnTrigger,
  setCustomCodeActionHandler,
  clearMessageCache,
}

extension InAppMethodExtension on InAppMethod {
  String get name {
    switch (this) {
      case InAppMethod.initialize:
        return 'initialize';
      case InAppMethod.onRouteChanged:
        return 'onRouteChanged';
      case InAppMethod.showMessagesOnTrigger:
        return 'showMessagesOnTrigger';
      case InAppMethod.setCustomCodeActionHandler:
        return 'setCustomCodeActionHandler';
      case InAppMethod.clearMessageCache:
        return 'clearMessageCache';
    }
  }
}
