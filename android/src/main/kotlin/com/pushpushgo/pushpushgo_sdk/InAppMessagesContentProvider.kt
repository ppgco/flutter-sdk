package com.pushpushgo.pushpushgo_sdk

import android.app.Application
import android.content.ContentProvider
import android.content.ContentValues
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.util.Log
import com.pushpushgo.inappmessages.InAppMessagesSDK

/**
 * ContentProvider that initializes InAppMessagesSDK early in the app lifecycle.
 * This ensures ActivityLifecycleCallbacks are registered before Activity.onResume().
 * 
 * Configuration is read from AndroidManifest.xml meta-data:
 * - com.pushpushgo.inapp.projectId (required)
 * - com.pushpushgo.inapp.apiKey (required)
 * - com.pushpushgo.inapp.isDebug (optional, default: false)
 * - com.pushpushgo.inapp.baseUrl (optional, for staging environment)
 */
class InAppMessagesContentProvider : ContentProvider() {

    companion object {
        private const val TAG = "InAppMsgProvider"
        
        // Meta-data keys
        private const val META_PROJECT_ID = "com.pushpushgo.inapp.projectId"
        private const val META_API_KEY = "com.pushpushgo.inapp.apiKey"
        private const val META_IS_DEBUG = "com.pushpushgo.inapp.isDebug"
        private const val META_BASE_URL = "com.pushpushgo.inapp.baseUrl"
        
        // Flag to check if SDK was initialized by ContentProvider
        @Volatile
        var isEarlyInitialized: Boolean = false
            private set
    }

    override fun onCreate(): Boolean {
        val ctx = context?.applicationContext ?: return false
        
        try {
            val application = ctx as Application
            val metadata = ctx.packageManager
                .getApplicationInfo(ctx.packageName, PackageManager.GET_META_DATA)
                .metaData
            
            // Check if meta-data is configured
            if (metadata == null) {
                Log.d(TAG, "No meta-data found, skipping early initialization")
                return true
            }
            
            val projectId = metadata.getString(META_PROJECT_ID)
            val apiKey = metadata.getString(META_API_KEY)
            
            // If required config is missing, skip early init (will be initialized from Dart)
            if (projectId.isNullOrEmpty() || apiKey.isNullOrEmpty()) {
                Log.d(TAG, "Missing projectId or apiKey in meta-data, skipping early initialization")
                return true
            }
            
            val isDebug = metadata.getBoolean(META_IS_DEBUG, false)
            val baseUrl = metadata.getString(META_BASE_URL)
            
            Log.d(TAG, "Early initializing InAppMessagesSDK (projectId: $projectId, debug: $isDebug)")
            
            InAppMessagesSDK.initialize(
                application = application,
                projectId = projectId,
                apiKey = apiKey,
                debug = isDebug,
                baseUrl = baseUrl
            )
            
            isEarlyInitialized = true
            Log.d(TAG, "InAppMessagesSDK early initialization complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to early initialize InAppMessagesSDK", e)
        }
        
        return true
    }

    override fun getType(uri: Uri): String? = null

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int = 0
}
