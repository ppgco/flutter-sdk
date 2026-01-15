package com.pushpushgo.pushpushgo_sdk

import android.app.Application
import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.firebase.FirebaseApp
import com.pushpushgo.sdk.PushPushGo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
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
  onNewSubscription;
  companion object {
    fun create(name: String): MethodIdentifier {
      return values().find { it.name.equals(name, ignoreCase = true) }
        ?: throw IllegalArgumentException("Invalid process state: $name")
    }
  }

}

class PushpushgoSdkPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private lateinit var sharedPrefs: PpgSharedPrefs
  private val inAppMessagesPlugin = InAppMessagesPlugin()
  
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.pushpushgo/sdk")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    sharedPrefs = PpgSharedPrefs()
    
    // Register In-App Messages plugin
    inAppMessagesPlugin.onAttachedToEngine(flutterPluginBinding)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    inAppMessagesPlugin.onDetachedFromEngine(binding)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (MethodIdentifier.create(call.method)) {
      MethodIdentifier.initialize -> {
        try {
          FirebaseApp.initializeApp(context.applicationContext)
          val apiToken = call.argument<String>("apiToken") ?: throw Exception("apiToken is is required");
          val projectId = call.argument<String>("projectId") ?: throw Exception("projectId is is required");

          val isProduction = call.argument<Boolean>("isProduction") ?: true
          val isDebug = call.argument<Boolean>("isDebug") ?: false

          PushPushGo.getInstance(
            application = context.applicationContext as Application,
            apiKey = apiToken,
            projectId = projectId,
            isProduction = isProduction,
            isDebug = isDebug,
          );

          sharedPrefs.setCredentials(context, mapOf(
            "apiToken" to apiToken,
            "projectId" to projectId
          ))
          sharedPrefs.setEnvironmentConfig(context, isProduction, isDebug)

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