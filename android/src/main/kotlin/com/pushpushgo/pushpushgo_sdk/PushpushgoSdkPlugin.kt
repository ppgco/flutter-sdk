package com.pushpushgo.pushpushgo_sdk

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.firebase.FirebaseApp
import com.pushpushgo.sdk.PushPushGo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/** PpgCorePlugin */

enum class MethodIdentifier {
  initialize,
  registerForNotifications,
  unregisterFromNotifications,
  getSubscriberId,
  sendBeacon,
  getCredentials,
  onNewSubscription,
  onNotificationClicked;
  companion object {
    fun create(name: String): MethodIdentifier {
      return values().find { it.name.equals(name, ignoreCase = true) }
        ?: throw IllegalArgumentException("Invalid process state: $name")
    }
  }

}

class PushpushgoSdkPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.NewIntentListener {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private lateinit var sharedPrefs: PpgSharedPrefs
  private var activity: Activity? = null
  private var pendingNotificationData: Map<String, Any?>? = null
  private var isInitialized = false

  companion object {
    private const val PPG_PUSH_CAMPAIGN_KEY = "campaign"
    private const val PPG_PUSH_PROJECT_KEY = "project"
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.pushpushgo/sdk")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    sharedPrefs = PpgSharedPrefs()
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addOnNewIntentListener(this)
    // Check if app was launched from notification
    handleIntent(binding.activity.intent)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addOnNewIntentListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onNewIntent(intent: Intent): Boolean {
    handleIntent(intent)
    return false
  }

  private fun handleIntent(intent: Intent?) {
    intent?.let {
      val extras = it.extras
      if (extras != null && (extras.containsKey(PPG_PUSH_CAMPAIGN_KEY) || extras.containsKey(PPG_PUSH_PROJECT_KEY))) {
        val notificationData = mutableMapOf<String, Any?>()
        for (key in extras.keySet()) {
          val value = extras.get(key)
          // Only include serializable types (skip Bundle and other complex types)
          if (value is String || value is Number || value is Boolean) {
            notificationData[key] = value
          }
        }
        sendNotificationClickedEvent(notificationData)
      }
    }
  }

  private fun sendNotificationClickedEvent(data: Map<String, Any?>) {
    pendingNotificationData = data
    if (isInitialized) {
      trySendPendingNotification()
    }
  }

  private fun trySendPendingNotification() {
    pendingNotificationData?.let { data ->
      channel.invokeMethod(MethodIdentifier.onNotificationClicked.name, data)
      pendingNotificationData = null
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (MethodIdentifier.create(call.method)) {
      MethodIdentifier.initialize -> {
        try {
          FirebaseApp.initializeApp(context.applicationContext)
          val apiToken = call.argument<String>("apiToken") ?: throw Exception("apiToken is is required");
          val projectId = call.argument<String>("projectId") ?: throw Exception("projectId is is required");

          PushPushGo.getInstance(
            application = context.applicationContext as Application,
            apiKey = apiToken,
            projectId = projectId,
            isProduction = call.argument<Boolean>("isProduction") ?: true,
            isDebug = call.argument<Boolean>("isDebug") ?: false,
          );

          sharedPrefs.setCredentials(context, mapOf(
            "apiToken" to apiToken,
            "projectId" to projectId
          ))

          // Mark as initialized and send any pending notification data
          isInitialized = true
          trySendPendingNotification()

          result.success("success")
        } catch(error: Exception) {
          result.error("error", error.message, error.cause)
        }
      }
      MethodIdentifier.getSubscriberId -> {
        result.success(PushPushGo.getInstance().getSubscriberId())
      }
      MethodIdentifier.sendBeacon -> {
          val stringValue = call.arguments as? String
          if (stringValue == null) {
            Log.w("PpgBeaconTranslate", "value is not a string, omit")
            return result.error("error", "value is not a string, omit", "options is required")
          }

          val parsedJSON = try {
            JSONObject(stringValue)
          } catch (e: JSONException) {
            Log.w("PpgBeaconTranslate", "cannot parse JSON, omit sending beacon")
            return result.error("error", "cannot parse JSON, omit sending beacon", "unable to parse json")
          }

          val beacon = PushPushGo.getInstance().createBeacon()

          val tagsRaw = parsedJSON.optJSONArray("tags") ?: JSONArray();
          for (i in 0 until tagsRaw.length()) {
            val it = tagsRaw.optJSONObject(i)
            val key = it["key"] as? String
            val value = it["value"] as? String
            val strategy = it["strategy"] ?: ""
            val ttl = it["ttl"] ?: 0

            if (key != null && value != null) {
              beacon.appendTag(value, key, strategy as String, ttl as Int)
            } else {
              Log.w("PpgBeaconTranslate", "cannot parse to string key or value, omit")
            }
          }

          val tagsToDeleteRaw = parsedJSON.optJSONArray("tagsToDelete") ?: JSONArray();

          for (i in 0 until tagsToDeleteRaw.length()) {
            val it = tagsToDeleteRaw.optJSONObject(i)
            val key = it["key"] as? String
            val value = it["value"] as? String

            if (value == null && key != null) {
              beacon.removeTag(key)
            } else {
              beacon.removeTag("${key}:${value}")
            }
          }

          val selectorsRaw = parsedJSON.optJSONObject("selectors")

          selectorsRaw?.let { selectors ->
            val keys = selectors.keys()
            while (keys.hasNext()) {
              val key = keys.next()
              val value = selectors.optString(key)
              beacon.set(key as String, value ?: "")
            }
          } ?: Log.w("PpgBeaconTranslate", "cannot parse selectors")

          val customId = parsedJSON["customId"] as? String
          customId?.let { beacon.setCustomId(it) } ?: Log.w("PpgBeaconTranslate", "cannot parse custom id")

          val assignToGroup = parsedJSON.optString("assignToGroup", null)
          assignToGroup?.let { beacon.assignToGroup(it) }

          val unassignFromGroup = parsedJSON.optString("unassignFromGroup", null)
          unassignFromGroup?.let { beacon.unassignFromGroup(it) }

          beacon.send()
          result.success("success")
      }
      MethodIdentifier.unregisterFromNotifications -> {
        PushPushGo.getInstance().unregisterSubscriber()
        result.success("success")
      }
      MethodIdentifier.registerForNotifications -> {
        Futures.addCallback(PushPushGo.getInstance().createSubscriber(), object : FutureCallback<String> {
          override fun onSuccess(sub: String?) {
            result.success("success")
            channel.invokeMethod(MethodIdentifier.onNewSubscription.toString(), sub)
          }

          override fun onFailure(t: Throwable) {
            Log.d("Ppg", t.message.toString())
            result.error("error", t.message.toString(), t.cause.toString())
          }
        }, ContextCompat.getMainExecutor(context))
      }
      else -> result.notImplemented()
    }
  }
}