package com.pushpushgo.pushpushgo_sdk_example

import android.app.Application
import com.pushpushgo.pushpushgo_sdk.PushPushGoHelpers

class MainApplication : Application() {
    override fun onCreate() {
        PushPushGoHelpers.initialize(this)
        super.onCreate()
    }
}
