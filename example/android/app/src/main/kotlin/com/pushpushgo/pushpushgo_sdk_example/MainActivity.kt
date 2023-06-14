package com.pushpushgo.pushpushgo_sdk_example

import android.os.Bundle
import android.content.Intent
import com.pushpushgo.sdk.PushPushGo
import io.flutter.embedding.android.FlutterActivity
import android.util.Log

class MainActivity: FlutterActivity() {
   override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("AAA", "ON CREATE")
        if (savedInstanceState == null) {
            PushPushGo.getInstance(application)
            PushPushGo.getInstance().handleBackgroundNotificationClick(intent);
        }
   }

    // TODO wyniesc to do PushpushgoSdkPlugin.kt jako intent tak jak u nas
    // A z tym wyzej to nie wiem ocb :D mozna wywalic i zobaczyc co sie stanie w teorii, ale to samo jest u nas wiec przy zgaszonej appce nie do konca moize to zadzialac?
    //    Do sprawdzenia ... jebac biede...
   override fun onNewIntent(intent: Intent) {
        Log.d("AAA", "ON NEW INTENT")
        PushPushGo.getInstance().handleBackgroundNotificationClick(intent);
   }
}
