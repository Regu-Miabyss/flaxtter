package dev.wyrin.flutter_media_session

import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build

/**
 * Flutter plugin for managing system media sessions on Android.
 * Integrates with Media3 to provide system-level media controls, metadata, and playback state synchronization.
 */
@UnstableApi
class FlutterMediaSessionPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel : MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var context: Context
    private var activity: Activity? = null
    private var pendingPermissionResult: Result? = null

    private var pendingMetadata: Map<String, Any?>? = null
    private var pendingPlaybackState: Map<String, Any?>? = null
    private var pendingAvailableActions: List<Any>? = null
    private var pendingActivateResult: Result? = null
    /**
     * When true, the service requests audio focus while playing and forwards
     * focus events as media actions. Mirrors the user-facing
     * `setHandlesInterruptions` API; defaults to false so we don't fight other
     * audio plugins (audioplayers, just_audio) that already manage focus.
     * Persisted across service restarts so the setting survives deactivate.
     */
    var handlesInterruptions: Boolean = false
        private set

    companion object {
        private const val REQUEST_NOTIFICATION_PERMISSION = 1101
        
        /**
         * Singleton instance for access from the media service.
         */
        var instance: FlutterMediaSessionPlugin? = null
            private set
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        instance = this
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_media_session")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_media_session_events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private var serviceConnection: android.content.ServiceConnection? = null

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "activate" -> {
                if (FlutterMediaSessionService.instance != null) {
                    result.success(null)
                } else {
                    pendingActivateResult = result
                    val intent = Intent(context, FlutterMediaSessionService::class.java)
                    serviceConnection = object : android.content.ServiceConnection {
                        override fun onServiceConnected(name: android.content.ComponentName?, service: android.os.IBinder?) {}
                        override fun onServiceDisconnected(name: android.content.ComponentName?) {
                            serviceConnection = null
                        }
                    }
                    try {
                        context.bindService(intent, serviceConnection!!, Context.BIND_AUTO_CREATE)
                    } catch (e: Exception) {
                        pendingActivateResult?.error("SERVICE_ERROR", "Failed to bind service: ${e.message}", null)
                        pendingActivateResult = null
                    }
                }
            }
            "deactivate" -> {
                val intent = Intent(context, FlutterMediaSessionService::class.java)
                serviceConnection?.let {
                    try { context.unbindService(it) } catch (e: Exception) {}
                    serviceConnection = null
                }
                context.stopService(intent)
                result.success(null)
            }
            "updateMetadata" -> {
                val arguments = call.arguments as? Map<String, Any?>
                if (FlutterMediaSessionService.instance != null) {
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    val album = call.argument<String>("album")
                    val artworkUri = call.argument<String>("artworkUri")
                    val durationMs = (call.argument<Number>("durationMs"))?.toLong() ?: 0L
                    FlutterMediaSessionService.instance?.updateMetadata(title, artist, album, artworkUri, durationMs)
                } else {
                    pendingMetadata = arguments
                }
                result.success(null)
            }
            "updatePlaybackState" -> {
                val arguments = call.arguments as? Map<String, Any?>
                if (FlutterMediaSessionService.instance != null) {
                    val status = call.argument<String>("status") ?: "idle"
                    val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                    val speed = (call.argument<Number>("speed"))?.toFloat() ?: 1.0f
                    val bufferedPositionMs = (call.argument<Number>("bufferedPositionMs"))?.toLong() ?: 0L
                    val repeatMode = (call.argument<Number>("repeatMode"))?.toInt() ?: 0
                    val shuffleModeEnabled = call.argument<Boolean>("shuffleModeEnabled") ?: false
                    FlutterMediaSessionService.instance?.updatePlaybackState(status, positionMs, speed, bufferedPositionMs, repeatMode, shuffleModeEnabled)
                } else {
                    pendingPlaybackState = arguments
                }
                result.success(null)
            }
            "updateAvailableActions" -> {
                @Suppress("UNCHECKED_CAST")
                val actions = call.arguments as? List<Any>
                if (FlutterMediaSessionService.instance != null) {
                    FlutterMediaSessionService.instance?.updateAvailableActions(actions)
                } else {
                    pendingAvailableActions = actions
                }
                result.success(null)
            }
            "requestNotificationPermission" -> {
                requestNotificationPermission(result)
            }
            "setHandlesInterruptions", "setAutoHandleInterruptions" -> {
                val enabled = call.arguments as? Boolean ?: false
                handlesInterruptions = enabled
                FlutterMediaSessionService.instance?.onHandlesInterruptionsChanged(enabled)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestNotificationPermission(result: Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success(true)
            return
        }

        if (ContextCompat.checkSelfPermission(context, "android.permission.POST_NOTIFICATIONS") == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        pendingPermissionResult = result
        activity?.requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), REQUEST_NOTIFICATION_PERMISSION)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == REQUEST_NOTIFICATION_PERMISSION) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return true
        }
        return false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        instance = null
    }

    /**
     * Sends a media action event back to the Flutter side.
     * @param action The name of the action (e.g., "play", "pause").
     * @param args Optional arguments for the action (e.g., seek position).
     */
    fun sendAction(action: String, args: Any? = null) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            if (args != null) {
                eventSink?.success(mapOf("action" to action, "args" to args))
            } else {
                eventSink?.success(action)
            }
        }
    }

    /**
     * Called when the MediaSessionService has finished creating and is ready.
     */
    fun onServiceCreated() {
        pendingActivateResult?.success(null)
        pendingActivateResult = null
    }

    /**
     * Synchronizes metadata and playback state that were received before the service was fully initialized.
     */
    fun syncPendingData() {
        val service = FlutterMediaSessionService.instance ?: return
        
        pendingMetadata?.let {
            val title = it["title"] as? String
            val artist = it["artist"] as? String
            val album = it["album"] as? String
            val artworkUri = it["artworkUri"] as? String
            val durationMs = (it["durationMs"] as? Number)?.toLong() ?: 0L
            service.updateMetadata(title, artist, album, artworkUri, durationMs)
            pendingMetadata = null
        }
        
        pendingPlaybackState?.let {
            val status = it["status"] as? String ?: "idle"
            val positionMs = (it["positionMs"] as? Number)?.toLong() ?: 0L
            val speed = (it["speed"] as? Number)?.toFloat() ?: 1.0f
            val bufferedPositionMs = (it["bufferedPositionMs"] as? Number)?.toLong() ?: 0L
            val repeatMode = (it["repeatMode"] as? Number)?.toInt() ?: 0
            val shuffleModeEnabled = it["shuffleModeEnabled"] as? Boolean ?: false
            service.updatePlaybackState(status, positionMs, speed, bufferedPositionMs, repeatMode, shuffleModeEnabled)
            pendingPlaybackState = null
        }

        pendingAvailableActions?.let {
            service.updateAvailableActions(it)
            pendingAvailableActions = null
        }
    }
}
