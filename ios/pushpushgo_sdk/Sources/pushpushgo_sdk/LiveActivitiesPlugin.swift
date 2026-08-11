import Flutter
import UIKit

// Live Activities ship as a separate module of the native SDK. It is always
// linked through Swift Package Manager; on CocoaPods it is only present once
// the app depends on `PPG_LiveActivities` (which requires a podspec accepting
// the app's deployment target). Everything that touches the module is compiled
// conditionally so the plugin keeps working either way.
#if canImport(PPG_LiveActivities)
import PPG_LiveActivities
#endif

/// Flutter plugin for PushPushGo Live Activities
///
/// Live Activities require iOS 17.2+. On older systems — and when the native
/// module is not linked at all — every method degrades gracefully:
/// `isSupported` reports `false` and the rest are no-ops, so the Dart side
/// needs no platform checks.
///
/// The football match template (`MatchActivityAttributes`) is wired in
/// directly: the native API is generic over `ActivityAttributes`, but generic
/// types cannot cross a method channel, and it is the only template the
/// backend serves today.
public class LiveActivitiesPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    // Constants
    private static let methodChannelName = "com.pushpushgo/liveactivities/methods"
    private static let eventChannelName = "com.pushpushgo/liveactivities/events"

    // Properties
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    /// Events produced before Dart attached to the event channel — a URL can
    /// open the app long before the Flutter engine is ready.
    private var pendingEvents: [[String: Any?]] = []

    static var instance: LiveActivitiesPlugin?

    // Method Identifiers
    private enum MethodIdentifier: String {
        case initialize
        case isSupported
        case subscribe
        case unsubscribe
        case getSubscriberId
        case isActive
        case getActiveActivities
        case simulatePush
    }

    // FlutterPlugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = LiveActivitiesPlugin()
        LiveActivitiesPlugin.instance = instance

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)

        print("LiveActivitiesPlugin: Registered")
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
        case .isSupported:
            handleIsSupported(result: result)
        case .subscribe:
            handleSubscribe(call: call, result: result)
        case .unsubscribe:
            handleUnsubscribe(call: call, result: result)
        case .getSubscriberId:
            // Android-only concept — iOS keys subscribers by installation id.
            result(nil)
        case .isActive:
            handleIsActive(call: call, result: result)
        case .getActiveActivities:
            handleGetActiveActivities(result: result)
        case .simulatePush:
            // Android-only testing helper.
            print("LiveActivitiesPlugin: simulatePush is not available on iOS")
            result(nil)
        }
    }

    // Method Implementations

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        #if canImport(PPG_LiveActivities)
        guard #available(iOS 17.2, *) else {
            print("LiveActivitiesPlugin: Live Activities require iOS 17.2+")
            result(nil)
            return
        }

        // Credentials come from the main SDK initialize() so the app does not
        // have to repeat them.
        guard let apiKey = PushpushgoSdkPlugin.configuredApiToken,
              let projectId = PushpushgoSdkPlugin.configuredProjectId else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Initialize the PushPushGo SDK before Live Activities",
                details: nil
            ))
            return
        }

        let args = call.arguments as? [String: Any]

        // The App Group is shared with the Widget Extension; it defaults to the
        // one already configured for push notifications.
        guard let appGroupId = (args?["appGroupId"] as? String)
                ?? PushpushgoSdkPlugin.configuredAppGroupId else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "appGroupId is required on iOS",
                details: nil
            ))
            return
        }

        let isProduction = args?["isProduction"] as? Bool ?? true
        let isDebug = args?["isDebug"] as? Bool ?? false

        LiveActivitiesSDK.shared.initialize(
            apiKey: apiKey,
            projectId: projectId,
            appGroupId: appGroupId,
            isProduction: isProduction,
            isDebug: isDebug
        )

        print("LiveActivitiesPlugin: Initialized")
        result(nil)
        #else
        print("LiveActivitiesPlugin: PPG_LiveActivities is not linked, skipping")
        result(nil)
        #endif
    }

    private func handleIsSupported(result: @escaping FlutterResult) {
        #if canImport(PPG_LiveActivities)
        if #available(iOS 17.2, *) {
            result(LiveActivitiesSDK.shared.areActivitiesEnabled())
            return
        }
        #endif
        result(false)
    }

    private func handleSubscribe(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let liveNotificationId = args["liveNotificationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "liveNotificationId is required",
                details: nil
            ))
            return
        }

        #if canImport(PPG_LiveActivities)
        guard #available(iOS 17.2, *) else {
            result(unsupportedError())
            return
        }

        LiveActivitiesSDK.shared.subscribe(
            MatchActivityAttributes.self,
            liveNotificationId: liveNotificationId,
            onCampaignAlreadyActive: { payload in
                // Late join: the campaign is already running, so no
                // push-to-start will arrive. Build the activity from the
                // current backend state instead.
                let dto = try PPGLiveNotificationDTO.decode(from: payload)
                guard let match = MatchActivityAttributes.from(dto: dto) else {
                    return nil
                }

                // Badges must land in the App Group before the widget renders.
                let badges = [
                    match.attributes.homeTeamBadgeUrl,
                    match.attributes.awayTeamBadgeUrl
                ].compactMap { $0 }

                if !badges.isEmpty {
                    _ = await LiveActivityImageManager.shared.prefetch(from: badges)
                }

                return (match.attributes, match.initialState)
            },
            onStatus: { [weak self] status in
                self?.emit(status: status, liveNotificationId: liveNotificationId)
            }
        )

        // iOS has no backend subscriber id to hand back — registration is keyed
        // by an internal installation id.
        result(nil)
        #else
        result(unsupportedError())
        #endif
    }

    private func handleUnsubscribe(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let liveNotificationId = args["liveNotificationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "liveNotificationId is required",
                details: nil
            ))
            return
        }

        #if canImport(PPG_LiveActivities)
        if #available(iOS 17.2, *) {
            LiveActivitiesSDK.shared.unsubscribe(liveNotificationId: liveNotificationId)
        }
        #endif

        result(nil)
    }

    private func handleIsActive(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let liveNotificationId = args["liveNotificationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "liveNotificationId is required",
                details: nil
            ))
            return
        }

        #if canImport(PPG_LiveActivities)
        if #available(iOS 17.2, *) {
            // Subscriber-driven activities are registered with the live
            // notification id as their template id.
            let isActive = LiveActivitiesSDK.shared.getActiveActivities()
                .contains { $0.templateId == liveNotificationId }
            result(isActive)
            return
        }
        #endif
        result(false)
    }

    private func handleGetActiveActivities(result: @escaping FlutterResult) {
        #if canImport(PPG_LiveActivities)
        if #available(iOS 17.2, *) {
            // `templateId` carries the live notification id for
            // subscriber-driven activities, which is what Dart calls `id`.
            let activities = LiveActivitiesSDK.shared.getActiveActivities().map { info in
                return [
                    "id": info.templateId,
                    "template": "FOOTBALL_MATCH_TRACKING",
                    "status": "active"
                ] as [String: Any?]
            }
            result(activities)
            return
        }
        #endif
        result([])
    }

    private func unsupportedError() -> FlutterError {
        return FlutterError(
            code: "UNSUPPORTED",
            message: "Live Activities require iOS 17.2 or newer and the PPG_LiveActivities module",
            details: nil
        )
    }

    // URL routing

    /// Handle a URL that opened the app from a Live Activity — an action
    /// button, or the `widgetURL` behind the notification body.
    ///
    /// Only the SDK-owned `ppg-la` scheme is consumed (returning `true`).
    /// Everything else returns `false` and is left untouched, so universal
    /// links and other plugins' deep links keep working — in particular the URL
    /// is never opened on the app's behalf here.
    ///
    /// Deep links are still reported to Dart while an activity is running, so
    /// the app can route them itself.
    @discardableResult
    static func handleOpenURL(_ url: URL) -> Bool {
        #if canImport(PPG_LiveActivities)
        guard #available(iOS 17.2, *) else { return false }

        if url.scheme?.lowercased() == LiveActivitiesSDK.urlScheme {
            var closedNotificationId = ""

            let handled = LiveActivitiesSDK.handleURL(url) { liveNotificationId in
                closedNotificationId = liveNotificationId
                LiveActivitiesSDK.shared.endAllActivities(ofType: MatchActivityAttributes.self)
            }

            LiveActivitiesPlugin.instance?.sendClick(
                liveNotificationId: closedNotificationId,
                deepLink: url.absoluteString
            )

            return handled
        }

        // A URL arriving while an activity is on screen is almost certainly a
        // tap on it; report it without claiming the URL.
        let active = LiveActivitiesSDK.shared.getActiveActivities()
        if let liveNotificationId = active.first?.templateId {
            LiveActivitiesPlugin.instance?.sendClick(
                liveNotificationId: liveNotificationId,
                deepLink: url.absoluteString
            )
        }

        return false
        #else
        return false
        #endif
    }

    // Events sent to Dart

    #if canImport(PPG_LiveActivities)
    @available(iOS 17.2, *)
    private func emit(status: LiveNotificationSubscriptionStatus, liveNotificationId: String) {
        var name: String
        var activityId: String?
        var error: String?

        switch status {
        case .registered:
            name = "registered"
        case .activityStarted(let id):
            name = "started"
            activityId = id
        case .updateTokenSent(let id):
            name = "tokenRegistered"
            activityId = id
        case .activityEnded(let id):
            name = "ended"
            activityId = id
        case .unsubscribed:
            name = "unsubscribed"
        case .error(let subscriptionError):
            name = "error"
            error = "\(subscriptionError)"
        }

        send([
            "type": "status",
            "status": name,
            "liveNotificationId": liveNotificationId,
            "activityId": activityId,
            "error": error
        ])
    }
    #endif

    /// Report a tap on a Live Activity.
    ///
    /// iOS delivers taps as URLs and does not identify which action button was
    /// used, so `actionIndex` is always `-1`.
    private func sendClick(liveNotificationId: String, deepLink: String?) {
        send([
            "type": "click",
            "liveNotificationId": liveNotificationId,
            "deepLink": deepLink,
            "actionIndex": -1
        ])
    }

    private func send(_ event: [String: Any?]) {
        DispatchQueue.main.async {
            guard let sink = self.eventSink else {
                print("LiveActivitiesPlugin: No event sink yet, buffering event")
                self.pendingEvents.append(event)
                return
            }

            sink(event)
        }
    }

    // FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("LiveActivitiesPlugin: Event stream connected")

        let buffered = pendingEvents
        pendingEvents.removeAll()
        buffered.forEach { events($0) }

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("LiveActivitiesPlugin: Event stream disconnected")
        return nil
    }
}
