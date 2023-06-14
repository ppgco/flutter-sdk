import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pushpushgo_sdk_method_channel.dart';

abstract class PushpushgoSdkPlatform extends PlatformInterface {
  /// Constructs a PushpushgoSdkPlatform.
  PushpushgoSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static PushpushgoSdkPlatform _instance = MethodChannelPushpushgoSdk();

  /// The default instance of [PushpushgoSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelPushpushgoSdk].
  static PushpushgoSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PushpushgoSdkPlatform] when
  /// they register themselves.
  static set instance(PushpushgoSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
