package com.example.testf

import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    companion object {
        const val CHANNEL = "com.example.testf/marquee"
    }

    private lateinit var marquee: MarqueeNotificationHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        marquee = MarqueeNotificationHelper(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
    }

    override fun onDestroy() {
        marquee.dispose()
        super.onDestroy()
    }
}
