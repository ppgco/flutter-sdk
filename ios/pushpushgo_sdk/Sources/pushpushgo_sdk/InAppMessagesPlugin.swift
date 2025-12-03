import Flutter
import PPG_InAppMessages
import UIKit

/// Flutter plugin for PushPushGo In-App Messages
public class InAppMessagesPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    // Constants
    private static let methodChannelName = "com.pushpushgo/inappmessages/methods"
    private static let eventChannelName = "com.pushpushgo/inappmessages/events"
    
    // Properties
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    // Method Identifiers
    private enum MethodIdentifier: String {
        case initialize
        case onRouteChanged
        case showMessagesOnTrigger
        case setCustomCodeActionHandler
        case clearMessageCache
    }
    
    // FlutterPlugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = InAppMessagesPlugin()
        
        // Setup Method Channel
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        // Setup Event Channel
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)
        
        print("InAppMessagesPlugin: Registered")
    }
    
    // FlutterPlugin Method Handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let method = MethodIdentifier(rawValue: call.method) else {
            result(FlutterMethodNotImplemented)
            return
        }
        
        switch method {
        case .initialize:
            handleInitialize(call: call, result: result)
        case .onRouteChanged:
            handleOnRouteChanged(call: call, result: result)
        case .showMessagesOnTrigger:
            handleShowMessagesOnTrigger(call: call, result: result)
        case .setCustomCodeActionHandler:
            handleSetCustomCodeActionHandler(call: call, result: result)
        case .clearMessageCache:
            handleClearMessageCache(result: result)
        }
    }
    
    // Method Implementations
    
    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let apiKey = args["apiKey"] as? String,
              let projectId = args["projectId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "apiKey and projectId are required",
                details: nil
            ))
            return
        }
        
        let isProduction = args["isProduction"] as? Bool ?? true
        let isDebug = args["isDebug"] as? Bool ?? false
        
        InAppMessagesSDK.shared.initialize(
            apiKey: apiKey,
            projectId: projectId,
            isProduction: isProduction,
            isDebug: isDebug
        )
        
        print("InAppMessagesPlugin: Initialized")
        result("success")
    }
    
    private func handleOnRouteChanged(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let route = args["route"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "route is required",
                details: nil
            ))
            return
        }
        
        InAppMessagesSDK.shared.onRouteChanged(route)
        result(nil)
    }
    
    private func handleShowMessagesOnTrigger(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String,
              let value = args["value"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "key and value are required",
                details: nil
            ))
            return
        }
        
        InAppMessagesSDK.shared.showMessagesOnTrigger(key: key, value: value)
        result(nil)
    }
    
    private func handleSetCustomCodeActionHandler(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Set up the custom code action handler that sends events to Flutter
        InAppMessagesSDK.shared.setCustomCodeActionHandler { [weak self] customCode in
            guard let self = self, let eventSink = self.eventSink else {
                print("InAppMessagesPlugin: No event sink available for custom code")
                return
            }
            
            // Send event to Flutter on main queue
            DispatchQueue.main.async {
                eventSink([
                    "type": "customCode",
                    "code": customCode
                ])
            }
        }
        
        result(nil)
    }
    
    private func handleClearMessageCache(result: @escaping FlutterResult) {
        InAppMessagesSDK.shared.clearMessageCache()
        result(nil)
    }
    
    // FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("InAppMessagesPlugin: Event stream connected")
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("InAppMessagesPlugin: Event stream disconnected")
        return nil
    }
}
