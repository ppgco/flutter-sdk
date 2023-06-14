
import 'pushpushgo_sdk_platform_interface.dart';

class PushpushgoSdk {
  Future<String?> getPlatformVersion() {
    return PushpushgoSdkPlatform.instance.getPlatformVersion();
  }
}
