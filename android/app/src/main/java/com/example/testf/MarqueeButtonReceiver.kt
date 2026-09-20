package com.example.testf

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.KeyEvent

/**
 * Receives button taps from the marquee notification and
 * routes them to audio_service's AudioService as a standard
 * ACTION_MEDIA_BUTTON intent.
 *
 * Why this works:
 * ─────────────────────────────────────────────────────────────
 * audio_service's AudioService extends MediaBrowserServiceCompat
 * and handles android.intent.action.MEDIA_BUTTON intents by
 * dispatching them to the active MediaSession — exactly the same
 * path as a headset button press.  This is the official,
 * version-safe approach for Android 5+.
 *
 * AudioManager.dispatchMediaKeyEvent is NOT used here because on
 * Android 8+ it requires audio focus, which a notification-tap
 * context does not hold, causing the event to be silently dropped.
 */
class MarqueeButtonReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val keyCode = when (intent.action) {
            MarqueeNotificationHelper.ACTION_PREV -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            MarqueeNotificationHelper.ACTION_PP   -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            MarqueeNotificationHelper.ACTION_NEXT -> KeyEvent.KEYCODE_MEDIA_NEXT
            else -> return
        }

        // Send ACTION_MEDIA_BUTTON with the key event directly to AudioService.
        // audio_service registers to handle this intent and routes it to the
        // active MediaSessionCompat, which calls our BaseAudioHandler overrides.
        val keyEvent = KeyEvent(KeyEvent.ACTION_DOWN, keyCode)
        val serviceIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            setClass(context, com.ryanheise.audioservice.AudioService::class.java)
            putExtra(Intent.EXTRA_KEY_EVENT, keyEvent)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            // Service might not be running (nothing playing) — safe to ignore.
        }
    }
}
