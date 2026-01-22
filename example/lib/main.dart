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
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class _MyAppState extends State<MyApp> {
  
  final _pushpushgo = PushpushgoSdk({
    "apiToken": "MY_API_KEY", 
    "projectId": "MY_PROJECT_ID",
    "appGroupId": "group.ppg.fluttersdk"
  });

  @override
  void initState() {
    super.initState();
    initialize();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initialize() async {
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
      isProduction: false,  // Use staging API (api.master1.qappg.co)
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
      apiKey: "d362ffa4-caf4-48a9-810e-ac0c7c47d3e3",
      projectId: "692709eac9a8af1af56d923e",
      isProduction: false,  // Use staging API (api.master1.qappg.co)
      isDebug: true,
    );

    // Set up custom code action handler
    PPGInAppMessages.instance.setCustomCodeActionHandler((code) {
      log("Custom code action received: $code");
      _handleCustomCode(code);
    });

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
              content: const Text('This dialog was triggered by an In-App Message custom code action.'),
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

class _HomeScreenState extends State<HomeScreen> {
  String _statusMessage = "Ready";
  Color _statusColor = Colors.grey;

  void _updateStatus(String message, {Color? color}) {
    setState(() {
      _statusMessage = message;
      _statusColor = color ?? Colors.blue;
    });
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
                  _statusColor == Colors.green ? Icons.check_circle :
                  _statusColor == Colors.red ? Icons.error :
                  _statusColor == Colors.orange ? Icons.hourglass_empty :
                  Icons.info,
                  color: _statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _statusColor.withOpacity(1),
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
                  const Text("Navigation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      _updateStatus("Navigated to /details", color: Colors.blue);
                    },
                  ),
                  
                  const Divider(height: 32),
                  
                  // Push Notifications section
                  const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Register for notifications"),
                    onPressed: () async {
                      _updateStatus("⏳ Registering for notifications...", color: Colors.orange);
                      var result = await widget.pushpushgo.registerForNotifications();
                      if (result == ResponseStatus.success) {
                        _updateStatus("✅ Registered successfully!\nPush notifications enabled.", color: Colors.green);
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
                      _updateStatus("⏳ Unregistering from notifications...", color: Colors.orange);
                      var result = await widget.pushpushgo.unregisterFromNotifications();
                      if (result == ResponseStatus.success) {
                        _updateStatus("✅ Unregistered successfully!\nPush notifications disabled.", color: Colors.green);
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
                      _updateStatus("⏳ Getting subscriber ID...", color: Colors.orange);
                      var result = await widget.pushpushgo.getSubscriberId();
                      if (result != null && result.isNotEmpty) {
                        _updateStatus("📋 Subscriber ID:\n$result", color: Colors.blue);
                        log('Subscriber ID: $result');
                      } else {
                        _updateStatus("⚠️ No subscriber ID (not registered)", color: Colors.orange);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    child: const Text("Send beacon"),
                    onPressed: () async {
                      _updateStatus("⏳ Sending beacon with tags and selectors...", color: Colors.orange);
                      var result = await widget.pushpushgo.sendBeacon(Beacon(
                        tags: {
                          Tag.fromString("my:tag"),
                          Tag(
                            key: "test_key",
                            value: "test_value",
                            strategy: "append",
                            ttl: 1000
                          )
                        },
                        tagsToDelete: {},
                        customId: "flutter_test_user",
                        selectors: {
                          "platform": "flutter",
                          "test": "true"
                        }
                      ));
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
                  const Text("In-App Messages", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
