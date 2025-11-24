package com.colourswift.cssecurity

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {

            Log.i("CSRealtime", "Boot completed, scheduling service start")

            // Delay avoids Android 12+ FGS crash
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val serviceIntent = Intent(context, CSForegroundService::class.java)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }

                    Log.i("CSRealtime", "CSForegroundService started after delay")
                } catch (e: Exception) {
                    Log.e("CSRealtime", "Failed to start service after boot: ${e.message}")
                }
            }, 7000) // 7 seconds is safe across all OEMs
        }
    }
}
