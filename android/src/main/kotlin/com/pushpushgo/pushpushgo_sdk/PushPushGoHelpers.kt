package com.pushpushgo.pushpushgo_sdk

import android.app.Application
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.pushpushgo.sdk.PushPushGo

class PushPushGoHelpers {
    companion object {

        fun onNewIntent(application: Application, intent: Intent) {
            Log.d("AAA", "ON NEW INTENT FROM DELEGATE")
            val prefs = PpgSharedPrefs()
            val creds = prefs.getCredentials(application.applicationContext);
            if (creds["apiToken"] != "" && creds["projectId"] != "") {
                Log.d("CREDENTIALS", creds.toString())
                PushPushGo.getInstance(
                    application = application,
                    apiKey = if (creds["apiToken"] is String) creds["apiToken"] as String else throw Exception("apiToken is is required"),
                    projectId = if (creds["projectId"] is String) creds["projectId"] as String else throw Exception("projectId is is required"),
                    isProduction = true,
                    isDebug = false
                )
                PushPushGo.getInstance().handleBackgroundNotificationClick(intent);
            }
        }

        fun onCreate(application: Application, intent: Intent?, savedInstanceState: Bundle?) {
            if (savedInstanceState == null) {
                Log.d("AAA", "ON CREATE FROM DELEGATE")
                val prefs = PpgSharedPrefs()
                val creds = prefs.getCredentials(application.applicationContext);

                if (creds["apiToken"] != "" && creds["projectId"] != "") {
                    Log.d("CREDENTIALS", creds.toString())
                    PushPushGo.getInstance(
                        application = application,
                        apiKey = if (creds["apiToken"] is String) creds["apiToken"] as String else throw Exception("apiToken is is required"),
                        projectId = if (creds["projectId"] is String) creds["projectId"] as String else throw Exception("projectId is is required"),
                        isProduction = true,
                        isDebug = false
                    )
                    PushPushGo.getInstance().handleBackgroundNotificationClick(intent);
                }
            }
        }
    }
}