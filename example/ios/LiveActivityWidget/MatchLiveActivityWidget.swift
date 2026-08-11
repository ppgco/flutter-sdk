import ActivityKit
import PPG_LiveActivities
import SwiftUI
import WidgetKit

/// Live Activity widget for the PushPushGo football match template.
///
/// The Lock Screen and Dynamic Island views ship with the SDK, so the whole
/// extension is this declaration — the backend drives the content through
/// ActivityKit pushes.
///
/// The extension's deployment target is iOS 17.2, which is why no `@available`
/// annotations are needed here.
@main
struct MatchLiveActivityWidget: Widget {

    /// The widget runs in its own process and inherits nothing from the host
    /// app, so the shared App Group has to be wired up again. It must match the
    /// `appGroupId` passed to `PPGLiveActivities.initialize` on the Dart side.
    init() {
        LiveActivitiesSDK.configureWidgetExtension(
            appGroupId: "group.ppg.fluttersdk"
        )
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            // Lock Screen / banner
            PPGMatchLockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island
            PPGMatchDynamicIsland(context: context).body()
        }
    }
}
