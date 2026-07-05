package com.brukb.blan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File

class BlanForegroundService : Service() {
    companion object {
        const val SERVER_TASK_ID = "transfer-server"
        private const val CHANNEL_ID = "blan_tasks"
        private const val NOTIFICATION_ID = 1001
        private const val STOP_REQUEST_CODE = 2001
        private const val OPEN_REQUEST_CODE = 2002

        private val activeTasks = linkedMapOf<String, Pair<String, String>>()
        private var stopSharingListener: (() -> Unit)? = null

        fun setStopSharingListener(listener: (() -> Unit)?) {
            stopSharingListener = listener
        }

        fun requestStopSharing() {
            stopSharingListener?.invoke()
        }

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

        val notification = buildNotification()
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

    private fun buildNotification(): Notification {
        val (title, body) = notificationContent()
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openAppIntent())

        if (activeTasks.containsKey(SERVER_TASK_ID)) {
            builder.addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Stop sharing",
                    stopSharingIntent(),
                ).build(),
            )
        }

        return builder.build()
    }

    private fun notificationContent(): Pair<String, String> {
        val server = activeTasks[SERVER_TASK_ID]
        val activeWork = activeTasks.entries.lastOrNull { it.key != SERVER_TASK_ID }
        val title = server?.first ?: activeWork?.value?.first ?: "B-LAN"
        val body = when {
            server != null && activeWork != null ->
                "${server.second} · ${activeWork.value.second}"
            server != null -> server.second
            activeWork != null -> activeWork.value.second
            else -> ""
        }
        return title to body
    }

    private fun openAppIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, OPEN_REQUEST_CODE, intent, flags)
    }

    private fun stopSharingIntent(): PendingIntent {
        val intent = Intent(this, SharingStopReceiver::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(this, STOP_REQUEST_CODE, intent, flags)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "B-LAN background tasks",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps LAN sharing and transfers running in the background"
            }
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
