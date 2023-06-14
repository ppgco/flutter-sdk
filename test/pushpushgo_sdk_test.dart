import 'package:flutter_test/flutter_test.dart';
import 'package:pushpushgo_sdk/pushpushgo_sdk.dart';
import 'package:pushpushgo_sdk/pushpushgo_sdk_platform_interface.dart';
import 'package:pushpushgo_sdk/pushpushgo_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPushpushgoSdkPlatform
    with MockPlatformInterfaceMixin
    implements PushpushgoSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PushpushgoSdkPlatform initialPlatform = PushpushgoSdkPlatform.instance;

  test('$MethodChannelPushpushgoSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPushpushgoSdk>());
  });

  test('getPlatformVersion', () async {
    PushpushgoSdk pushpushgoSdkPlugin = PushpushgoSdk();
    MockPushpushgoSdkPlatform fakePlatform = MockPushpushgoSdkPlatform();
    PushpushgoSdkPlatform.instance = fakePlatform;

    expect(await pushpushgoSdkPlugin.getPlatformVersion(), '42');
  });
}
