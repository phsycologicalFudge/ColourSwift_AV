package com.colourswift.cssecurity

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import android.os.PowerManager
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "colourswift/foreground_service"
    private val EVENT_CHANNEL = "colourswift/realtime_stream"
    private var receiver: RealtimeReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Battery optimization prompt removed
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ===== Foreground service control =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val args = call.arguments as? Map<*, *>
                        val title = args?.get("title") as? String ?: "CS Security"
                        val text = args?.get("text") as? String ?: "Realtime protection active"
                        startForegroundServiceCompat(title, text)
                        result.success(true)
                    }

                    "stopService" -> {
                        stopForegroundService()
                        result.success(true)
                    }

                    "showNotification" -> {
                        val args = call.arguments as? Map<*, *>
                        val title = args?.get("title") as? String ?: "CS Security"
                        val text = args?.get("text") as? String ?: ""
                        showNotification(title, text)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        // ===== Storage permission channel =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "colourswift/storage_permission")
            .setMethodCallHandler { call, result ->
                if (call.method == "openManageStorage") {
                    try {
                        val intent =
                            Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                        intent.data = android.net.Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        Log.i("CSMain", "Launching Manage Storage settings…")
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("CSMain", "Error launching settings: ${e.message}")
                        result.error("ERROR", e.message, null)
                    }
                } else result.notImplemented()
            }

        // ===== Icon switcher (Pro feature) =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "colourswift/icon_switch")
            .setMethodCallHandler { call, _ ->
                if (call.method == "setIcon") {
                    val iconName = call.argument<String>("icon") ?: "default"
                    switchLauncherIcon(iconName)
                }
            }

        // ===== Realtime file detection stream =====
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (receiver != null) {
                        unregisterReceiver(receiver)
                        receiver = null
                    }
                    receiver = RealtimeReceiver(events)
                    val filter = IntentFilter("com.colourswift.cssecurity.NEW_FILE_DETECTED")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(receiver, filter)
                    }
                    Log.i("CSMain", "RealtimeReceiver registered")
                }

                override fun onCancel(arguments: Any?) {
                    if (receiver != null) {
                        unregisterReceiver(receiver)
                        receiver = null
                        Log.i("CSMain", "RealtimeReceiver unregistered")
                    }
                }
            })
    }

    // ------------------------
    // Class-level helper functions
    // ------------------------

    private fun startForegroundServiceCompat(title: String, text: String) {
        try {
            val intent = Intent(this, CSForegroundService::class.java)
            intent.putExtra("title", title)
            intent.putExtra("text", text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else startService(intent)
            Log.i("CSMain", "Foreground service started")
        } catch (e: Exception) {
            Log.e("CSMain", "Failed to start service: ${e.message}")
        }
    }

    private fun stopForegroundService() {
        try {
            val intent = Intent(this, CSForegroundService::class.java)
            stopService(intent)
            Log.i("CSMain", "Foreground service stopped")
        } catch (e: Exception) {
            Log.e("CSMain", "Failed to stop service: ${e.message}")
        }
    }

    private fun showNotification(title: String, text: String) {
        val channelId = "cssecurity_realtime_notify"
        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId, "Realtime Alerts",
                android.app.NotificationManager.IMPORTANCE_HIGH
            )
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }
        val notification = android.app.Notification.Builder(applicationContext, channelId)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .build()
        manager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun switchLauncherIcon(icon: String) {
        val pm = applicationContext.packageManager
        val main = ComponentName(applicationContext, "com.colourswift.cssecurity.MainActivity")
        val defAlias =
            ComponentName(applicationContext, "com.colourswift.cssecurity.IconDefaultAlias")
        val birdAlias =
            ComponentName(applicationContext, "com.colourswift.cssecurity.IconBirdAlias")

        val target = if (icon == "bird") birdAlias else defAlias

        pm.setComponentEnabledSetting(
            target,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )

        val toDisable = listOf(main, if (icon == "bird") defAlias else birdAlias)
        for (comp in toDisable) {
            pm.setComponentEnabledSetting(
                comp,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_LAUNCHER)
        intent.setComponent(target)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)

        Thread {
            Thread.sleep(500)
            Runtime.getRuntime().exit(0)
        }.start()
    }

    fun requestIgnoreBatteryOptimizations(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(context.packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    context.startActivity(intent)
                    Log.i("CSRealtime", "Prompting user to exempt battery optimizations")
                } catch (e: Exception) {
                    Log.e("CSRealtime", "Failed to request battery exemption: ${e.message}")
                }
            }
        }
    }

    override fun onDestroy() {
        receiver?.let {
            try {
                unregisterReceiver(it)
                Log.i("CSMain", "RealtimeReceiver unregistered on destroy")
            } catch (_: Exception) {}
            receiver = null
        }
        super.onDestroy()
    }
}
