package com.pushpushgo.pushpushgo_sdk

import android.app.Application
import android.content.ContentProvider
import android.content.ContentValues
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.util.Log
import com.pushpushgo.sdk.PushPushGo

/**
 * ContentProvider that initializes PushPushGo SDK early in the app lifecycle.
 * This prevents crashes when FCM sends onNewToken() before Flutter SDK initialization.
 * 
 * Configuration can be provided via:
 * 1. AndroidManifest.xml meta-data (recommended for preventing cold-start crashes):
 *    - com.pushpushgo.sdk.projectId (required)
 *    - com.pushpushgo.sdk.apiKey (required)
 *    - com.pushpushgo.sdk.isProduction (optional, default: true)
 *    - com.pushpushgo.sdk.isDebug (optional, default: false)
 * 
 * 2. SharedPreferences (set by Flutter SDK after first initialization)
 * 
 * If meta-data is not configured and SharedPreferences are empty (first run),
 * initialization will be skipped and handled later by Flutter SDK.
 */
class PushPushGoContentProvider : ContentProvider() {

    companion object {
        private const val TAG = "PpgContentProvider"
        
        private const val META_PROJECT_ID = "com.pushpushgo.sdk.projectId"
        private const val META_API_KEY = "com.pushpushgo.sdk.apiKey"
        private const val META_IS_PRODUCTION = "com.pushpushgo.sdk.isProduction"
        private const val META_IS_DEBUG = "com.pushpushgo.sdk.isDebug"
        
        @Volatile
        var isEarlyInitialized: Boolean = false
            private set
    }

    override fun onCreate(): Boolean {
        val ctx = context?.applicationContext ?: return false
        
        try {
            val application = ctx as Application
            
            // Try to get config from meta-data first
            val metadata = try {
                ctx.packageManager
                    .getApplicationInfo(ctx.packageName, PackageManager.GET_META_DATA)
                    .metaData
            } catch (e: Exception) {
                null
            }
            
            var projectId: String? = null
            var apiKey: String? = null
            var isProduction = true
            var isDebug = false
            
            // Check meta-data first
            if (metadata != null) {
                projectId = metadata.getString(META_PROJECT_ID)
                apiKey = metadata.getString(META_API_KEY)
                isProduction = metadata.getBoolean(META_IS_PRODUCTION, true)
                isDebug = metadata.getBoolean(META_IS_DEBUG, false)
            }
            
            // If meta-data not configured, try SharedPreferences (from previous Flutter init)
            if (projectId.isNullOrEmpty() || apiKey.isNullOrEmpty()) {
                val prefs = PpgSharedPrefs()
                val creds = prefs.getCredentials(ctx)
                
                if (creds["apiToken"] != "" && creds["projectId"] != "") {
                    projectId = creds["projectId"] as? String
                    apiKey = creds["apiToken"] as? String
                    isProduction = prefs.getIsProduction(ctx)
                    isDebug = prefs.getIsDebug(ctx)
                    Log.d(TAG, "Using credentials from SharedPreferences")
                }
            } else {
                Log.d(TAG, "Using credentials from AndroidManifest meta-data")
            }
            
            // If still no credentials, skip initialization (first run without meta-data)
            if (projectId.isNullOrEmpty() || apiKey.isNullOrEmpty()) {
                Log.d(TAG, "No credentials available, skipping early initialization. " +
                    "Add meta-data to AndroidManifest.xml to prevent cold-start crashes.")
                return true
            }
            
            Log.d(TAG, "Early initializing PushPushGo SDK (projectId: $projectId, production: $isProduction, debug: $isDebug)")
            
            PushPushGo.getInstance(
                application = application,
                apiKey = apiKey,
                projectId = projectId,
                isProduction = isProduction,
                isDebug = isDebug
            )
            
            isEarlyInitialized = true
            Log.d(TAG, "PushPushGo SDK early initialization complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to early initialize PushPushGo SDK: ${e.message}")
        }
        
        return true
    }

    override fun getType(uri: Uri): String? = null
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0
}
