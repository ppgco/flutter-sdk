import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushpushgo_sdk/pushpushgo_sdk_method_channel.dart';

void main() {
  MethodChannelPushpushgoSdk platform = MethodChannelPushpushgoSdk();
  const MethodChannel channel = MethodChannel('pushpushgo_sdk');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
