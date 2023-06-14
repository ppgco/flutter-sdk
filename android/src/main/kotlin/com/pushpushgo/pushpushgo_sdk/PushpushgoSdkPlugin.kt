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
import org.json.JSONException
import org.json.JSONObject

/** PpgCorePlugin */

enum class MethodIdentifier {
  initialize,
  registerForNotifications,
  unregisterFromNotifications,
  getSubscriberId,
  sendBeacon,
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
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.pushpushgo/sdk")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (MethodIdentifier.create(call.method)) {
      MethodIdentifier.initialize -> {
        try {
          FirebaseApp.initializeApp(context.applicationContext)
          PushPushGo.getInstance(
            application = context.applicationContext as Application,
            apiKey = call.argument<String>("apiToken") ?: throw Exception("apiToken is is required"),
            projectId = call.argument<String>("projectId") ?: throw Exception("projectId is is required"),
            isProduction = call.argument<Boolean>("isProduction") ?: true,
            isDebug = call.argument<Boolean>("isDebug") ?: false,
          );
          result.success("success")
        } catch(error: Exception) {
          result.error("error", error.message, error.cause)
        }
      }
      MethodIdentifier.getSubscriberId -> {
        result.success(PushPushGo.getInstance().getSubscriberId())
      }
      MethodIdentifier.sendBeacon -> {
        Log.d("ARGUMENTS", "${call.arguments}")

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

          val tagsRaw = parsedJSON["tags"] as? List<Map<String, Any>>
          tagsRaw?.forEach { it ->
            val key = it["key"] as? String
            val value = it["value"] as? String
            if (key != null && value != null) {
              beacon.appendTag(value, key)
            } else {
              Log.w("PpgBeaconTranslate", "cannot parse to string key or value, omit")
            }
          } ?: Log.w("PpgBeaconTranslate", "cannot parse tags, omit")

          val tagsToDeleteRaw = parsedJSON["tagsToDelete"] as? List<Map<String, Any>>
          tagsToDeleteRaw?.forEach { it ->
            val key = it["key"] as? String
            val value = it["value"] as? String
            if (key != null || value != null) {
              if (value == null && key !== null) {
                beacon.removeTag(key)
              } else {
                beacon.removeTag("${key}:${value}")
              }
            } else {
              Log.w("PpgBeaconTranslate", "cannot parse to string key or value, omit")
            }
          } ?: Log.w("PpgBeaconTranslate", "cannot parse tags to delete")

          val selectorsRaw = parsedJSON["selectors"] as? Map<*, *>
          if (selectorsRaw != null) {
            for ((key, value) in selectorsRaw) {
              beacon.set(key as String, value ?: "")
            }
          } else {
            Log.w("PpgBeaconTranslate", "cannot parse selectors")
          }

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