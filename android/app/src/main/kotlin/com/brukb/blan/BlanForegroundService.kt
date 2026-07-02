package com.brukb.blan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File

class BlanForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "blan_tasks"
        private const val NOTIFICATION_ID = 1001
        private val activeTasks = linkedMapOf<String, Pair<String, String>>()

        fun start(context: Context, taskId: String, title: String, body: String) {
            activeTasks[taskId] = title to body
            val intent = Intent(context, BlanForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(context: Context, taskId: String, title: String, body: String) {
            activeTasks[taskId] = title to body
            val intent = Intent(context, BlanForegroundService::class.java)
            context.startService(intent)
        }

        fun stop(context: Context, taskId: String) {
            activeTasks.remove(taskId)
            val intent = Intent(context, BlanForegroundService::class.java)
            if (activeTasks.isEmpty()) {
                context.stopService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        if (activeTasks.isEmpty()) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val latest = activeTasks.values.last()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(latest.first)
            .setContentText(latest.second)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "B-LAN background tasks",
                NotificationManager.IMPORTANCE_LOW,
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}

object SafFileStats {
    fun stat(path: String): Map<String, Long> {
        val file = File(path)
        return if (file.exists()) {
            mapOf(
                "size" to file.length(),
                "mtimeMs" to file.lastModified(),
            )
        } else {
            mapOf(
                "size" to 0L,
                "mtimeMs" to 0L,
            )
        }
    }
}
