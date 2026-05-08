package com.pushpushgo.pushpushgo_sdk

import android.app.Application
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.pushpushgo.sdk.PushPushGo

class PushPushGoHelpers {
    companion object {

        /**
         * Applies a no-op notification link handler when handleNotificationLink == false.
         * This prevents the native SDK from opening the URL while still allowing click
         * tracking via handleBackgroundNotificationClick().
         */
        internal fun applyNotificationLinkHandlerOverride(context: android.content.Context) {
            val prefs = PpgSharedPrefs()
            if (!prefs.getHandleNotificationLink(context)) {
                try {
                    PushPushGo.getInstance().notificationHandler = { _, url, _ ->
                        Log.d("PpgHelpers", "Link click intercepted (not opening): $url")
                    }
                } catch (e: Exception) {
                    Log.w("PpgHelpers", "Cannot apply notification handler override: ${e.message}")
                }
            }
        }

        fun initialize(application: Application): Boolean {
            val prefs = PpgSharedPrefs()
            val context = application.applicationContext
            val creds = prefs.getCredentials(context)

            if (creds["apiToken"] != "" && creds["projectId"] != "") {
                val isProduction = prefs.getIsProduction(context)
                val isDebug = prefs.getIsDebug(context)

                PushPushGo.getInstance(
                    application = application,
                    apiKey = if (creds["apiToken"] is String) creds["apiToken"] as String else throw Exception("apiToken is is required"),
                    projectId = if (creds["projectId"] is String) creds["projectId"] as String else throw Exception("projectId is is required"),
                    isProduction = isProduction,
                    isDebug = isDebug
                )

                // Re-apply notification handler override based on persisted flag,
                // so that link opening is suppressed before Flutter side initializes.
                applyNotificationLinkHandlerOverride(context)

                return true
            }

            return false
        }

        fun onNewIntent(application: Application, intent: Intent) {
            if (PushPushGoHelpers.initialize(application)) {
                // Always track click. Link opening is controlled by notificationHandler
                // override applied in initialize() based on handleNotificationLink flag.
                PushPushGo.getInstance().handleBackgroundNotificationClick(intent)
            }
        }

        fun onCreate(application: Application, intent: Intent?, savedInstanceState: Bundle?) {
            if (savedInstanceState == null) {
                if (PushPushGoHelpers.initialize(application)) {
                    // Always track click. Link opening is controlled by notificationHandler
                    // override applied in initialize() based on handleNotificationLink flag.
                    PushPushGo.getInstance().handleBackgroundNotificationClick(intent)
                }
            }
        }
    }
}