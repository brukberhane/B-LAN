package com.brukb.blan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SharingStopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        BlanForegroundService.requestStopSharing()
    }
}
