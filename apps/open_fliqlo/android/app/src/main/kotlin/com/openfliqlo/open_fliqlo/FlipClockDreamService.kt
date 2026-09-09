package com.openfliqlo.open_fliqlo

import android.service.dreams.DreamService
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * System screen saver (Daydream) hosting the Flutter flip clock in --screensaver mode.
 */
class FlipClockDreamService : DreamService() {
    private var engine: FlutterEngine? = null
    private var flutterView: FlutterView? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        isInteractive = true
        isFullscreen = true

        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val flutterEngine = FlutterEngine(applicationContext)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "finish" -> {
                    finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
            listOf("--screensaver"),
        )

        val view = FlutterView(this)
        view.attachToFlutterEngine(flutterEngine)
        setContentView(view)

        engine = flutterEngine
        flutterView = view
    }

    override fun onDetachedFromWindow() {
        flutterView?.detachFromFlutterEngine()
        flutterView = null
        engine?.destroy()
        engine = null
        super.onDetachedFromWindow()
    }

    companion object {
        const val CHANNEL = "com.openfliqlo.app/platform"
    }
}
