import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pushpushgo_sdk_platform_interface.dart';

/// An implementation of [PushpushgoSdkPlatform] that uses method channels.
class MethodChannelPushpushgoSdk extends PushpushgoSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pushpushgo_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
