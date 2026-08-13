package com.pushpushgo.pushpushgo_sdk

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.pushpushgo.sdk.PushPushGo
import com.pushpushgo.sdk.push.liveactivity.data.LiveActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin for PushPushGo Live Activities
 *
 * Thin bridge over the native SDK facade — the notification itself is rendered
 * and kept up to date by the Android SDK, so this class only forwards
 * subscribe/unsubscribe calls and reports lifecycle events back to Dart.
 */
class LiveActivitiesPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "LiveActivitiesPlugin"
        private const val METHOD_CHANNEL_NAME = "com.pushpushgo/liveactivities/methods"
        private const val EVENT_CHANNEL_NAME = "com.pushpushgo/liveactivities/events"

        /** Android 16 — the first release with ProgressStyle Live Updates. */
        private const val LIVE_ACTIVITY_MIN_SDK = 36
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var eventSink: EventChannel.EventSink? = null

    /**
     * Clicks delivered before Dart attached to the event channel. The launcher
     * intent of a cold start arrives long before the Flutter engine is ready,
     * so the event is held here and replayed on [onListen].
     */
    private val pendingEvents = mutableListOf<Map<String, Any?>>()

    // Method identifiers
    private enum class MethodIdentifier {
        initialize,
        isSupported,
        subscribe,
        unsubscribe,
        getSubscriberId,
        isActive,
        getActiveActivities,
        simulatePush;

        companion object {
            fun fromString(name: String): MethodIdentifier? {
                return values().find { it.name == name }
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(this)

        Log.d(TAG, "LiveActivitiesPlugin attached")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        Log.d(TAG, "LiveActivitiesPlugin detached")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (MethodIdentifier.fromString(call.method)) {
            MethodIdentifier.initialize -> handleInitialize(result)
            MethodIdentifier.isSupported -> handleIsSupported(result)
            MethodIdentifier.subscribe -> handleSubscribe(call, result)
            MethodIdentifier.unsubscribe -> handleUnsubscribe(call, result)
            MethodIdentifier.getSubscriberId -> handleGetSubscriberId(call, result)
            MethodIdentifier.isActive -> handleIsActive(call, result)
            MethodIdentifier.getActiveActivities -> handleGetActiveActivities(result)
            MethodIdentifier.simulatePush -> handleSimulatePush(call, result)
            null -> result.notImplemented()
        }
    }

    // Method Implementations

    /**
     * Nothing to configure on Android — Live Activities are served by the
     * already-initialized push SDK. The iOS counterpart needs the App Group id
     * here, hence the shared method.
     */
    private fun handleInitialize(result: MethodChannel.Result) {
        try {
            PushPushGo.getInstance()
            Log.d(TAG, "Live Activities ready (supported: ${PushPushGo.getInstance().isLiveActivitiesSupported()})")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Initialization failed — initialize the PushPushGo SDK first", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }

    /**
     * Whether this device can render Live Activities.
     *
     * Device support is a pure OS-version question, so it must not depend on
     * the push SDK being initialized — otherwise an app that calls this before
     * (or without) a successful `initialize()` is told its Android 16 device is
     * unsupported. The SDK stays the source of truth when it is available.
     */
    private fun handleIsSupported(result: MethodChannel.Result) {
        if (PushPushGo.isInitialized()) {
            result.success(PushPushGo.getInstance().isLiveActivitiesSupported())
            return
        }

        Log.d(TAG, "PushPushGo not initialized yet, falling back to the OS version check")
        result.success(Build.VERSION.SDK_INT >= LIVE_ACTIVITY_MIN_SDK)
    }

    private fun handleSubscribe(call: MethodCall, result: MethodChannel.Result) {
        val liveNotificationId = call.argument<String>("liveNotificationId")
            ?: return result.error("INVALID_ARGUMENTS", "liveNotificationId is required", null)

        try {
            val ppg = PushPushGo.getInstance()

            if (!ppg.isLiveActivitiesSupported()) {
                Log.w(TAG, "Live Activities require Android 16 (API 36), skipping subscribe")
                return result.error(
                    "UNSUPPORTED",
                    "Live Activities require Android 16 (API 36) or newer",
                    null,
                )
            }

            Futures.addCallback(
                ppg.subscribeToLiveActivity(liveNotificationId),
                object : FutureCallback<String> {
                    override fun onSuccess(laSubscriberId: String) {
                        result.success(laSubscriberId)
                        sendStatus("registered", liveNotificationId)

                        // Subscribing to an already running activity renders its
                        // current state immediately — report it as started so the
                        // app doesn't have to poll.
                        if (ppg.isLiveActivityActive(liveNotificationId)) {
                            sendStatus("started", liveNotificationId)
                        }
                    }

                    override fun onFailure(t: Throwable) {
                        Log.e(TAG, "subscribe failed", t)
                        result.error("SUBSCRIBE_ERROR", t.message, null)
                        sendStatus("error", liveNotificationId, error = t.message)
                    }
                },
                ContextCompat.getMainExecutor(context),
            )
        } catch (e: Exception) {
            Log.e(TAG, "subscribe failed", e)
            result.error("SUBSCRIBE_ERROR", e.message, null)
        }
    }

    private fun handleUnsubscribe(call: MethodCall, result: MethodChannel.Result) {
        val liveNotificationId = call.argument<String>("liveNotificationId")
            ?: return result.error("INVALID_ARGUMENTS", "liveNotificationId is required", null)

        try {
            Futures.addCallback(
                PushPushGo.getInstance().unsubscribeFromLiveActivity(liveNotificationId),
                object : FutureCallback<Unit> {
                    override fun onSuccess(unused: Unit) {
                        result.success(null)
                        sendStatus("unsubscribed", liveNotificationId)
                    }

                    override fun onFailure(t: Throwable) {
                        Log.e(TAG, "unsubscribe failed", t)
                        result.error("UNSUBSCRIBE_ERROR", t.message, null)
                        sendStatus("error", liveNotificationId, error = t.message)
                    }
                },
                ContextCompat.getMainExecutor(context),
            )
        } catch (e: Exception) {
            Log.e(TAG, "unsubscribe failed", e)
            result.error("UNSUBSCRIBE_ERROR", e.message, null)
        }
    }

    private fun handleGetSubscriberId(call: MethodCall, result: MethodChannel.Result) {
        val liveNotificationId = call.argument<String>("liveNotificationId")
            ?: return result.error("INVALID_ARGUMENTS", "liveNotificationId is required", null)

        try {
            result.success(PushPushGo.getInstance().getLiveActivitySubscriberId(liveNotificationId))
        } catch (e: Exception) {
            Log.w(TAG, "getSubscriberId failed: ${e.message}")
            result.success(null)
        }
    }

    private fun handleIsActive(call: MethodCall, result: MethodChannel.Result) {
        val liveNotificationId = call.argument<String>("liveNotificationId")
            ?: return result.error("INVALID_ARGUMENTS", "liveNotificationId is required", null)

        try {
            result.success(PushPushGo.getInstance().isLiveActivityActive(liveNotificationId))
        } catch (e: Exception) {
            Log.w(TAG, "isActive failed: ${e.message}")
            result.success(false)
        }
    }

    private fun handleGetActiveActivities(result: MethodChannel.Result) {
        try {
            val activities = PushPushGo.getInstance().getActiveLiveActivities().map { serialize(it) }
            result.success(activities)
        } catch (e: Exception) {
            Log.w(TAG, "getActiveActivities failed: ${e.message}")
            result.success(emptyList<Map<String, Any?>>())
        }
    }

    private fun handleSimulatePush(call: MethodCall, result: MethodChannel.Result) {
        try {
            val data = call.argument<Map<String, String>>("data")
                ?: return result.error("INVALID_ARGUMENTS", "data is required", null)

            PushPushGo.getInstance().simulateLiveActivityPush(data)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "simulatePush failed", e)
            result.error("ERROR", e.message, null)
        }
    }

    private fun serialize(activity: LiveActivity): Map<String, Any?> = mapOf(
        "id" to activity.id,
        "template" to activity.template.value,
        "status" to activity.status.value,
        "homeTeamName" to activity.configuration.content.homeTeamName,
        "awayTeamName" to activity.configuration.content.awayTeamName,
        "homeScore" to activity.liveData.homeTeamScore,
        "awayScore" to activity.liveData.awayTeamScore,
        "phase" to activity.liveData.status.value,
    )

    // Events sent to Dart

    /** Report a lifecycle change of a subscribed live notification. */
    fun sendStatus(
        status: String,
        liveNotificationId: String,
        error: String? = null,
    ) {
        send(
            mapOf(
                "type" to "status",
                "status" to status,
                "liveNotificationId" to liveNotificationId,
                "error" to error,
            ),
        )
    }

    /**
     * Report a tap on a Live Activity. [actionIndex] is the 0-based index of the
     * tapped action button, or -1 for a tap on the notification body.
     */
    fun sendClick(
        liveNotificationId: String,
        deepLink: String?,
        actionIndex: Int,
    ) {
        send(
            mapOf(
                "type" to "click",
                "liveNotificationId" to liveNotificationId,
                "deepLink" to deepLink,
                "actionIndex" to actionIndex,
            ),
        )
    }

    private fun send(event: Map<String, Any?>) {
        val sink = eventSink
        if (sink == null) {
            Log.d(TAG, "No event sink yet, buffering ${event["type"]}")
            pendingEvents.add(event)
            return
        }

        // EventSink must be called on the main thread
        Handler(Looper.getMainLooper()).post { sink.success(event) }
    }

    // EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "Event stream connected")

        if (pendingEvents.isNotEmpty()) {
            val buffered = pendingEvents.toList()
            pendingEvents.clear()
            buffered.forEach { send(it) }
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "Event stream disconnected")
    }
}
