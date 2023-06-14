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
  final _pushpushgo = PushpushgoSdk();

  @override
  void initState() {
    super.initState();
    initializePpgCore();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initializePpgCore() async {
    // TBD Logic
    _pushpushgo.initialize(
      options: {"apiToken": "b63f3498-cf98-4b71-b6bd-c47abb45c650", "projectId": "64899899acc4724e338f8ad4"}, 
      onNewSubscriptionHandler: (subscriberId) {
        log("MY SUBSCRIBER ID IS");
        log(subscriberId);
      }
    );

    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
                        Tag.fromString("my:tag")
                      },
                      tagsToDelete: {},
                      customId: "my_id",
                      selectors: {
                        "my": "data"
                      }
                    ));
                    log('get subscriber id result');
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
