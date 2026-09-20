package com.example.testf

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    companion object {
        const val CHANNEL        = "com.example.testf/marquee"
        const val PERM_CHANNEL   = "com.example.testf/permissions"
        const val PERM_REQ_CODE  = 1001
    }

    private lateinit var marquee: MarqueeNotificationHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        marquee = MarqueeNotificationHelper(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Marquee notification channel ──────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val title     = call.argument<String>("title")     ?: ""
                        val artist    = call.argument<String>("artist")    ?: ""
                        val nextLine  = call.argument<String>("nextLine")  ?: ""
                        val artUrl    = call.argument<String>("artUrl")    ?: ""
                        val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                        marquee.update(title, artist, nextLine, artUrl, isPlaying)
                        result.success(null)
                    }
                    "cancel" -> {
                        marquee.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Runtime permissions channel ───────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestStoragePermissions" -> {
                        requestStoragePermissions()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestStoragePermissions() {
        val permsToRequest = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ — granular audio permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO)
                    != PackageManager.PERMISSION_GRANTED) {
                permsToRequest.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
        } else {
            // Android 6–12 — legacy storage permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)
                    != PackageManager.PERMISSION_GRANTED) {
                permsToRequest.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
                        != PackageManager.PERMISSION_GRANTED) {
                    permsToRequest.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                }
            }
        }

        if (permsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permsToRequest.toTypedArray(), PERM_REQ_CODE)
        }
    }

    override fun onDestroy() {
        marquee.dispose()
        super.onDestroy()
    }
}
