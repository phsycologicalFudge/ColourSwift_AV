package com.colourswift.cssecurity

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.FileObserver
import android.os.IBinder
import android.util.Log
import java.io.File

class CSForegroundService : Service() {

    private var observer: FileObserver? = null
    private val downloadsPath = "/storage/emulated/0/Download"

    override fun onCreate() {
        super.onCreate()
        startDownloadWatcher()
        Log.i("CSRealtime", "Service created and FileObserver started")
    }


    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title") ?: "ColourSwift AV+"
        val text = intent?.getStringExtra("text") ?: "Realtime protection active"

        createNotification(title, text)

        return START_STICKY
    }

    private fun createNotification(title: String, text: String) {
        val channelId = "cssecurity_realtime_v2"
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Realtime Protection",
                NotificationManager.IMPORTANCE_DEFAULT // Hypatia-style
            )
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }

        val notificationIntent = Intent(applicationContext, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = Notification.Builder(applicationContext, channelId)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, notification)
        } else {
            startForeground(1, notification)
        }
    }

    private fun startDownloadWatcher() {
        val path = File(downloadsPath)
        if (!path.exists()) path.mkdirs()

        observer?.stopWatching()
        observer = object : FileObserver(path.absolutePath, CREATE or MOVED_TO) {
            override fun onEvent(event: Int, fileName: String?) {
                fileName?.let {
                    val fullPath = "$downloadsPath/$it"
                    Log.i("CSRealtime", "Detected new file: $fullPath")

                    val intent = Intent("com.colourswift.cssecurity.NEW_FILE_DETECTED")
                    intent.setPackage("com.colourswift.cssecurity")
                    intent.putExtra("path", fullPath)
                    sendBroadcast(intent)
                    Log.i("CSRealtime", "Broadcast sent for $fullPath")
                }
            }
        }
        observer?.startWatching()
        Log.i("CSRealtime", "FileObserver active on $downloadsPath")
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Let Android handle restart via START_STICKY; minimal manual restart
        Log.i("CSRealtime", "Task removed, relying on START_STICKY for restart")
    }

    override fun onDestroy() {
        observer?.stopWatching()
        observer = null
        Log.i("CSRealtime", "Service destroyed, FileObserver stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
