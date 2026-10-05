package com.brukb.blan.proximity

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat

/**
 * Decides dialog-over-screen vs heads-up notification for an invite, and
 * builds the notification. Result relays through [InviteBus].
 */

/** What the initiator asked for, shown on the invite. */
data class InviteIntent(
    val useLanTheirs: Boolean = false,
    val useLanMine: Boolean = false,
    val usePrivateNetwork: Boolean = false,
) {
    val lines: List<String>
        get() = buildList {
            if (useLanTheirs) add("They want to join your Wi-Fi.")
            if (useLanMine) add("They want you on their Wi-Fi.")
            if (usePrivateNetwork) add("They want a private network.")
        }
}

object InvitePresenter {
    const val NOTIFICATION_ID = 4201
    const val CHANNEL_ID = "blan_invites"
    const val ACTION_ACCEPT = "com.brukb.blan.proximity.INVITE_ACCEPT"
    const val ACTION_DECLINE = "com.brukb.blan.proximity.INVITE_DECLINE"

    fun hasFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    fun hasOverlayPermission(context: Context): Boolean =
        Settings.canDrawOverlays(context)

    /** Fires the Settings intent for the first missing invite permission. */
    fun requestInvitePermissions(context: Context) {
        if (!hasOverlayPermission(context)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            !hasFullScreenIntent(context)
        ) {
            val intent = Intent(
                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }

    /**
     * Shows the invite. Returns "dialog" when the full-screen activity was
     * launched, "notification" when the heads-up was posted. A foreground
     * app may launch the activity directly — background activity launch
     * restrictions only apply to backgrounded apps.
     */
    @SuppressLint("MissingPermission")
    fun showInvite(
        context: Context,
        nick: String,
        code: String,
        inForeground: Boolean,
        inviteIntent: InviteIntent = InviteIntent(),
    ): String {
        if (inForeground || (hasOverlayPermission(context) && hasFullScreenIntent(context))) {
            val intent = Intent(context, InviteActivity::class.java)
                .putExtra("nick", nick)
                .putExtra("code", code)
                .putExtra("lines", inviteIntent.lines.toTypedArray())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            context.startActivity(intent)
            return "dialog"
        }
        postHeadsUp(context, nick, code, inviteIntent)
        return "notification"
    }

    private fun postHeadsUp(
        context: Context,
        nick: String,
        code: String,
        inviteIntent: InviteIntent,
    ) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Nearby invites",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, com.brukb.blan.MainActivity::class.java).addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK,
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val acceptIntent = PendingIntent.getBroadcast(
            context,
            1,
            Intent(context, InviteActionReceiver::class.java).setAction(ACTION_ACCEPT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val declineIntent = PendingIntent.getBroadcast(
            context,
            2,
            Intent(context, InviteActionReceiver::class.java).setAction(ACTION_DECLINE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val text = buildString {
            append("Code: $code")
            for (line in inviteIntent.lines) {
                append("\n")
                append(line)
            }
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("Invite from $nick")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(0, "Accept", acceptIntent)
            .addAction(0, "Decline", declineIntent)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    fun cancelNotification(context: Context) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }
}