package com.brukb.blan.proximity

import android.app.Activity
import android.app.AlertDialog
import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import org.json.JSONObject
import rikka.shizuku.Shizuku
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Binder client for Shevery / Shizuku. Package matching is decided in Dart
 * (`shizuku_detect.dart`); this class only collects facts and the binder state.
 * The passphrase is read in [WifiPskService] and never logged.
 */
class ShizukuBridge(private val context: Context) {
    @Volatile
    private var userConnection: ServiceConnection? = null
    private var userArgs: Shizuku.UserServiceArgs? = null

    fun startListening() {
        if (listening) return
        listening = true
        try {
            Shizuku.addBinderReceivedListenerSticky(binderReceived)
            Shizuku.addBinderDeadListener(binderDead)
            Shizuku.addRequestPermissionResultListener(permissionResult)
        } catch (_: Exception) {
        }
    }

    fun stopListening() {
        if (listening) {
            listening = false
            try {
                Shizuku.removeBinderReceivedListener(binderReceived)
                Shizuku.removeBinderDeadListener(binderDead)
                Shizuku.removeRequestPermissionResultListener(permissionResult)
            } catch (_: Exception) {
            }
        }
        unbind()
    }

    fun facts(): Map<String, Any> {
        return mapOf(
            "known" to knownFacts(),
            "candidates" to slowCandidates(),
        )
    }

