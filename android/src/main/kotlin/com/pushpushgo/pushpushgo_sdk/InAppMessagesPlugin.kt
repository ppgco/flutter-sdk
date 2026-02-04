package com.pushpushgo.pushpushgo_sdk

import android.app.Activity
import android.app.Application
import android.content.Context
import android.util.Log
import com.pushpushgo.inappmessages.InAppMessagesSDK
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin for PushPushGo In-App Messages
 */
class InAppMessagesPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware {

    companion object {
        private const val TAG = "InAppMessagesPlugin"
        private const val METHOD_CHANNEL_NAME = "com.pushpushgo/inappmessages/methods"
        private const val EVENT_CHANNEL_NAME = "com.pushpushgo/inappmessages/events"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null

    // Method identifiers
    private enum class MethodIdentifier {
        initialize,
        onRouteChanged,
        showMessagesOnTrigger,
        setCustomCodeActionHandler,
        clearMessageCache;

        companion object {
            fun fromString(name: String): MethodIdentifier? {
                return values().find { it.name == name }
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        // Setup Method Channel
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        // Setup Event Channel
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(this)

        Log.d(TAG, "InAppMessagesPlugin attached")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        Log.d(TAG, "InAppMessagesPlugin detached")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (MethodIdentifier.fromString(call.method)) {
            MethodIdentifier.initialize -> handleInitialize(call, result)
            MethodIdentifier.onRouteChanged -> handleOnRouteChanged(call, result)
            MethodIdentifier.showMessagesOnTrigger -> handleShowMessagesOnTrigger(call, result)
            MethodIdentifier.setCustomCodeActionHandler -> handleSetCustomCodeActionHandler(result)
            MethodIdentifier.clearMessageCache -> handleClearMessageCache(result)
            null -> result.notImplemented()
        }
    }

    // Method Implementations

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        try {
            // Check if SDK was already initialized by ContentProvider
            if (InAppMessagesContentProvider.isEarlyInitialized) {
                Log.d(TAG, "InAppMessagesSDK already initialized by ContentProvider")
                result.success("success")
                return
            }
            
            val apiKey = call.argument<String>("apiKey")
                ?: return result.error("INVALID_ARGUMENTS", "apiKey is required", null)
            val projectId = call.argument<String>("projectId")
                ?: return result.error("INVALID_ARGUMENTS", "projectId is required", null)

            val isProduction = call.argument<Boolean>("isProduction") ?: true
            val isDebug = call.argument<Boolean>("isDebug") ?: false

            // Determine base URL based on environment
            val baseUrl = if (isProduction) null else "https://api.master1.qappg.co/"

            InAppMessagesSDK.initialize(
                application = context.applicationContext as Application,
                projectId = projectId,
                apiKey = apiKey,
                debug = isDebug,
                baseUrl = baseUrl
            )

            Log.d(TAG, "InAppMessagesSDK initialized from Dart")
            result.success("success")
        } catch (e: Exception) {
            Log.e(TAG, "Initialization failed", e)
            result.error("INIT_ERROR", e.message, e.stackTraceToString())
        }
    }

    private fun handleOnRouteChanged(call: MethodCall, result: MethodChannel.Result) {
        try {
            val route = call.argument<String>("route")
                ?: return result.error("INVALID_ARGUMENTS", "route is required", null)

            InAppMessagesSDK.getInstance().showActiveMessages(route)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "onRouteChanged failed", e)
            result.error("ERROR", e.message, null)
        }
    }

    private fun handleShowMessagesOnTrigger(call: MethodCall, result: MethodChannel.Result) {
        try {
            val key = call.argument<String>("key")
                ?: return result.error("INVALID_ARGUMENTS", "key is required", null)
            val value = call.argument<String>("value")
                ?: return result.error("INVALID_ARGUMENTS", "value is required", null)

            InAppMessagesSDK.getInstance().showMessagesOnTrigger(key, value)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "showMessagesOnTrigger failed", e)
            result.error("ERROR", e.message, null)
        }
    }

    private fun handleSetCustomCodeActionHandler(result: MethodChannel.Result) {
        try {
            InAppMessagesSDK.getInstance().setJsActionHandler { jsCode ->
                // Send event to Flutter
                eventSink?.let { sink ->
                    // Must be called on main thread
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        sink.success(
                            mapOf(
                                "type" to "customCode",
                                "code" to jsCode
                            )
                        )
                    }
                } ?: Log.w(TAG, "No event sink available for custom code")
            }
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "setCustomCodeActionHandler failed", e)
            result.error("ERROR", e.message, null)
        }
    }

    private fun handleClearMessageCache(result: MethodChannel.Result) {
        // Note: Android SDK doesn't have clearMessageCache method
        // This is a no-op for Android
        Log.d(TAG, "clearMessageCache not available on Android")
        result.success(null)
    }

    // EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "Event stream connected")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "Event stream disconnected")
    }

    // ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        Log.d(TAG, "Activity attached: ${activity?.javaClass?.simpleName}")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        Log.d(TAG, "Activity reattached: ${activity?.javaClass?.simpleName}")
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
