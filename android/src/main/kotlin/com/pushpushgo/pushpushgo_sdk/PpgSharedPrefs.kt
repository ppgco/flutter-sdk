package com.pushpushgo.pushpushgo_sdk

import android.content.Context
import android.content.SharedPreferences

class PpgSharedPrefs {

    // Function to get SharedPreferences instance
    private fun getSharedPreferences(context: Context): SharedPreferences {
        return context.getSharedPreferences("PpgSharedPrefs", Context.MODE_PRIVATE)
    }

    // Function to save a string value in SharedPreferences
    private fun saveString(context: Context, key: String, value: String) {
        val sharedPreferences = getSharedPreferences(context)
        val editor = sharedPreferences.edit()
        editor.putString(key, value)
        editor.apply()
    }

    // Function to retrieve a string value from SharedPreferences
    private fun getString(context: Context, key: String, defaultValue: String): String {
        val sharedPreferences = getSharedPreferences(context)
        return sharedPreferences.getString(key, defaultValue) ?: defaultValue
    }

    fun setCredentials(context: Context, credentials: Map<String, String>) {
        saveString(context, "apiToken", credentials["apiToken"] as String)
        saveString(context, "projectId", credentials["projectId"] as String)
    }

    fun getCredentials(context: Context): Map<String, String> {
        val apiToken: String = getString(context, "apiToken", "")
        val projectId: String = getString(context, "projectId", "")

        return mapOf(
            "apiToken" to apiToken,
            "projectId" to projectId
        )
    }

    fun setHandleNotificationLink(context: Context, handleLink: Boolean) {
        saveString(context, "handleNotificationLink", handleLink.toString())
    }

    fun getHandleNotificationLink(context: Context): Boolean {
        return getString(context, "handleNotificationLink", "true") == "true"
    }
}

