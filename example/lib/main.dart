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

class _MyAppState extends State<MyApp> {
  
  final _pushpushgo = PushpushgoSdk({
    "apiToken": "my-api-key", 
    "projectId": "my-project-id"
  });

  @override
  void initState() {
    super.initState();
    initialize();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initialize() async {
    // Initialize Push Notifications SDK
    _pushpushgo.initialize(
      onNewSubscriptionHandler: (subscriberId) {
        log("MY SUBSCRIBER ID IS");
        log(subscriberId);
      }
    );

    // Initialize In-App Messages SDK
    await PPGInAppMessages.instance.initialize(
      apiKey: "my-api-key",
      projectId: "my-project-id",
      isDebug: true,
    );

    // Set up custom code action handler
    PPGInAppMessages.instance.setCustomCodeActionHandler((code) {
      log("Custom code action received: $code");
      // Handle custom code actions here
      // e.g., navigate to specific screen, apply discount, etc.
    });

    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

class HomeScreen extends StatelessWidget {

  final PushpushgoSdk pushpushgo;

  const HomeScreen({
    super.key, 
    required this.pushpushgo,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            Center(
              child: ElevatedButton(
                  child: const Text("Go to detail screen"),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DetailScreen(),
                      ),
                    );
                  })
            ),
            Center(
              child: ElevatedButton(
                  child: const Text("Get subscriber id"),
                  onPressed: () async {
                    var result = await pushpushgo.getSubscriberId();
                    log('get subscriber id result');
                    log(result as String);
                  })
            ),
            Center(
              child: ElevatedButton(
                  child: const Text("Send random beacon"),
                  onPressed: () async {
                    var result = await pushpushgo.sendBeacon(Beacon(
                      tags: {
                        Tag.fromString("my:tag"),
                        Tag(
                          key: "myaa",
                          value: "aaaa",
                          strategy: "append",
                          ttl: 1000
                        )
                      },
                      tagsToDelete: {},
                      customId: "my_id",
                      selectors: {
                        "my": "data"
                      }
                    ));
                    log('beacon result');
                    log(result as String);
                  })
            ),
            Center(
              child: ElevatedButton(
                  child: const Text("Register"),
                  onPressed: () {
                    pushpushgo.registerForNotifications();
                  })
            ),
            Center(
              child: ElevatedButton(
                  child: const Text("Unregister"),
                  onPressed: () {
                    pushpushgo.unregisterFromNotifications();
                  })
            ),
            const Divider(height: 32),
            const Text("In-App Messages", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton(
                  child: const Text("Show custom trigger"),
                  onPressed: () {
                    PPGInAppMessages.instance.showMessagesOnTrigger(
                      key: "action",
                      value: "test_button_clicked",
                    );
                  })
            ),
            Center(
              child: ElevatedButton(
                  child: const Text("Clear message cache"),
                  onPressed: () {
                    PPGInAppMessages.instance.clearMessageCache();
                    log("Message cache cleared");
                  })
            ),
          ],
        )
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: const Center(child: Text("Detail screen")),
      ),
    );
  }
}
