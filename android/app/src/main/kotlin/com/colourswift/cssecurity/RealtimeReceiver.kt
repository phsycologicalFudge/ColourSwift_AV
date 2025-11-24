package com.colourswift.cssecurity

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.io.File

class RealtimeReceiver(private var events: EventChannel.EventSink? = null) : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        val path = intent?.getStringExtra("path")
        if (path != null) {
            Log.i("CSRealtime", "Detected new file: $path")

            // --- Flutter event ---
            events?.success(path)

            // --- Quarantine logic ---
            context?.let { ctx ->
                try {
                    val file = File(path)
                    if (file.exists()) {
                        // Move to quarantine folder
                        val quarantineDir = File(ctx.filesDir, "quarantine")
                        if (!quarantineDir.exists()) quarantineDir.mkdir()
                        val target = File(quarantineDir, file.name)
                        file.renameTo(target)
                        Log.i("CSRealtime", "File quarantined: ${target.absolutePath}")
                    }
                } catch (e: Exception) {
                    Log.e("CSRealtime", "Failed to quarantine file: ${e.message}")
                }
            }
        }
    }

    // Optional: helper to set Flutter EventSink dynamically
    fun setEventSink(sink: EventChannel.EventSink?) {
        this.events = sink
    }
}
