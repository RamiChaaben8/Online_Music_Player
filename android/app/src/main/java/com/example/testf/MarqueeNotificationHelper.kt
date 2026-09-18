package com.example.testf

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.net.URL

/**
 * Posts a custom notification with the song title on line 1,
 * artist on line 2, and "Next: ..." on line 3.
 *
 * Note: Android RemoteViews TextViews do NOT scroll (marquee is ignored
 * in notifications). We keep the text short per field by separating
 * title / artist / next into their own TextViews so each line is as
 * readable as possible.
 */
class MarqueeNotificationHelper(private val context: Context) {

    companion object {
        const val CHANNEL_ID   = "com.example.testf.marquee"
        const val NOTIF_ID     = 9999
        const val ACTION_PREV  = "com.example.testf.marquee.PREV"
        const val ACTION_PP    = "com.example.testf.marquee.PP"
        const val ACTION_NEXT  = "com.example.testf.marquee.NEXT"
    }

    private val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Now Playing",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            nm.createNotificationChannel(ch)
        }
    }

    /** Call this from Dart (via MethodChannel) whenever the song changes. */
    fun update(
        title: String,
        artist: String,
        nextLine: String,
        artUrl: String,
        isPlaying: Boolean
    ) {
        val notif = build(title, artist, nextLine, null, isPlaying)
        nm.notify(NOTIF_ID, notif)

        if (artUrl.isNotEmpty()) {
            scope.launch {
                try {
                    val bmp: Bitmap = URL(artUrl).openStream().use {
                        BitmapFactory.decodeStream(it)
                    }
                    val notifWithArt = build(title, artist, nextLine, bmp, isPlaying)
                    nm.notify(NOTIF_ID, notifWithArt)
                } catch (_: Exception) {}
            }
        }
    }

    /** Call when playback stops so the notification disappears. */
    fun cancel() = nm.cancel(NOTIF_ID)

    private fun build(
        title: String,
        artist: String,
        nextLine: String,
        art: Bitmap?,
        isPlaying: Boolean
    ): Notification {
        val collapsed = remoteViews(R.layout.notification_player,          title, artist, nextLine, art, isPlaying)
        val expanded  = remoteViews(R.layout.notification_player_expanded, title, artist, nextLine, art, isPlaying)

        val openIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP }
        val openPi = PendingIntent.getActivity(
            context, 0, openIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(openPi)
            .setOngoing(isPlaying)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun remoteViews(
        layoutId: Int,
        title: String,
        artist: String,
        nextLine: String,
        art: Bitmap?,
        isPlaying: Boolean
    ): RemoteViews {
        val rv = RemoteViews(context.packageName, layoutId)
        rv.setTextViewText(R.id.notification_title,  title)
        rv.setTextViewText(R.id.notification_artist, artist)
        rv.setTextViewText(R.id.notification_next,   nextLine)

        if (art != null) rv.setImageViewBitmap(R.id.notification_image, art)
        else rv.setImageViewResource(R.id.notification_image, R.drawable.ic_notification)

        val ppIcon = if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play_arrow
        rv.setImageViewResource(R.id.notification_play_pause, ppIcon)

        rv.setOnClickPendingIntent(R.id.notification_prev,       actionPi(ACTION_PREV, 10))
        rv.setOnClickPendingIntent(R.id.notification_play_pause, actionPi(ACTION_PP,   11))
        rv.setOnClickPendingIntent(R.id.notification_next_btn,   actionPi(ACTION_NEXT, 12))
        return rv
    }

    private fun actionPi(action: String, rc: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context, rc,
            Intent(action).setPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    fun dispose() = scope.cancel()
}