    fun state(): String {
        startListening()
        return try {
            if (!Shizuku.pingBinder()) {
                return if (providerInstalled()) "dead" else "notInstalled"
            }
            if (Shizuku.isPreV11()) {
                return "tooOld"
            }
            if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                "ready"
            } else {
                "noPermission"
            }
        } catch (_: Exception) {
            if (providerInstalled()) "dead" else "notInstalled"
        }
    }

    fun requestPermission(): Map<String, Any?> {
        return try {
            when {
                !Shizuku.pingBinder() -> mapOf(
                    "result" to "error",
                    "message" to "Shizuku service is not running. Start it in the Shevery app, then try again.",
                )
                Shizuku.isPreV11() -> mapOf(
                    "result" to "error",
                    "message" to "This Shizuku/Shevery version is too old (pre-v11). Please update it.",
                )
                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED ->
                    mapOf("result" to "alreadyGranted")
                Shizuku.shouldShowRequestPermissionRationale() -> mapOf(
                    "result" to "error",
                    "message" to "Permission was denied. Grant it manually for this app in the Shevery app.",
                )
                else -> awaitPermission()
            }
        } catch (error: Exception) {
            mapOf(
                "result" to "error",
                "message" to (error.message ?: "Failed to request Shizuku permission"),
            )
        }
    }

    /**
     * [done] receives true/false for Allow / Not now. Null means the dialog
     * was not shown — callers must not persist that as a No.
     */
    fun confirm(activity: Activity?, done: (Boolean?) -> Unit) {
        if (activity == null) {
            done(null)
            return
        }
        activity.runOnUiThread {
            var delivered = false
            fun finish(value: Boolean) {
                if (delivered) return
                delivered = true
                done(value)
            }
            AlertDialog.Builder(activity)
                .setTitle("Read Wi-Fi password?")
                .setMessage(
                    "Allow B-LAN to read the current Wi-Fi password using Shevery or Shizuku?",
                )
                .setPositiveButton("Allow") { dialog, _ ->
                    dialog.dismiss()
                    finish(true)
                }
                .setNegativeButton("Not now") { dialog, _ ->
                    dialog.dismiss()
                    finish(false)
                }
                .setOnCancelListener { finish(false) }
                .show()
        }
    }

    fun readPersonalPsk(ssidHint: String? = null): Map<String, String>? {
        val raw = callUserService(8) { service -> service.readPersonal(ssidHint.orEmpty()) }
        val got = parsePersonal(raw)
        android.util.Log.i(
            "blan-ctl",
            "shizuku read ssid=${got?.get("ssid") ?: "-"} psk=${if (got?.get("passphrase").isNullOrEmpty()) "no" else "yes"}",
        )
        return got
    }

    /** Privileged STA switch. Passphrase stays in the binder call; never logged. */
    fun connectPersonal(ssid: String, passphrase: String, security: String): Boolean {
        if (ssid.isEmpty() || passphrase.isEmpty()) {
            return false
        }
        val reply = callUserService(40) { service ->
            service.connectPersonal(ssid, passphrase, security)
        }
        val ok = reply == "ok"
        android.util.Log.i("blan-ctl", "shizuku connect ssid=$ssid ok=$ok")
        return ok
    }

    private fun <T> callUserService(timeoutSec: Long, block: (IWifiPsk) -> T): T? {
        if (!ensureBinder() ||
            Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED
        ) {
            val ping = try {
                Shizuku.pingBinder()
            } catch (_: Exception) {
                false
            }
            android.util.Log.i(
                "blan-ctl",
                "shizuku call skipped ping=$ping state=${state()}",
            )
            return null
        }
        val latch = CountDownLatch(1)
        val holder = AtomicReference<T?>()
        val args = Shizuku.UserServiceArgs(
            ComponentName(context, WifiPskService::class.java),
        )
            .daemon(false)
            .processNameSuffix("psk")
            .debuggable(isDebuggable())
            .version(6)
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
                try {
                    holder.set(block(IWifiPsk.Stub.asInterface(service)))
                } catch (error: Exception) {
                    android.util.Log.w("blan-ctl", "shizuku user-service call failed: $error")
                    holder.set(null)
                } finally {
                    latch.countDown()
                }
            }

            override fun onServiceDisconnected(name: ComponentName?) {}
        }
        unbind()
        userArgs = args
        userConnection = connection
        return try {
            Shizuku.bindUserService(args, connection)
            val ok = latch.await(timeoutSec, TimeUnit.SECONDS)
            if (!ok) {
                android.util.Log.w("blan-ctl", "shizuku user-service bind timeout")
                null
            } else {
                holder.get()
            }
        } catch (error: Exception) {
            android.util.Log.w("blan-ctl", "shizuku bind failed: $error")
            null
        } finally {
            unbind()
        }
    }

    private fun awaitPermission(): Map<String, Any?> {
        val latch = CountDownLatch(1)
        val grant = AtomicReference<Int?>()
        val listener = Shizuku.OnRequestPermissionResultListener { code, resultCode ->
            if (code == REQUEST_CODE) {
                grant.set(resultCode)
                latch.countDown()
            }
        }
        Shizuku.addRequestPermissionResultListener(listener)
        return try {
            Shizuku.requestPermission(REQUEST_CODE)
            if (!latch.await(60, TimeUnit.SECONDS)) {
                mapOf("result" to "error", "message" to "Permission request timed out.")
            } else if (grant.get() == PackageManager.PERMISSION_GRANTED) {
                mapOf("result" to "alreadyGranted")
            } else {
                mapOf(
                    "result" to "error",
                    "message" to "Permission was denied. Grant it manually for this app in the Shevery app.",
                )
            }
        } finally {
            try {
                Shizuku.removeRequestPermissionResultListener(listener)
            } catch (_: Exception) {
            }
        }
    }

    /** Binder attach is triggered by the sticky listener; wait off the main thread. */
    private fun ensureBinder(): Boolean {
        fun ping(): Boolean = try {
            Shizuku.pingBinder()
        } catch (_: Exception) {
            false
        }
        if (ping()) {
            return true
        }
        startListening()
        repeat(10) {
            if (ping()) {
                return true
            }
            try {
                Thread.sleep(100)
            } catch (_: InterruptedException) {
                return ping()
            }
        }
        return ping()
    }

    private fun parsePersonal(raw: String?): Map<String, String>? {
        if (raw.isNullOrEmpty()) {
            return null
        }
        val json = JSONObject(raw)
        val ssid = json.optString("ssid")
        val passphrase = json.optString("passphrase")
        val security = json.optString("security")
        if (ssid.isEmpty() || security.isEmpty()) {
            return null
        }
        return mapOf("ssid" to ssid, "passphrase" to passphrase, "security" to security)
    }

    private fun unbind() {
        val args = userArgs
        val connection = userConnection
        userArgs = null
        userConnection = null
        if (args == null || connection == null) {
            return
        }
        try {
            Shizuku.unbindUserService(args, connection, true)
        } catch (_: Exception) {
        }
    }

    private fun providerInstalled(): Boolean {
        if (knownFacts().any { it["installed"] == true }) {
            return true
        }
        return slowCandidates().isNotEmpty()
    }

    private fun knownFacts(): List<Map<String, Any>> {
        val manager = context.packageManager
        return KNOWN_PACKAGES.map { name ->
            try {
                val info = packageInfo(manager, name, PackageManager.GET_PERMISSIONS)
                mapOf(
                    "name" to name,
                    "installed" to true,
                    "permissions" to (info.requestedPermissions?.toList() ?: emptyList()),
                )
            } catch (_: PackageManager.NameNotFoundException) {
                mapOf(
                    "name" to name,
                    "installed" to false,
                    "permissions" to emptyList<String>(),
                )
            }
        }
    }

    private fun slowCandidates(): List<Map<String, Any>> {
        val manager = context.packageManager
        val installed = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                manager.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                manager.getInstalledApplications(0)
            }
        } catch (_: Exception) {
            return emptyList()
        }
        val out = mutableListOf<Map<String, Any>>()
        for (app in installed) {
            if (app.packageName in KNOWN_PACKAGES) {
                continue
            }
            val fact = candidateFact(manager, app.packageName) ?: continue
            out.add(fact)
            if (out.size >= 20) {
                break
            }
        }
        return out
    }

    private fun candidateFact(manager: PackageManager, packageName: String): Map<String, Any>? {
        val flags = PackageManager.GET_PERMISSIONS or
            PackageManager.GET_PROVIDERS or
            PackageManager.GET_RECEIVERS
        val info = try {
            packageInfo(manager, packageName, flags)
        } catch (_: Exception) {
            return null
        }
        val permissions = info.requestedPermissions?.toList() ?: emptyList()
        val authorities = info.providers?.mapNotNull { it.authority } ?: emptyList()
        val providerNames = info.providers?.mapNotNull { it.name } ?: emptyList()
        val receiverNames = info.receivers?.mapNotNull { it.name } ?: emptyList()
        val permissionHit = permissions.any { it.contains("moe.shizuku.manager.permission") }
        val providerHit = (authorities + providerNames).any {
            it.contains("shizuku", ignoreCase = true)
        }
        val receiverHit = receiverNames.any { it.contains("ShizukuReceiver", ignoreCase = true) }
        if (!permissionHit && !providerHit && !receiverHit) {
            return null
        }
        return mapOf(
            "name" to packageName,
            "permissions" to permissions,
            "authorities" to authorities,
            "providerNames" to providerNames,
            "receiverNames" to receiverNames,
        )
    }

    private fun packageInfo(manager: PackageManager, name: String, flags: Int) =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            manager.getPackageInfo(name, PackageManager.PackageInfoFlags.of(flags.toLong()))
        } else {
            @Suppress("DEPRECATION")
            manager.getPackageInfo(name, flags)
        }

    private fun isDebuggable(): Boolean {
        val flags = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE
        return flags != 0
    }

    private val binderReceived = Shizuku.OnBinderReceivedListener { }
    private val binderDead = Shizuku.OnBinderDeadListener { }
    private val permissionResult = Shizuku.OnRequestPermissionResultListener { _, _ -> }

    companion object {
        const val REQUEST_CODE = 7001
        private val KNOWN_PACKAGES = listOf(
            "com.hamondev.shevery",
            "moe.shizuku.privileged.api",
            "moe.shizuku.manager",
        )

        @Volatile
        var activity: Activity? = null

        private var listening = false
    }
}
