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
    case onNotificationClicked
    case sendBeacon
  }
  
  private var channel: FlutterMethodChannel?
  private var application: UIApplication?
  private var handleNotificationLink: Bool = true
  
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
        return sendBeacon(serialized: call.arguments, callback: result)
    default:
        return result(FlutterMethodNotImplemented)
    }
  }

  public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]) -> Bool {
    self.application = application;
    return true
  }

    // TODO
  private func unregisterFromNotifications(callback: @escaping FlutterResult) {
    print("unregisterFromNotifications")
    PPG.unsubscribeUser() { result in
      DispatchQueue.main.async {
        switch result {
        case .error(let error):
            // handle error
            print(error)
            return callback("error")
        case .success:
            return callback("success")
        }
      }
    }
  }
  
  private func getSubscriberId(callback: @escaping FlutterResult) {
    print("getSubscriberId")
    return callback(PPG.subscriberId)
  }

  private func createBeaconTagStrategy(_ strategy: String?) -> BeaconTagStrategy {
      guard let rawValue = strategy else {
          return .append
      }

      return BeaconTagStrategy(rawValue: rawValue) ?? .append
  }

  private func sendBeacon(serialized: Any?, callback: @escaping FlutterResult) {
    print("sendBeacon")
    
    guard let stringValue = serialized as? String else {
      print ("value is not a string, omit")
      return callback("error");
    }
    
    guard let parsedJSON = try? JSONSerialization.jsonObject(with: stringValue.data(using: .utf8)!) as? [String: Any] else {
      print("cannot parse json, omit sending beacon")
      return callback("error");
    }
      
    let beacon = Beacon()
    
    if let tagsRaw = parsedJSON["tags"] as? [[String: Any]] {
      tagsRaw.forEach({ it in
        if let key = it["key"] as? String,
           let value = it["value"] as? String,
           let strategy = it["strategy"] as? String,
           let ttl = it["ttl"] as? Int64 {
            beacon.addTag(BeaconTag(tag: value, label: key, strategy: createBeaconTagStrategy(strategy), ttl: ttl))
        } else {
          print("cannot parse to string key or value, omit");
        }
      })
    } else {
      print("cannot parse tags omit")
    }
    
    if let tagsToDeleteRaw = parsedJSON["tagsToDelete"] as? [[String: Any]] {
      tagsToDeleteRaw.forEach({ it in
        if let key = it["key"] as? String,
           let value = it["value"] as? String {
          beacon.addTagToDelete(BeaconTag(tag: value, label: key))
        } else {
          print("cannot parse to string key or value, omit");
        }
      })
    } else {
      print("cannot parse tags to delete")
    }
    
    if let selectorsRaw = parsedJSON["selectors"] as? [String: Any] {
      selectorsRaw.forEach { key, value in
          if let stringValue = value as? String {
              beacon.addSelector(key, stringValue)
          } else if let floatValue = value as? Float {
              beacon.addSelector(key, floatValue)
          } else if let dateValue = value as? Date {
              beacon.addSelector(key, dateValue)
          } else if let boolValue = value as? Bool {
              beacon.addSelector(key, boolValue)
          } else {
              print("cannot parse to string key or value, omit")
          }
      }
    } else {
      print("cannot parse selectors")
    }
  
    if let customId = parsedJSON["customId"] as? String {
      beacon.customId = customId
    } else {
      print("cannot parse custom id")
    }
    
    beacon.send() { result in
      DispatchQueue.main.async {
        switch(result) {
          case .error(let error):
            print(error);
            return callback("error")
          case .success:
            return callback("success")
        }
      }
    }
  }

  private func onInitialize(options: Any?, callback: @escaping FlutterResult) {
    guard let hashable = options as? [AnyHashable: Any] else {
      print("Initialize method argument should be hashable map")
      return callback("error");
    }

    guard let appGroupId = hashable["appGroupId"] as? String else {
      print("appGroupId is required")
      return callback("error");
    }
    
    guard let projectId = hashable["projectId"] as? String else {
      print("projectId is required")
      return callback("error");
    }
    
    guard let apiToken = hashable["apiToken"] as? String else {
      print("apiToken is required")
      return callback("error");
    }
    
    // Parse handleNotificationLink option
    if let handleLinkStr = hashable["handleNotificationLink"] as? String {
      self.handleNotificationLink = handleLinkStr.lowercased() != "false"
    } else {
      self.handleNotificationLink = true
    }
    
    UNUserNotificationCenter.current().delegate = PushpushgoSdkPlugin.instance
    PPG.initializeNotifications(projectId: projectId, apiToken: apiToken, appGroupId: appGroupId)
    
    return callback("success")
  }

  private func onRegisterForNotifications(callback: @escaping FlutterResult) {
    guard let application = self.application else {
      print("UIApplication cannot be reached")
      return callback("error")
    }
    
    PPG.registerForNotifications(application: application, handler: { result in
        DispatchQueue.main.async {
          switch result {
          case .error(let error):
              // handle error
              print(error)
              return callback("error")
          case .success:
              return callback("success")
          }
        }
    })
  }

  public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PPG.sendDeviceToken(deviceToken) { subscriberId in
      print(deviceToken)
      print(subscriberId)
      DispatchQueue.main.async {
        self.channel?.invokeMethod(MethodIdentifier.onNewSubscription.rawValue, arguments: PPG.subscriberId)
      }
    }
  }

  public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
      print("didReceiveRemoteNotification")
      PPG.registerNotificationDeliveredFromUserInfo(userInfo: userInfo) { status in
          print(status);
      completionHandler(.newData)
      }
      return true
  }

  // Works only on UIKit on SwiftUI it can be done onChange()
  public func applicationWillEnterForeground(_ application: UIApplication) {
      print("applicationWillEnterForeground")
  }
  
  public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("didFailToRegisterForRemoteNotificationsWithError")
    print(error.localizedDescription)
    DispatchQueue.main.async {
      self.channel?.invokeMethod(MethodIdentifier.onNewSubscription.rawValue, arguments: "{\"error\": \(error.localizedDescription)}")
    }
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

    let actionIdentifier = response.actionIdentifier
    // Handle the action
    if actionIdentifier == UNNotificationDefaultActionIdentifier {
        // User tapped the notification itself
        PPG.notificationClicked(response: response)
    } else if actionIdentifier == "button_1" {
        PPG.notificationButtonClicked(response: response, button: 1)
    } else if actionIdentifier == "button_2" {
        PPG.notificationButtonClicked(response: response, button: 2)
    } else {
        // Track as regular notification click for unknown actions
        PPG.notificationClicked(response: response)
    }

    // Send notification data to Flutter
    sendNotificationClickedEvent(response: response, actionIdentifier: actionIdentifier)

    // Handle URL opening if present and handleNotificationLink is enabled
    if self.handleNotificationLink {
      let (responseUrl, isUniversalLink) = PPG.getUrlFromNotificationResponse(response: response)

      if let url = responseUrl {
          #if !APP_EXTENSION
          DispatchQueue.main.async {
              if isUniversalLink {
                  // Handle as Universal Link using NSUserActivity
                  let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
                  userActivity.webpageURL = url
                  
                  if let appDelegate = UIApplication.shared.delegate,
                     appDelegate.responds(to: #selector(UIApplicationDelegate.application(_:continue:restorationHandler:))) {
                      appDelegate.application?(UIApplication.shared, continue: userActivity, restorationHandler: { _ in })
                  } else {
                      // Fallback if app delegate can't handle it or is not configured for UL
                      UIApplication.shared.open(url)
                  }
              } else {
                  // Open as regular URL in browser
                  UIApplication.shared.open(url)
              }
          }
          #else
          // In an app extension, we typically wouldn't open URLs.
          print("PushPushGo SDK (Flutter Plugin): URL opening skipped in app extension context.")
          #endif
      }
    }
    completionHandler()
  }
  
  public func userNotificationCenter(_ center: UNUserNotificationCenter, didDismissNotification notification: UNNotification) {
      print("userNotificationCenter.didDismissNotification")
  }

  private func sendNotificationClickedEvent(response: UNNotificationResponse, actionIdentifier: String) {
    let userInfo = response.notification.request.content.userInfo
    var notificationData: [String: Any] = [:]
    
    // Copy all userInfo data
    for (key, value) in userInfo {
      if let stringKey = key as? String {
        notificationData[stringKey] = value
      }
    }
    
    // Add action identifier
    notificationData["actionIdentifier"] = actionIdentifier
    
    // Add notification content
    notificationData["title"] = response.notification.request.content.title
    notificationData["body"] = response.notification.request.content.body
    
    DispatchQueue.main.async {
      self.channel?.invokeMethod(MethodIdentifier.onNotificationClicked.rawValue, arguments: notificationData)
    }
  }
}

