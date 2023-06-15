package com.pushpushgo.pushpushgo_sdk_example

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import android.util.Log
import com.pushpushgo.pushpushgo_sdk.PushPushGoHelpers

class MainActivity: FlutterActivity() {
   override fun onCreate(savedInstanceState: Bundle?) {
       super.onCreate(savedInstanceState)
       Log.d("AAA", "on Create from main activity")
       PushPushGoHelpers.onCreate(this.application, intent, savedInstanceState)
   }

    override fun onNewIntent(intent: Intent) {
        Log.d("AAA", "ON NEW INTENT")
        PushPushGoHelpers.onNewIntent(this.application, intent)
    }

}
