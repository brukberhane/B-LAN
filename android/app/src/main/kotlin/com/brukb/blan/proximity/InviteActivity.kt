package com.brukb.blan.proximity

import android.app.Activity
import android.app.AlertDialog
import android.os.Bundle

/**
 * Full-screen translucent invite sheet. Shown only when overlay + full-screen
 * intent are granted; relays Accept/Decline to [InviteBus]. No secrets here —
 * just nick and the 6-digit code.
 */
class InviteActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val nick = intent.getStringExtra("nick") ?: "Unknown peer"
        val code = intent.getStringExtra("code") ?: "------"
        AlertDialog.Builder(this)
            .setTitle("Invite from $nick")
            .setMessage("Code: $code")
            .setPositiveButton("Accept") { dialog, _ ->
                dialog.dismiss()
                InviteBus.accept()
                finish()
            }
            .setNegativeButton("Decline") { dialog, _ ->
                dialog.dismiss()
                InviteBus.decline()
                finish()
            }
            .setOnCancelListener {
                InviteBus.decline()
                finish()
            }
            .show()
    }
}