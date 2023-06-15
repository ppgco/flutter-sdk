package com.pushpushgo.pushpushgo_sdk_example;

import com.pushpushgo.pushpushgo_sdk.PushPushGoHelpers
import io.flutter.app.FlutterApplication

class MainApplication: FlutterApplication() {
    override fun onCreate() {
        PushPushGoHelpers.initialize(this)
        super.onCreate()
    }
}