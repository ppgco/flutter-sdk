import Flutter
import PPG_framework
import UserNotifications

public class PushpushgoSdkPlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate {

  enum MethodIdentifier: String {
    case initialize
    case registerForNotifications
    case unregisterFromNotifications
    case getSubscriberId
    case onNewSubscription
  }
  
  private var channel: FlutterMethodChannel?
  private var application: UIApplication?
  
  static var instance: PushpushgoSdkPlugin?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.pushpushgo/sdk", binaryMessenger: registrar.messenger())
    let instance = PushpushgoSdkPlugin()
    
    PushpushgoSdkPlugin.instance = instance
    
    instance.channel = channel
    registrar.addApplicationDelegate(instance)
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    print("registrar")
  }
    
    
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let method = MethodIdentifier(rawValue: call.method)
    switch method {
    case .initialize:
        return onInitialize(options: call.arguments, callback: result)
    case .registerForNotifications:
        return onRegisterForNotifications(callback: result)
    case .unregisterFromNotifications:
        return unregisterFromNotifications(callback: result)
    case .getSubscriberId:
        return getSubscriberId(callback: result)
    case .sendBeacon:
        return sendBeacon(callback: result)    
    default:
        return result(FlutterMethodNotImplemented)
    }
  }

  public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
    self.application = application;
    return true
  }

    // TODO
  private func unregisterFromNotifications(callback: @escaping FlutterResult) {
    print("unregisterFromNotifications")
    return callback("unregisterFromNotifications")
  }
  
  // TODO
  private func getSubscriberId(callback: @escaping FlutterResult) {
    print("getSubscriberId")
    return callback("getSubscriberId")
  }

  // TODO
  private func sendBeacon(options: Any?, callback: @escaping FlutterResult) {
    print("sendBeacon")
    return callback("sendBeacon")
  }

  private func onInitialize(options: Any?, callback: @escaping FlutterResult) {
    guard let hashable = options as? [AnyHashable: Any] else {
      print("Initialize method argument should be hashable map")
      return callback("failed");
    }
    
    guard let projectId = hashable["projectId"] as? String else {
      print("projectId is required")
      return callback("failed");
    }
    
    guard let apiToken = hashable["apiToken"] as? String else {
      print("apiToken is required")
      return callback("failed");
    }
    
    PPG.initializeNotifications(projectId: projectId, apiToken: apiToken)
    UNUserNotificationCenter.current().delegate = PushpushgoSdkPlugin.instance
    
    return callback("success")
  }

  private func onRegisterForNotifications(callback: @escaping FlutterResult) {
    guard let application = self.application else {
      print("UIApplication cannot be reached")
      return callback("failed")
    }
    
    PPG.registerForNotifications(application: application, handler: { result in
        switch result {
        case .error(let error):
            // handle error
            print(error)
            return callback("denied")
        case .success:
            return callback("granted")
        }
    })
  }

  public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PPG.sendDeviceToken(deviceToken) { subscriberId in
      print(deviceToken)
      print(subscriberId)
      self.channel?.invokeMethod(MethodIdentifier.onNewSubscription.rawValue, arguments: subscriberId)
    }
  }

  public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
      print("didReceiveRemoteNotification")
      return true
  }

  // Works only on UIKit on SwiftUI it can be done onChange()
  public func applicationWillEnterForeground(_ application: UIApplication) {
      print("applicationWillEnterForeground")
  }
  
  public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("didFailToRegisterForRemoteNotificationsWithError")
    print(error.localizedDescription)
    channel?.invokeMethod(MethodIdentifier.onNewSubscription.rawValue, arguments: "{\"error\": \(error.localizedDescription)}")
  }
  
  public func applicationDidBecomeActive(_ application: UIApplication) {
    print("applicationDidBecomeActive")
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    PPG.sendEventsDataToApi()
  }

}

extension PushpushgoSdkPlugin: UNUserNotificationCenterDelegate {
  
  public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      print("userNotificationCenter.willPresent")
      // Display notification when app is in foreground, optional
      completionHandler([.alert, .badge, .sound])
  }
  
  public func userNotificationCenter(_ center: UNUserNotificationCenter,
          didReceive response: UNNotificationResponse,
          withCompletionHandler completionHandler:
            @escaping () -> Void) {
    print("userNotificationCenter.didReceive")

    // Send information about clicked notification to framework
    PPG.notificationClicked(response: response)

    // Open external link from push notification
    // Remove this section if this behavior is not expected
    guard let url = PPG.getUrlFromNotificationResponse(response: response)
        else {
            completionHandler()
            return
        }
    UIApplication.shared.open(url)
    completionHandler()
  }
  
  public func userNotificationCenter(_ center: UNUserNotificationCenter, didDismissNotification notification: UNNotification) {
      print("userNotificationCenter.didDismissNotification")
  }
}

