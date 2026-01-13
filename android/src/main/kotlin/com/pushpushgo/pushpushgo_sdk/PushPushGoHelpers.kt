package com.pushpushgo.pushpushgo_sdk

import android.app.Application
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.pushpushgo.sdk.PushPushGo

class PushPushGoHelpers {
    companion object {

        fun initialize(application: Application): Boolean {
            val prefs = PpgSharedPrefs()
            val creds = prefs.getCredentials(application.applicationContext);

            if (creds["apiToken"] != "" && creds["projectId"] != "") {
                PushPushGo.getInstance(
                    application = application,
                    apiKey = if (creds["apiToken"] is String) creds["apiToken"] as String else throw Exception("apiToken is is required"),
                    projectId = if (creds["projectId"] is String) creds["projectId"] as String else throw Exception("projectId is is required"),
                    isProduction = true,
                    isDebug = false
                )

                return true
            }

            return false
        }

        fun onNewIntent(application: Application, intent: Intent) {
            if (PushPushGoHelpers.initialize(application)) {
                val prefs = PpgSharedPrefs()
                if (prefs.getHandleNotificationLink(application.applicationContext)) {
                    PushPushGo.getInstance().handleBackgroundNotificationClick(intent);
                }
            }
        }

        fun onCreate(application: Application, intent: Intent?, savedInstanceState: Bundle?) {
            if (savedInstanceState == null) {
                if (PushPushGoHelpers.initialize(application)) {
                    val prefs = PpgSharedPrefs()
                    if (prefs.getHandleNotificationLink(application.applicationContext)) {
                        PushPushGo.getInstance().handleBackgroundNotificationClick(intent);
                    }
                }
            }
        }
    }
}