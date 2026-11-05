package com.sbikazis.pubget

import android.net.Uri
import android.util.Base64
import android.view.WindowManager
import com.google.firebase.storage.FirebaseStorage
import com.google.firebase.storage.StorageMetadata
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
        const val KIRARI_UPLOAD_CHANNEL = "pubget/kirari_upload"
        const val KIRARI_UPLOAD_PREFS = "kirari_resumable_uploads"
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
    private lateinit var kirariUploadChannel: MethodChannel

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

        kirariUploadChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KIRARI_UPLOAD_CHANNEL
        )
        kirariUploadChannel.setMethodCallHandler { call, result ->
            if (call.method != "uploadSource") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val arguments = call.arguments as? Map<*, *>
            val storagePath = arguments?.get("storagePath") as? String
            val localPath = arguments?.get("localPath") as? String
            if (storagePath.isNullOrBlank() || localPath.isNullOrBlank()) {
                result.error("INVALID_UPLOAD", "Missing upload path.", null)
                return@setMethodCallHandler
            }

            val source = java.io.File(localPath)
            if (!source.isFile || source.length() <= 0L) {
                result.error("MISSING_SOURCE", "The local video file is unavailable.", null)
                return@setMethodCallHandler
            }

            try {
                val preferences = getSharedPreferences(KIRARI_UPLOAD_PREFS, MODE_PRIVATE)
                val key = Base64.encodeToString(
                    storagePath.toByteArray(Charsets.UTF_8),
                    Base64.NO_WRAP or Base64.URL_SAFE
                )
                val sessionKey = "session_$key"
                val pathKey = "path_$key"
                val sizeKey = "size_$key"
                val modifiedKey = "modified_$key"
                val sessionTimeKey = "session_time_$key"

                // Never attach a previous session to a different or stale file.
                val sessionAge = System.currentTimeMillis() -
                    preferences.getLong(sessionTimeKey, 0L)
                if (preferences.getString(pathKey, null) != source.absolutePath ||
                    preferences.getLong(sizeKey, -1L) != source.length() ||
                    preferences.getLong(modifiedKey, -1L) != source.lastModified() ||
                    sessionAge > 6L * 24L * 60L * 60L * 1000L) {
                    preferences.edit()
                        .remove(sessionKey)
                        .remove(pathKey)
                        .remove(sizeKey)
                        .remove(modifiedKey)
                        .remove(sessionTimeKey)
                        .apply()
                }

                val sessionUri = preferences.getString(sessionKey, null)?.let {
                    runCatching { Uri.parse(it) }.getOrNull()
                }
                val metadata = StorageMetadata.Builder()
                    .setContentType("video/mp4")
                    .setCustomMetadata("uploadedBy", "kirari-client")
                    .build()
                val task = FirebaseStorage.getInstance()
                    .reference
                    .child(storagePath)
                    .putFile(Uri.fromFile(source), metadata, sessionUri)

                task.addOnProgressListener { snapshot ->
                    snapshot.uploadSessionUri?.let { uri ->
                        preferences.edit()
                            .putString(sessionKey, uri.toString())
                            .putString(pathKey, source.absolutePath)
                            .putLong(sizeKey, source.length())
                            .putLong(modifiedKey, source.lastModified())
                            .putLong(sessionTimeKey, System.currentTimeMillis())
                            .apply()
                    }
                    val total = snapshot.totalByteCount
                    val progress = if (total > 0L) {
                        snapshot.bytesTransferred.toDouble() / total.toDouble()
                    } else {
                        0.0
                    }
                    kirariUploadChannel.invokeMethod(
                        "progress",
                        mapOf("progress" to progress)
                    )
                }
                task.addOnSuccessListener {
                    preferences.edit()
                        .remove(sessionKey)
                        .remove(pathKey)
                        .remove(sizeKey)
                        .remove(modifiedKey)
                        .remove(sessionTimeKey)
                        .apply()
                    result.success(null)
                }
                task.addOnFailureListener { error ->
                    // Keep the session URI: the next process can pass it back
                    // to putFile and Firebase Storage resumes from its server offset.
                    result.error("UPLOAD_FAILED", error.message, error.javaClass.simpleName)
                }
            } catch (error: Exception) {
                result.error("UPLOAD_SETUP_FAILED", error.message, error.javaClass.simpleName)
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