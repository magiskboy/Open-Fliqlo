package com.openfliqlo.open_fliqlo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Opened from the system screen-saver settings gear for Open Fliqlo. */
class ConfigureActivity : FlutterActivity() {
    override fun getDartEntrypointArgs(): List<String> = listOf("--configure")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FlipClockDreamService.CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "finish" -> {
                    finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
