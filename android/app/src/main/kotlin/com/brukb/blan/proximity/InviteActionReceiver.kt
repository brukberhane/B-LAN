package com.brukb.blan.proximity

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Accept/Decline action buttons on the heads-up invite notification.
 */
class InviteActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(InvitePresenter.NOTIFICATION_ID)
        if (intent.action == InvitePresenter.ACTION_ACCEPT) {
            InviteBus.accept()
        } else {
            InviteBus.decline()
        }
    }
}