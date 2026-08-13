import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pushpushgo_sdk/beacon.dart';
import 'dart:async';

import 'package:pushpushgo_sdk/pushpushgo_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// Global keys for navigation and snackbar from custom code handler
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class _MyAppState extends State<MyApp> {
  final _pushpushgo = PushpushgoSdk({
    "apiToken": "YOUR_API_KEY",
    "projectId": "YOUR_PROJECT_ID",
    "appGroupId": "group.ppg.fluttersdk"
  });

  @override
  void initState() {
    super.initState();
    initialize();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initialize() async {
    // Taps on the Live Activity body or its action buttons. Registered before
    // the first await so a tap that launched the app is handled as early as
    // possible — the SDK replays it anyway if the handler comes later.
    PPGLiveActivities.instance.setClickHandler((click) {
      log("LIVE ACTIVITY CLICKED: $click");
      // Surfaced on screen because a tap usually arrives during a cold start,
      // when no debugger is attached to see the log.
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 5),
          content: Text(
            "Live Activity clicked\n"
            "id: ${click.liveNotificationId}\n"
            "deepLink: ${click.deepLink ?? "-"}\n"
            "${click.isBodyClick ? "body" : "action button ${click.actionIndex}"}",
          ),
        ),
      );
    });

    // Initialize Push Notifications SDK
    await _pushpushgo.initialize(
      onNewSubscriptionHandler: (subscriberId) {
        log("MY SUBSCRIBER ID IS");
        log(subscriberId);
      },
      onNotificationClickedHandler: (notificationData) {
        log("NOTIFICATION CLICKED");
        log(notificationData.toString());
        // Example: Navigate to specific screen based on notification data
        // if (notificationData['link'] != null) {
        //   Navigator.of(context).pushNamed(notificationData['link']);
        // }
      },
      // Set to false to disable automatic URL opening on notification click
      // When false, you handle the link manually in onNotificationClickedHandler
      handleNotificationLink: false,
      isProduction: false, // Use staging API (api.master1.qappg.co)
      isDebug: true,
    );

    // Auto-register for notifications on app start (common use case)
    try {
      final registerResult = await _pushpushgo.registerForNotifications();
      log("Auto-register result: $registerResult");
    } catch (e) {
      log("Auto-register failed (will retry manually): $e");
    }

    // Initialize In-App Messages SDK
    await PPGInAppMessages.instance.initialize(
      apiKey: "YOUR_API_KEY",
      projectId: "YOUR_PROJECT_ID",
      isProduction: false, // Use staging API (api.master1.qappg.co)
      isDebug: true,
    );

    // Set up custom code action handler
    PPGInAppMessages.instance.setCustomCodeActionHandler((code) {
      log("Custom code action received: $code");
      _handleCustomCode(code);
    });

    // Initialize Live Activities
    // Credentials are reused from the push SDK; iOS additionally needs the App
    // Group shared with the Widget Extension.
    await PPGLiveActivities.instance.initialize(
      appGroupId: "group.ppg.fluttersdk",
      isProduction: false, // Use staging API (api.master1.qappg.co)
      isDebug: true,
    );

    if (!mounted) return;
  }

  /// Handle custom code actions from In-App Messages
  void _handleCustomCode(String code) {
    switch (code) {
      case 'navigate_details':
        // Navigate to details screen
        navigatorKey.currentState?.pushNamed('/details');
        break;

      case 'navigate_home':
        // Navigate back to home
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        break;

      case 'show_snackbar':
        // Show a snackbar message
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Custom action triggered from In-App Message!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        break;

      case 'show_promo':
        // Show promotional snackbar
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('🎉 Special offer: Use code INAPP20 for 20% off!'),
            backgroundColor: Colors.purple,
            duration: Duration(seconds: 5),
          ),
        );
        break;

      case 'show_dialog':
        // Show a dialog
        final context = navigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Custom Action'),
              content: const Text(
                  'This dialog was triggered by an In-App Message custom code action.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        break;

      default:
        // Unknown code - show info snackbar
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Unknown custom code: $code'),
            backgroundColor: Colors.orange,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Global keys for custom code handler actions
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      // Add NavigatorObserver for automatic route tracking
      navigatorObservers: [
        InAppMessagesNavigatorObserver(),
      ],
      routes: {
        '/': (context) => HomeScreen(pushpushgo: _pushpushgo),
        '/details': (context) => const DetailScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  final PushpushgoSdk pushpushgo;

  const HomeScreen({
    super.key,
    required this.pushpushgo,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Demo campaign used by the `simulatePush` buttons below.
const String _demoLiveNotificationId = "demo-match-1";

const String _demoConfiguration = '''
{"type":"FOOTBALL_MATCH_TRACKING",
 "content":{"title":"Premier League",
   "homeTeamName":"Arsenal",
   "homeTeamImage":"https://crests.football-data.org/57.png",
   "awayTeamName":"Chelsea",
   "awayTeamImage":"https://crests.football-data.org/61.png"},
 "design":{"android":{"hasTrackerIcon":true,
   "progressBarColor":{"lightMode":"#4CAF50","darkMode":"#2E7D32"},
   "breakTimeBarColor":{"lightMode":"#FFC107","darkMode":"#FFA000"}}},
 "statusLabels":{"PRE_MATCH":"Starting soon","FIRST_HALF":"1st half",
   "HALF_TIME_BREAK":"Half time","SECOND_HALF":"2nd half",
   "FULL_TIME":"Full time","OTHER":"Match"},
 "actions":[{"type":"OPEN_APP","name":"Open"},
   {"type":"CLOSE","name":"Dismiss"}],
 "timeout":{"minutes":150},
 "url":"app://demo/match/demo-match-1"}
''';

class _HomeScreenState extends State<HomeScreen> {
  String _statusMessage = "Ready";
  Color _statusColor = Colors.grey;

  final _liveNotificationController = TextEditingController();
  StreamSubscription<LiveActivityStatusEvent>? _liveActivitySubscription;

  @override
  void initState() {
    super.initState();

    // Lifecycle of subscribed live notifications
    _liveActivitySubscription =
        PPGLiveActivities.instance.statusStream.listen((event) {
      log("Live Activity status: $event");
      _updateStatus(
        "📡 Live Activity: ${event.status.name}"
        "${event.error != null ? "\n${event.error}" : ""}",
        color:
            event.status == LiveActivityStatus.error ? Colors.red : Colors.teal,
      );
    });
  }

  @override
  void dispose() {
    _liveActivitySubscription?.cancel();
    _liveNotificationController.dispose();
    super.dispose();
  }

  void _updateStatus(String message, {Color? color}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusColor = color ?? Colors.blue;
    });
  }

  /// Drive the Live Activity pipeline locally, without a backend campaign.
  ///
  /// Android only — `simulatePush` is a no-op on iOS, where activities are
  /// started by ActivityKit push-to-start. `configuration` is only required on
  /// `start`; later events reuse the one already tracked.
  Future<void> _simulateLiveActivityPush({
    required String event,
    int homeScore = 0,
    int awayScore = 0,
    String phase = "FIRST_HALF",
    String? hotMessage,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final envelope = <String, String>{
      'type': 'live_notification',
      'liveNotificationId': _demoLiveNotificationId,
      'event': event,
      'template': 'FOOTBALL_MATCH_TRACKING',
      'liveData': '{"type":"FOOTBALL_MATCH_TRACKING",'
          '"homeTeamScore":$homeScore,"awayTeamScore":$awayScore,'
          '"status":"$phase","statusChangedAt":$now}',
      if (event == 'start') 'configuration': _demoConfiguration,
      if (hotMessage != null)
        'hotMessage': '{"id":"hot-$now","text":"$hotMessage",'
            '"timestamp":${now ~/ 1000 + 30}}',
    };

    await PPGLiveActivities.instance.simulatePush(envelope);
    _updateStatus(
      "🧪 simulatePush($event) sent — Android only",
      color: Colors.purple,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PPG SDK Example'),
      ),
      body: Column(
        children: [
          // Status block - always visible at top
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _statusColor.withOpacity(0.2),
            child: Row(
              children: [
                Icon(
                  _statusColor == Colors.green
                      ? Icons.check_circle
                      : _statusColor == Colors.red
                          ? Icons.error
                          : _statusColor == Colors.orange
                              ? Icons.hourglass_empty
                              : Icons.info,
                  color: _statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Navigation section
                  const Text("Navigation",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Go to detail screen"),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/details'),
                          builder: (context) => const DetailScreen(),
                        ),
                      );
                      _updateStatus("Navigated to /details",
                          color: Colors.blue);
                    },
                  ),

                  const Divider(height: 32),

                  // Push Notifications section
                  const Text("Push Notifications",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Register for notifications"),
                    onPressed: () async {
                      _updateStatus("⏳ Registering for notifications...",
                          color: Colors.orange);
                      var result =
                          await widget.pushpushgo.registerForNotifications();
                      if (result == ResponseStatus.success) {
                        _updateStatus(
                            "✅ Registered successfully!\nPush notifications enabled.",
                            color: Colors.green);
                      } else {
                        _updateStatus(
                          "❌ Registration failed\n"
                          "Possible reasons:\n"
                          "• User denied notification permissions\n"
                          "• Notifications disabled in Settings\n"
                          "• Check Xcode console for details",
                          color: Colors.red,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Unregister from notifications"),
                    onPressed: () async {
                      _updateStatus("⏳ Unregistering from notifications...",
                          color: Colors.orange);
                      var result =
                          await widget.pushpushgo.unregisterFromNotifications();
                      if (result == ResponseStatus.success) {
                        _updateStatus(
                            "✅ Unregistered successfully!\nPush notifications disabled.",
                            color: Colors.green);
                      } else {
                        _updateStatus(
                          "❌ Unregistration failed\n"
                          "Check Xcode console for details",
                          color: Colors.red,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Get subscriber ID"),
                    onPressed: () async {
                      _updateStatus("⏳ Getting subscriber ID...",
                          color: Colors.orange);
                      var result = await widget.pushpushgo.getSubscriberId();
                      if (result != null && result.isNotEmpty) {
                        _updateStatus("📋 Subscriber ID:\n$result",
                            color: Colors.blue);
                        log('Subscriber ID: $result');
                      } else {
                        _updateStatus("⚠️ No subscriber ID (not registered)",
                            color: Colors.orange);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Send beacon"),
                    onPressed: () async {
                      _updateStatus(
                          "⏳ Sending beacon with tags and selectors...",
                          color: Colors.orange);
                      var result = await widget.pushpushgo.sendBeacon(Beacon(
                          tags: {
                            Tag.fromString("my:tag"),
                            Tag(
                                key: "test_key",
                                value: "test_value",
                                strategy: "append",
                                ttl: 1000)
                          },
                          tagsToDelete: {},
                          customId: "flutter_test_user",
                          selectors: {"platform": "flutter", "test": "true"}));
                      if (result != null) {
                        _updateStatus(
                          "✅ Beacon sent successfully!\n"
                          "Tags: my:tag, test_key:test_value\n"
                          "CustomId: flutter_test_user\n"
                          "Response: $result",
                          color: Colors.green,
                        );
                        log('Beacon result: $result');
                      } else {
                        _updateStatus(
                          "❌ Beacon failed\n"
                          "Possible reasons:\n"
                          "• Device not registered\n"
                          "• Network error\n"
                          "• Check Xcode console for details",
                          color: Colors.red,
                        );
                      }
                    },
                  ),

                  const Divider(height: 32),

                  // In-App Messages section
                  const Text("In-App Messages",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Trigger custom action"),
                    onPressed: () {
                      PPGInAppMessages.instance.showMessagesOnTrigger(
                        key: "action",
                        value: "test_button_clicked",
                      );
                      _updateStatus(
                        "🎯 Trigger sent!\n"
                        "Key: action\n"
                        "Value: test_button_clicked\n\n"
                        "If a matching In-App Message exists, it will be displayed.",
                        color: Colors.purple,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Clear message cache"),
                    onPressed: () async {
                      await PPGInAppMessages.instance.clearMessageCache();
                      _updateStatus(
                        "🗑️ Message cache cleared!\n"
                        "All cached In-App Messages have been removed.\n"
                        "Messages will be fetched again on next route change.",
                        color: Colors.grey,
                      );
                    },
                  ),

                  const Divider(height: 32),

                  // Live Activities section
                  const Text("Live Activities",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _liveNotificationController,
                    decoration: const InputDecoration(
                      labelText: "Live notification ID",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Check support"),
                    onPressed: () async {
                      final supported =
                          await PPGLiveActivities.instance.isSupported();
                      _updateStatus(
                        supported
                            ? "✅ Live Activities are supported on this device"
                            : "⚠️ Live Activities not available\n"
                                "Requires Android 16 (API 36) or iOS 17.2+,\n"
                                "and must be enabled in system settings.",
                        color: supported ? Colors.green : Colors.orange,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Subscribe"),
                    onPressed: () async {
                      final id = _liveNotificationController.text.trim();
                      if (id.isEmpty) {
                        _updateStatus("⚠️ Enter a live notification ID first",
                            color: Colors.orange);
                        return;
                      }

                      _updateStatus("⏳ Subscribing to $id...",
                          color: Colors.orange);
                      try {
                        final subscriberId =
                            await PPGLiveActivities.instance.subscribe(id);
                        _updateStatus(
                          "✅ Subscribed to $id"
                          "${subscriberId != null ? "\nSubscriber: $subscriberId" : ""}",
                          color: Colors.green,
                        );
                      } catch (e) {
                        _updateStatus("❌ Subscribe failed\n$e",
                            color: Colors.red);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Unsubscribe"),
                    onPressed: () async {
                      final id = _liveNotificationController.text.trim();
                      if (id.isEmpty) {
                        _updateStatus("⚠️ Enter a live notification ID first",
                            color: Colors.orange);
                        return;
                      }

                      _updateStatus("⏳ Unsubscribing from $id...",
                          color: Colors.orange);
                      try {
                        await PPGLiveActivities.instance.unsubscribe(id);
                        _updateStatus("✅ Unsubscribed from $id",
                            color: Colors.green);
                      } catch (e) {
                        _updateStatus("❌ Unsubscribe failed\n$e",
                            color: Colors.red);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("List active activities"),
                    onPressed: () async {
                      final activities = await PPGLiveActivities.instance
                          .getActiveActivities();
                      if (activities.isEmpty) {
                        _updateStatus("ℹ️ No active Live Activities",
                            color: Colors.grey);
                        return;
                      }

                      _updateStatus(
                        "📋 Active Live Activities:\n"
                        "${activities.join("\n")}",
                        color: Colors.teal,
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    "Simulate a campaign (Android only, no backend needed)",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Simulate: start"),
                    onPressed: () => _simulateLiveActivityPush(
                      event: "start",
                      homeScore: 0,
                      awayScore: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Simulate: goal (update)"),
                    onPressed: () => _simulateLiveActivityPush(
                      event: "update",
                      homeScore: 1,
                      awayScore: 0,
                      hotMessage: "GOAL!",
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Simulate: end"),
                    onPressed: () => _simulateLiveActivityPush(
                      event: "end",
                      homeScore: 1,
                      awayScore: 0,
                      phase: "FULL_TIME",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Screen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const Center(child: Text("Detail screen")),
    );
  }
}
