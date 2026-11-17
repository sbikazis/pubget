package com.sbikazis.pubget

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter app and serves the `pubget/fan_work_reader` channel.
 *
 * The channel exists for one reason: a Fan Work file must not end up in the
 * task-switcher snapshot. Android takes that snapshot from the window, and
 * `FLAG_SECURE` is the only thing that blacks it out while still letting the
 * app draw. There is no Dart equivalent, so it has to be set here.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val READER_CHANNEL = "pubget/fan_work_reader"
    }

    /**
     * Whether the reader currently wants the window protected.
     *
     * Kept so protection can be re-applied after the activity resumes: the
     * recents snapshot is taken as the app pauses, so the flag has to stay on
     * through `onPause`, and it must be restored on `onResume` because the
     * reader widget is not rebuilt when the app comes back.
     */
    private var protectRequested = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, READER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setProtected" -> {
                        setProtected(call.arguments == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Applies or drops `FLAG_SECURE` on the current window.
     *
     * Tolerant by design: the reader must never fail to open because a platform
     * call misbehaved, so a refusal is swallowed and reading continues.
     */
    private fun setProtected(enabled: Boolean) {
        protectRequested = enabled
        applyProtection(enabled)
    }

    private fun applyProtection(enabled: Boolean) {
        try {
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        } catch (_: Throwable) {
            // Reading continues unprotected rather than being blocked.
        }
    }

    override fun onResume() {
        super.onResume()
        // The reader is still on screen after returning from the background,
        // but nothing in Dart re-runs, so the flag has to be restored here.
        if (protectRequested) applyProtection(true)
    }
}