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

        /**
         * Bring the native SDK up from the credentials stored on the previous
         * run, before Flutter starts.
         *
         * @return true when the SDK is ready to use.
         */
        fun initialize(application: Application): Boolean {
            val prefs = PpgSharedPrefs()
            val context = application.applicationContext
            val creds = prefs.getCredentials(context)
            val apiToken = creds["apiToken"].orEmpty()
            val projectId = creds["projectId"].orEmpty()

            // First run: nothing stored yet, Flutter will initialize the SDK.
            if (apiToken.isEmpty() || projectId.isEmpty()) return false

            return try {
                PushPushGo.getInstance(
                    application = application,
                    apiKey = apiToken,
                    projectId = projectId,
                    isProduction = prefs.getIsProduction(context),
                    isDebug = prefs.getIsDebug(context)
                )

                // Re-apply notification handler override based on persisted flag,
                // so that link opening is suppressed before Flutter side initializes.
                applyNotificationLinkHandlerOverride(context)

                true
            } catch (e: Exception) {
                // Written by a build that did not validate credentials before
                // storing them. Clear them so the next launch takes the
                // first-run path instead of failing here again.
                Log.e("PpgHelpers", "Stored credentials rejected, clearing them: ${e.message}")
                prefs.clearCredentials(context)
                false
            }
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