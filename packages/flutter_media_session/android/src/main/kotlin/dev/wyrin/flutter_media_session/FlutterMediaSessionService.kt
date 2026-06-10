package dev.wyrin.flutter_media_session

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * A Media3 MediaSessionService that manages the media session lifecycle and player state.
 * It uses a ForwardingPlayer to handle media control commands (play, pause, seek, etc.) 
 * and notifies the Flutter side via the plugin's event channel.
 */
@UnstableApi
class FlutterMediaSessionService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    private lateinit var player: ForwardingPlayer

    companion object {
        /**
         * Singleton instance for the service, set during onCreate.
         */
        var instance: FlutterMediaSessionService? = null
            private set
    }

    private var isReceiverRegistered = false

    private var customLayout: List<androidx.media3.session.CommandButton> = emptyList()
    private val baseControllerCommands = object : LinkedHashMap<androidx.media3.session.MediaSession.ControllerInfo, Pair<androidx.media3.session.SessionCommands, androidx.media3.common.Player.Commands>>() {
        override fun removeEldestEntry(eldest: Map.Entry<androidx.media3.session.MediaSession.ControllerInfo, Pair<androidx.media3.session.SessionCommands, androidx.media3.common.Player.Commands>>?): Boolean {
            return size > 100
        }
    }

    private val audioManager: AudioManager by lazy {
        getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false
    /**
     * Set when we lose focus transiently (e.g. an incoming call) while playing,
     * so we can ask the Flutter side to resume once focus returns. Permanent
     * losses do not set this — the user gave focus to another app on purpose.
     */
    private var resumeOnFocusGain = false

    /**
     * BroadcastReceiver to handle ACTION_AUDIO_BECOMING_NOISY, which typically happens
     * when headphones are unplugged. It notifies the Flutter side to pause playback.
     */
    private val noisyReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context, intent: android.content.Intent) {
            if (AudioManager.ACTION_AUDIO_BECOMING_NOISY == intent.action) {
                // Notify Flutter side to pause playback
                FlutterMediaSessionPlugin.instance?.sendAction("pause")
            }
        }
    }

    /**
     * Listens for audio focus changes (e.g. phone calls, navigation prompts).
     * Permanent and transient losses both ask Flutter to pause; transient losses
     * additionally trigger a resume when focus returns. Duckable losses are left
     * to the system to handle by lowering the volume automatically.
     */
    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                hasAudioFocus = false
                resumeOnFocusGain = false
                FlutterMediaSessionPlugin.instance?.sendAction("pause")
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                resumeOnFocusGain = hasAudioFocus
                hasAudioFocus = false
                FlutterMediaSessionPlugin.instance?.sendAction("pause")
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                // No-op: the system ducks playback volume automatically because
                // willPauseWhenDucked is false on the focus request.
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                hasAudioFocus = true
                if (resumeOnFocusGain) {
                    resumeOnFocusGain = false
                    FlutterMediaSessionPlugin.instance?.sendAction("play")
                }
            }
        }
    }

    private fun requestAudioFocus() {
        if (hasAudioFocus) return
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = audioFocusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setOnAudioFocusChangeListener(audioFocusListener)
                .setWillPauseWhenDucked(false)
                .build()
                .also { audioFocusRequest = it }
            audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                audioFocusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
        if (granted) {
            hasAudioFocus = true
        }
    }

    private fun abandonAudioFocus() {
        if (!hasAudioFocus && audioFocusRequest == null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(audioFocusListener)
        }
        hasAudioFocus = false
        // Note: do NOT reset resumeOnFocusGain here. abandonAudioFocus() runs
        // after we've already sent "pause" to Flutter on a transient loss,
        // and the next "paused" status update from Flutter will trip this.
        // We need the flag preserved so AUDIOFOCUS_GAIN can resume.
    }

    /**
     * Called by the plugin when the user toggles `setAutoHandleInterruptions`.
     * If turning off, drops any focus we currently hold so other audio
     * plugins (audioplayers, just_audio) can take it back without
     * fighting us.
     */
    fun onHandlesInterruptionsChanged(enabled: Boolean) {
        if (!enabled) {
            abandonAudioFocus()
            resumeOnFocusGain = false
        } else if (player.isCurrentlyPlaying()) {
            // If enabled while already playing, request focus immediately.
            requestAudioFocus()
        }
    }

    override fun onCreate() {
        instance = this
        player = ForwardingPlayer()
        
        // Use the launch intent of the app for the session activity
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        // Build the session BEFORE super.onCreate() — Media3 may query
        // onGetSession() during initialization.
        mediaSession = MediaSession.Builder(this, player)
            .setSessionActivity(pendingIntent)
            .setCallback(CustomMediaSessionCallback())
            .build()
            
        super.onCreate()

        // Register the session with the service so Media3's
        // MediaNotificationManager creates its internal MediaController
        // and starts the notification pipeline.
        addSession(mediaSession!!)

        // Sync any data that was sent to the plugin before the service was ready
        FlutterMediaSessionPlugin.instance?.syncPendingData()
        FlutterMediaSessionPlugin.instance?.onServiceCreated()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val player = mediaSession?.player
        if (player == null || !player.playWhenReady || player.mediaItemCount == 0) {
            stopSelf()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        instance = null
        if (isReceiverRegistered) {
            unregisterReceiver(noisyReceiver)
            isReceiverRegistered = false
        }
        abandonAudioFocus()
        mediaSession?.let {
            removeSession(it)
            player.release()
            it.release()
            mediaSession = null
        }
        super.onDestroy()
    }

    /**
     * Updates the media metadata displayed in the system controls.
     */
    fun updateMetadata(title: String?, artist: String?, album: String?, artworkUri: String?, durationMs: Long) {
        player.updateMetadata(title, artist, album, artworkUri, durationMs)
    }

    /**
     * Updates the playback state (status, position, speed) in the system controls.
     */
    fun updatePlaybackState(status: String, positionMs: Long, speed: Float, bufferedPositionMs: Long, repeatMode: Int, shuffleModeEnabled: Boolean) {
        player.updatePlaybackState(status, positionMs, speed, bufferedPositionMs, repeatMode, shuffleModeEnabled)
    }

    /**
     * Updates the set of media actions available in the system controls.
     */
    fun updateAvailableActions(actions: List<Any>?) {
        val newCustomLayout = mutableListOf<androidx.media3.session.CommandButton>()
        val standardActions = mutableListOf<String>()

        if (actions != null) {
            for (action in actions) {
                if (action is String) {
                    standardActions.add(action)
                } else if (action is Map<*, *>) {
                    val name = (action["name"] as? String)?.takeIf { it.isNotBlank() } ?: continue
                    val customLabel = (action["customLabel"] as? String)?.takeIf { it.isNotBlank() }
                    val customIconResource = (action["customIconResource"] as? String)?.takeIf { it.isNotBlank() }
                    
                    if (customLabel == null || customIconResource == null) {
                        // If it's a map but missing custom visual fields, treat it as a standard action name
                        standardActions.add(name)
                        continue
                    }
                    
                    if (!customIconResource.matches(Regex("^[a-z0-9_]+$"))) {
                        android.util.Log.w("FlutterMediaSession", "Invalid resource name format: $customIconResource")
                        continue
                    }

                    @Suppress("UNCHECKED_CAST")
                    val customExtras = action["customExtras"] as? Map<String, Any>

                    val extrasBundle = Bundle()
                    
                    if (customExtras != null && customExtras.size > 50) {
                        android.util.Log.w("FlutterMediaSession", "customExtras exceeds size limit")
                        continue
                    }

                    customExtras?.forEach { (key, value) ->
                        if (!key.matches(Regex("^[a-zA-Z0-9_]+$"))) {
                            android.util.Log.w("FlutterMediaSession", "Invalid extra key format: $key")
                            return@forEach
                        }
                        when (value) {
                            is String -> {
                                if (value.length > 1000) return@forEach
                                extrasBundle.putString(key, value)
                            }
                            is Int -> extrasBundle.putInt(key, value)
                            is Boolean -> extrasBundle.putBoolean(key, value)
                            is Double -> extrasBundle.putDouble(key, value)
                            is Float -> extrasBundle.putFloat(key, value)
                        }
                    }

                    val iconResId = resources.getIdentifier(customIconResource, "drawable", packageName)
                    if (iconResId != 0) {
                        try {
                            val sessionCommand = androidx.media3.session.SessionCommand(name, extrasBundle)
                            val button = androidx.media3.session.CommandButton.Builder()
                                .setSessionCommand(sessionCommand)
                                .setIconResId(iconResId)
                                .setDisplayName(customLabel)
                                .build()
                            newCustomLayout.add(button)
                        } catch (e: Exception) {
                            android.util.Log.e("FlutterMediaSession", "Failed to create custom action '$name'", e)
                        }
                    } else {
                        android.util.Log.w("FlutterMediaSession", "Custom action icon resource '$customIconResource' not found for action '$name'. Action will be ignored.")
                    }
                }
            }
        }

        customLayout = newCustomLayout
        player.updateAvailableActions(if (actions == null) null else standardActions)
        
        // Notify all connected controllers about the new custom layout
        mediaSession?.let { session ->
            for (controller in session.connectedControllers) {
                val baseCommands = baseControllerCommands[controller]
                if (baseCommands != null) {
                    val sessionCommandsBuilder = baseCommands.first.buildUpon()
                    for (button in customLayout) {
                        button.sessionCommand?.let { sessionCommandsBuilder.add(it) }
                    }
                    session.setAvailableCommands(controller, sessionCommandsBuilder.build(), baseCommands.second)
                }
                session.setCustomLayout(controller, customLayout)
            }
        }
    }

    /**
     * Callback handler for MediaSession events.
     */
    inner class CustomMediaSessionCallback : MediaSession.Callback {
        override fun onConnect(
            session: MediaSession,
            controller: MediaSession.ControllerInfo
        ): MediaSession.ConnectionResult {
            val connectionResult = super.onConnect(session, controller)
            
            // Store the default commands for this controller so we can append custom commands to them later dynamically
            baseControllerCommands[controller] = Pair(connectionResult.availableSessionCommands, connectionResult.availablePlayerCommands)
            
            val availableSessionCommands = connectionResult.availableSessionCommands.buildUpon()
            
            for (button in customLayout) {
                button.sessionCommand?.let { availableSessionCommands.add(it) }
            }
            
            return MediaSession.ConnectionResult.accept(
                availableSessionCommands.build(),
                connectionResult.availablePlayerCommands
            )
        }

        override fun onDisconnected(session: MediaSession, controller: MediaSession.ControllerInfo) {
            baseControllerCommands.remove(controller)
            super.onDisconnected(session, controller)
        }

        override fun onPostConnect(session: MediaSession, controller: MediaSession.ControllerInfo) {
            session.setCustomLayout(controller, customLayout)
        }

        override fun onCustomCommand(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
            customCommand: androidx.media3.session.SessionCommand,
            args: Bundle
        ): ListenableFuture<androidx.media3.session.SessionResult> {
            val actionName = customCommand.customAction
            if (actionName.isNotEmpty()) {
                val extrasMap = mutableMapOf<String, Any>()
                for (key in customCommand.customExtras.keySet()) {
                    customCommand.customExtras.get(key)?.let { extrasMap[key] = it }
                }
                
                if (extrasMap.isEmpty()) {
                    FlutterMediaSessionPlugin.instance?.sendAction(actionName)
                } else {
                    FlutterMediaSessionPlugin.instance?.sendAction(actionName, extrasMap)
                }
                return Futures.immediateFuture(androidx.media3.session.SessionResult(androidx.media3.session.SessionResult.RESULT_SUCCESS))
            }
            return super.onCustomCommand(session, controller, customCommand, args)
        }
    }

    /**
     * Custom player implementation that forwards state changes to Media3 and commands to Flutter.
     */
    inner class ForwardingPlayer : androidx.media3.common.SimpleBasePlayer(mainLooper) {
        private var currentMetadata: MediaMetadata = MediaMetadata.EMPTY
        private var playbackStatus: String = "buffering"

        /** Outer-class accessor — `playbackStatus` is private to this inner
         *  class so [FlutterMediaSessionService.onHandlesInterruptionsChanged]
         *  cannot read the field directly. */
        fun isCurrentlyPlaying(): Boolean = playbackStatus == "playing"
        private var lastPositionMs: Long = 0
        private var lastPositionUpdateTimeMs: Long = android.os.SystemClock.elapsedRealtime()
        private var speed: Float = 1.0f
        private var bufferedPositionMs: Long = 0
        private var durationMs: Long = C.TIME_UNSET
        private var repeatMode: Int = Player.REPEAT_MODE_OFF
        private var availableActions: List<String>? = null

        /**
         * Updates the internal metadata state and triggers a state invalidation.
         */
        fun updateMetadata(title: String?, artist: String?, album: String?, artworkUri: String?, durationMs: Long) {
            currentMetadata = MediaMetadata.Builder()
                .setTitle(title)
                .setDisplayTitle(title)
                .setArtist(artist)
                .setSubtitle(artist)
                .setAlbumTitle(album)
                .setAlbumArtist(artist)
                .setArtworkUri(artworkUri?.let { android.net.Uri.parse(it) })
                .build()
            this.durationMs = if (durationMs > 0) durationMs else C.TIME_UNSET
            invalidateState()
        }

        /**
         * Updates which actions are available in the system controls.
         */
        fun updateAvailableActions(actions: List<String>?) {
            this.availableActions = actions
            invalidateState()
        }

        private var shuffleModeEnabled: Boolean = false

        /**
         * Updates the internal playback state and triggers a state invalidation.
         * Also manages the registration of the ACTION_AUDIO_BECOMING_NOISY receiver.
         */
        fun updatePlaybackState(status: String, positionMs: Long, speed: Float, bufferedPositionMs: Long, repeatMode: Int, shuffleModeEnabled: Boolean) {
            val isPlaying = status == "playing"
            
            this.playbackStatus = status
            this.lastPositionMs = positionMs
            this.lastPositionUpdateTimeMs = android.os.SystemClock.elapsedRealtime()
            this.speed = speed
            this.bufferedPositionMs = bufferedPositionMs
            this.repeatMode = when (repeatMode) {
                1 -> Player.REPEAT_MODE_ALL  // 1 = all in Dart
                2 -> Player.REPEAT_MODE_ONE  // 2 = one in Dart
                else -> Player.REPEAT_MODE_OFF
            }
            this.shuffleModeEnabled = shuffleModeEnabled
            invalidateState()

            // Manage AudioBecomingNoisy receiver based on playback state
            if (isPlaying && !isReceiverRegistered) {
                registerReceiver(noisyReceiver, android.content.IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
                isReceiverRegistered = true
            } else if (!isPlaying && isReceiverRegistered) {
                unregisterReceiver(noisyReceiver)
                isReceiverRegistered = false
            }

            // Manage audio focus alongside the noisy receiver, but only if the
            // user opted in. By default we stay out of the focus race so apps
            // that already manage focus (audioplayers, just_audio) keep working.
            if (FlutterMediaSessionPlugin.instance?.handlesInterruptions == true) {
                if (isPlaying) {
                    requestAudioFocus()
                } else if (status != "buffering" && !resumeOnFocusGain) {
                    // Only abandon focus if we're not waiting to resume from a transient loss.
                    // Abandoning focus removes the app from the focus stack, which would
                    // prevent us from ever receiving AUDIOFOCUS_GAIN back.
                    abandonAudioFocus()
                }
            }
        }

        override fun getState(): State {
            val playerState = when (playbackStatus) {
                "playing", "paused" -> Player.STATE_READY
                "buffering" -> Player.STATE_BUFFERING
                "ended" -> Player.STATE_ENDED
                else -> Player.STATE_IDLE
            }
            val playWhenReady = playbackStatus == "playing" || playbackStatus == "buffering"

            val commandsBuilder = Player.Commands.Builder()
            val actions = availableActions
            if (actions == null) {
                commandsBuilder.addAllCommands()
            } else {
                // Basic commands that don't belong to actions
                commandsBuilder.add(Player.COMMAND_GET_CURRENT_MEDIA_ITEM)
                commandsBuilder.add(Player.COMMAND_GET_METADATA)
                commandsBuilder.add(Player.COMMAND_GET_TIMELINE)
                
                if (actions.contains("play") || actions.contains("pause")) {
                    commandsBuilder.add(Player.COMMAND_PLAY_PAUSE)
                }
                if (actions.contains("stop")) {
                    commandsBuilder.add(Player.COMMAND_STOP)
                }
                if (actions.contains("seekTo")) {
                    commandsBuilder.add(Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM)
                }
                if (actions.contains("skipToNext")) {
                    commandsBuilder.add(Player.COMMAND_SEEK_TO_NEXT)
                    commandsBuilder.add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
                }
                if (actions.contains("skipToPrevious")) {
                    commandsBuilder.add(Player.COMMAND_SEEK_TO_PREVIOUS)
                    commandsBuilder.add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
                }
                if (actions.contains("rewind")) {
                    commandsBuilder.add(Player.COMMAND_SEEK_BACK)
                }
                if (actions.contains("fastForward")) {
                    commandsBuilder.add(Player.COMMAND_SEEK_FORWARD)
                }
                if (actions.contains("shuffle")) {
                    commandsBuilder.add(Player.COMMAND_SET_SHUFFLE_MODE)
                }
                if (actions.contains("repeat")) {
                    commandsBuilder.add(Player.COMMAND_SET_REPEAT_MODE)
                }
            }
            
            return State.Builder()
                .setAvailableCommands(commandsBuilder.build())
                .setPlayWhenReady(playWhenReady, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
                .setPlaybackState(playerState)
                .setRepeatMode(repeatMode)
                .setShuffleModeEnabled(shuffleModeEnabled)
                .setCurrentMediaItemIndex(0)
                .setPlaylist(listOf(
                    MediaItemData.Builder("channel_0")
                        .setMediaItem(MediaItem.Builder().setMediaId("channel_0").setMediaMetadata(currentMetadata).build())
                        .setMediaMetadata(currentMetadata)
                        .setDurationUs(if (durationMs != C.TIME_UNSET) durationMs * 1000 else C.TIME_UNSET)
                        .build()
                ))
                .setContentPositionMs {
                    val position = if (playbackStatus == "playing") {
                        val elapsed = android.os.SystemClock.elapsedRealtime() - lastPositionUpdateTimeMs
                        lastPositionMs + (elapsed * speed).toLong()
                    } else {
                        lastPositionMs
                    }
                    if (durationMs != C.TIME_UNSET && position > durationMs) durationMs else position
                }
                .setContentBufferedPositionMs { bufferedPositionMs }
                .setPlaybackParameters(PlaybackParameters(speed))
                .build()
        }

        override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
            FlutterMediaSessionPlugin.instance?.sendAction(if (playWhenReady) "play" else "pause")
            return Futures.immediateVoidFuture()
        }

        override fun handleSeek(mediaItemIndex: Int, positionMs: Long, @Player.Command seekCommand: Int): ListenableFuture<*> {
            when (seekCommand) {
                Player.COMMAND_SEEK_TO_NEXT, Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM -> {
                    FlutterMediaSessionPlugin.instance?.sendAction("skipToNext")
                }
                Player.COMMAND_SEEK_TO_PREVIOUS, Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM -> {
                    FlutterMediaSessionPlugin.instance?.sendAction("skipToPrevious")
                }
                else -> {
                    // Update internal state immediately for better responsiveness
                    this.lastPositionMs = positionMs
                    this.lastPositionUpdateTimeMs = android.os.SystemClock.elapsedRealtime()
                    invalidateState()
                    FlutterMediaSessionPlugin.instance?.sendAction("seekTo", positionMs)
                }
            }
            return Futures.immediateVoidFuture()
        }

        override fun handleStop(): ListenableFuture<*> {
            FlutterMediaSessionPlugin.instance?.sendAction("stop")
            return Futures.immediateVoidFuture()
        }

        override fun handlePrepare(): ListenableFuture<*> {
            return Futures.immediateVoidFuture()
        }

        override fun handleRelease(): ListenableFuture<*> {
            return Futures.immediateVoidFuture()
        }

        override fun handleSetRepeatMode(repeatMode: Int): ListenableFuture<*> {
            FlutterMediaSessionPlugin.instance?.sendAction("repeat")
            return Futures.immediateVoidFuture()
        }

        override fun handleSetShuffleModeEnabled(shuffleModeEnabled: Boolean): ListenableFuture<*> {
            FlutterMediaSessionPlugin.instance?.sendAction("shuffle")
            return Futures.immediateVoidFuture()
        }
    }
}
