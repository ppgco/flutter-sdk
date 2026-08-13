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
  private val inAppMessagesPlugin = InAppMessagesPlugin()
  private val liveActivitiesPlugin = LiveActivitiesPlugin()
  private var activity: Activity? = null
  private var pendingNotificationData: Map<String, Any?>? = null
  private var pendingLiveActivityIntent: Intent? = null
  private var isInitialized = false

  companion object {
    private const val PPG_PUSH_CAMPAIGN_KEY = "campaign"
    private const val PPG_PUSH_PROJECT_KEY = "project"

    // Live Activity click extras, mirroring LiveActivityHandler in the native
    // SDK — its constants are internal to that module, so they can't be
    // referenced directly.
    private const val PPG_LA_ID_KEY = "live_activity_id"
    private const val PPG_LA_ACTION_INDEX_KEY = "la_action_index"
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.pushpushgo/sdk")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    sharedPrefs = PpgSharedPrefs()
    // Register In-App Messages plugin
    inAppMessagesPlugin.onAttachedToEngine(flutterPluginBinding)
    // Register Live Activities plugin
    liveActivitiesPlugin.onAttachedToEngine(flutterPluginBinding)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    inAppMessagesPlugin.onDetachedFromEngine(binding)
    liveActivitiesPlugin.onDetachedFromEngine(binding)
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
      handleLiveActivityIntent(it)

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

  /**
   * Report a Live Activity click to Dart. The native SDK reports the click
   * statistics and (unless suppressed) opens the deep link; here we only need
   * to forward the result. Handles both cold start (onCreate) and warm start
   * (onNewIntent), so the host app's MainActivity needs no extra code.
   */
  private fun handleLiveActivityIntent(intent: Intent) {
    if (!intent.hasExtra(PPG_LA_ID_KEY)) return

    // The launcher intent can arrive before the SDK is configured on the very
    // first run; hold it until initialize() provides the credentials.
    if (!PushPushGo.isInitialized()) {
      pendingLiveActivityIntent = intent
      return
    }

    processLiveActivityClick(intent)
  }

  private fun processLiveActivityClick(intent: Intent) {
    try {
      val liveActivityId = intent.getStringExtra(PPG_LA_ID_KEY) ?: return
      val actionIndex = intent.getIntExtra(PPG_LA_ACTION_INDEX_KEY, -1)
      val handleLink = sharedPrefs.getHandleNotificationLink(context)

      // Clears the click extras, so the same tap is never reported twice.
      val deepLink = PushPushGo.getInstance().handleLiveActivityClick(intent, handleLink)

      liveActivitiesPlugin.sendClick(liveActivityId, deepLink, actionIndex)
    } catch (error: Exception) {
      Log.e("PpgPlugin", "Failed to handle Live Activity click: ${error.message}")
    }
  }

  private fun trySendPendingLiveActivityClick() {
    pendingLiveActivityIntent?.let { intent ->
      pendingLiveActivityIntent = null
      processLiveActivityClick(intent)
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (MethodIdentifier.create(call.method)) {
      MethodIdentifier.initialize -> {
        try {
          FirebaseApp.initializeApp(context.applicationContext)
          val apiToken = call.argument<String>("apiToken") ?: throw Exception("apiToken is is required");
          val projectId = call.argument<String>("projectId") ?: throw Exception("projectId is is required");

          // Checked here rather than left to the native SDK: getInstance() skips
          // validation when an instance already exists, so bad credentials would
          // be persisted below and crash the next cold start.
          val credentialsError = PpgCredentials.validationError(apiToken, projectId)
          if (credentialsError != null) {
            Log.e("PpgPlugin", "Refusing to initialize: $credentialsError")
            result.error("INVALID_CREDENTIALS", credentialsError, null)
            return
          }

          val isProduction = call.argument<Boolean>("isProduction") ?: true
          val isDebug = call.argument<Boolean>("isDebug") ?: false
          val handleNotificationLinkArg = call.argument<String>("handleNotificationLink")
          val handleNotificationLink = handleNotificationLinkArg?.lowercase() != "false"

          val ppg = PushPushGo.getInstance(
            application = context.applicationContext as Application,
            apiKey = apiToken,
            projectId = projectId,
            isProduction = isProduction,
            isDebug = isDebug,
          )

          // Override Android notification handler if handleNotificationLink is false
          if (!handleNotificationLink) {
            ppg.notificationHandler = { _, url, _ ->
              Log.d("PpgPlugin", "Link click intercepted (not opening): $url")
              // Don't open link - Flutter will handle via onNotificationClickedHandler
            }
          }

          sharedPrefs.setCredentials(context, mapOf(
            "apiToken" to apiToken,
            "projectId" to projectId
          ))
          sharedPrefs.setEnvironmentConfig(context, isProduction, isDebug)
          sharedPrefs.setHandleNotificationLink(context, handleNotificationLink)

          // Mark as initialized and send any pending notification data
          isInitialized = true
          trySendPendingNotification()
          trySendPendingLiveActivityClick()

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
          override fun onSuccess(sub: String) {
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