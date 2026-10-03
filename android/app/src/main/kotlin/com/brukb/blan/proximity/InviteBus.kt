package com.brukb.blan.proximity

/**
 * One-shot bus from the invite surfaces (dialog activity / notification action
 * receiver) back to the plugin, which forwards to Dart's inviteResult stream.
 */
object InviteBus {
    @Volatile
    var sink: ((accepted: Boolean) -> Unit)? = null

    fun accept() {
        sink?.invoke(true)
        sink = null
    }

    fun decline() {
        sink?.invoke(false)
        sink = null
    }
}