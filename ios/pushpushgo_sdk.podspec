#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pushpushgo_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pushpushgo_sdk'
  s.version          = '1.4.0'
  s.summary          = 'PushPushGo SDK'
  s.description      = <<-DESC
  PushPushGo SDK for Flutter (Dart)
  Supports iOS and Android (Firebase/HMS)
                       DESC
  s.homepage         = 'https://github.com/ppgco/flutter-sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'PushPushGo Developers' => 'support@pushpushgo.com' }
  s.source           = { :path => '.' }
  s.source_files = 'pushpushgo_sdk/Sources/pushpushgo_sdk/**/*'
  s.dependency 'Flutter'
  s.dependency 'PPG_framework'
  s.dependency 'PPG_InAppMessages'
  # Live Activities are linked automatically on Swift Package Manager. On
  # CocoaPods the PPG_LiveActivities podspec still declares a 17.2 deployment
  # target, which cannot be a dependency of this 14.0 pod — until that is
  # relaxed upstream, apps opt in by adding `pod 'PPG_LiveActivities'` to their
  # own Podfile. The plugin compiles with or without the module.
  # s.dependency 'PPG_LiveActivities'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
