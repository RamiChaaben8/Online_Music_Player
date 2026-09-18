package com.example.testf

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.view.KeyEvent

/**
 * Receives button taps from the marquee notification and
 * forwards them as media key events — the standard way to
 * control any MediaSession without holding a reference to it.
 */
class MarqueeButtonReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val keyCode = when (intent.action) {
            MarqueeNotificationHelper.ACTION_PREV -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            MarqueeNotificationHelper.ACTION_PP   -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            MarqueeNotificationHelper.ACTION_NEXT -> KeyEvent.KEYCODE_MEDIA_NEXT
            else -> return
        }
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP,   keyCode))
    }
}
