import 'dart:async';

import 'package:pushpushgo_sdk/common_channel.dart';
import 'package:flutter/services.dart';

typedef MessageHandler = Function(Map<String, dynamic> message);
typedef SubscriptionHandler = Function(String serializedJSON);

typedef PpgOptions = Map<String, String>;

enum ResponseStatus {
  success,
  error
}

class PushpushgoSdk {

  String? lastSubscriptionJSON;

  SubscriptionHandler _onNewSubscriptionHandler = (String subscriberId) {
    throw UnsupportedError("onToken handler must be declared");
  };

  Future<void> initialize({
    required PpgOptions options,
    required SubscriptionHandler onNewSubscriptionHandler,
  }) {
    _onNewSubscriptionHandler = onNewSubscriptionHandler;

    CommonChannel.setMethodCallHandler(_handleChannelMethodCallback);
    return CommonChannel.invokeMethod<void>(
      method: ChannelMethod.initialize,
      arguments: options
    ).catchError(
      (error) {
        if (error is! TimeoutException) throw error;
      },
    );
  }

  Future<ResponseStatus> registerForNotifications() async {
    String result = await CommonChannel.invokeMethod<String>(
          method: ChannelMethod.registerForNotifications,
        ) ??
        "undefined";

    if (result == "success") {
      return ResponseStatus.success;
    }

    return ResponseStatus.error;
  }

  Future<ResponseStatus> unregisterFromNotifications() async {
    String result = await CommonChannel.invokeMethod<String>(
          method: ChannelMethod.unregisterFromNotifications,
        ) ??
        "undefined";

    if (result == "error") {
      return ResponseStatus.error;
    }

    return ResponseStatus.success;
  }

  Future<String?> getSubscriberId() async {
    return CommonChannel.invokeMethod<String>(
      method: ChannelMethod.getSubscriberId,
    );
  }

    Future<String?> sendBeacon(Map<String, dynamic> beaconData) async {
    return CommonChannel.invokeMethod<String>(
      method: ChannelMethod.sendBeacon,
      arguments: beaconData
    );
  }

  // From native to dart
  Future<dynamic> _handleChannelMethodCallback(MethodCall call) async {
    String method = call.method;

    dynamic arguments = call.arguments;
    
    if (method == ChannelMethod.onNewSubscription.name) {
      return _onNewSubscriptionHandler(arguments ?? "");
    }

    throw UnsupportedError("Unrecognized reply message");
  }
}
