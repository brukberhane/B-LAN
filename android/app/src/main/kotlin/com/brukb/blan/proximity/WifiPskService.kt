package com.brukb.blan.proximity

import android.annotation.SuppressLint
import android.content.AttributionSource
import android.content.Context
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Process
import android.util.Log
import org.json.JSONObject
import java.lang.reflect.InvocationHandler
import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Proxy
import java.util.BitSet
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Runs inside the Shizuku user-service process (shell uid). Hidden WifiManager
 * getters only return a personal PSK from that identity. Never log the passphrase.
 *
 * Shizuku v13+ prefers the [Context] constructor. [ActivityThread.currentApplication]
 * is often null in this process, which used to make every read return empty.
 */
class WifiPskService : IWifiPsk.Stub {
    private val appContext: Context?

    constructor() {
        appContext = currentApplication()
        Log.i("blan-ctl", "pskService ctor default ctx=${appContext != null}")
    }

    constructor(context: Context) {
        appContext = context.applicationContext ?: context
        Log.i("blan-ctl", "pskService ctor context pkg=${context.packageName}")
    }

    override fun readPersonal(ssidHint: String): String {
        return try {
            val context = appContext ?: currentApplication()
            if (context == null) {
                Log.w("blan-ctl", "pskService skip=noContext")
                return ""
            }
            val manager =
                context.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            if (manager == null) {
                Log.w("blan-ctl", "pskService skip=noWifiManager")
                return ""
            }
            val hint = ssidHint.trim().takeIf { it.isNotEmpty() && it != "<unknown ssid>" }
            Log.i("blan-ctl", "pskService uid=${Process.myUid()} hint=${hint ?: "-"}")
            val config = connectedConfig(manager, hint)
            if (config == null) {
                Log.w("blan-ctl", "pskService skip=noConfig hint=${hint ?: "-"}")
                return ""
            }
            personalJson(config) ?: run {
                Log.w(
                    "blan-ctl",
                    "pskService skip=notPersonal ssid=${stripQuotes(config.SSID) ?: "-"}",
                )
                ""
            }
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService skip=error ${error.javaClass.simpleName}: ${error.message}")
            ""
        }
    }

    override fun hasSaved(ssid: String): Boolean {
        if (ssid.isEmpty()) {
            return false
        }
        val listed = savedName(ssid)
        Log.i("blan-ctl", "pskService saved name=$ssid hit=$listed")
        return listed
    }

    /** `cmd wifi list-networks` prints SSIDs and security, never the passphrase. */
    private fun savedName(ssid: String): Boolean {
        return try {
            val proc = ProcessBuilder("cmd", "wifi", "list-networks")
                .redirectErrorStream(true)
                .start()
            val text = proc.inputStream.bufferedReader().use { it.readText() }
            if (!proc.waitFor(5, TimeUnit.SECONDS)) {
                proc.destroyForcibly()
            }
            text.lineSequence().any { line -> savedLineMatches(line, ssid) }
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService saved list ${rootCause(error)}")
            false
        }
    }

    private fun savedLineMatches(line: String, ssid: String): Boolean {
        val trimmed = line.trim()
        if (trimmed.isEmpty() || !trimmed[0].isDigit()) {
            return false
        }
        var body = trimmed.dropWhile { it.isDigit() }.trim()
        val marks = listOf("wpa3-sae^", "wpa3-sae", "wpa2-psk", "owe^", "wep", "owe", "open")
        for (mark in marks) {
            if (body.endsWith(mark)) {
                body = body.removeSuffix(mark).trim()
                break
            }
        }
        return body == ssid
    }

    override fun connectPersonal(ssid: String, passphrase: String, security: String): String {
        if (ssid.isEmpty() || passphrase.isEmpty()) {
            Log.w("blan-ctl", "pskService connect skip=badArgs")
            return ""
        }
        Log.i("blan-ctl", "pskService connect ssid=$ssid uid=${Process.myUid()}")
        val manager = wifiManagerOrNull()
        val config = wifiConfig(ssid, passphrase, security)
        // This process is shell (uid 2000). WifiManager from the app context
        // is attributed to com.brukb.blan and WifiService rejects it
        // ("Package com.brukb.blan does not belong to 2000"). Each step is
        // isolated so that rejection still reaches `cmd wifi`, which runs
        // as shell.
        if (manager != null &&
            connectStep("connect") { invokeConnect(manager, config) } &&
            waitForSsid(ssid, 8_000)
        ) {
            Log.i("blan-ctl", "pskService connect ok=connect")
            return "ok"
        }
        if (manager != null &&
            connectStep("addNetwork") { addAndEnable(manager, config) } &&
            waitForSsid(ssid, 8_000)
        ) {
            Log.i("blan-ctl", "pskService connect ok=addNetwork")
            return "ok"
        }
        if (connectStep("cmd") { cmdConnect(ssid, passphrase, security) } &&
            waitForSsid(ssid, 12_000)
        ) {
            Log.i("blan-ctl", "pskService connect ok=cmd")
            return "ok"
        }
        Log.w("blan-ctl", "pskService connect miss")
        return ""
    }

    private fun wifiManagerOrNull(): WifiManager? {
        return try {
            val context = appContext ?: currentApplication() ?: return null
            context.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService connect manager ${rootCause(error)}")
            null
        }
    }

    private fun connectStep(name: String, block: () -> Boolean): Boolean {
        return try {
            block()
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService connect $name error ${rootCause(error)}")
            false
        }
    }

    override fun destroy() {}

    private fun currentApplication(): Context? {
        return try {
            val thread = Class.forName("android.app.ActivityThread")
            val method = thread.getMethod("currentApplication")
            method.invoke(null) as? Context
        } catch (_: Exception) {
            null
        }
    }

    @SuppressLint("MissingPermission")
    private fun connectedConfig(
        manager: WifiManager,
        ssidHint: String?,
    ): WifiConfiguration? {
        val fromManager = wifiManagerConfig(manager, ssidHint)
        if (fromManager != null) {
            return fromManager
        }
        val fromBinder = iWifiManagerConfig(ssidHint)
        if (fromBinder != null) {
            return fromBinder
        }
        return null
    }

    private fun wifiManagerConfig(
        manager: WifiManager,
        ssidHint: String?,
    ): WifiConfiguration? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val method = WifiManager::class.java.getMethod("getPrivilegedConnectedNetwork")
                val connected = method.invoke(manager) as? WifiConfiguration
                Log.i(
                    "blan-ctl",
                    "pskService privilegedConnected ssid=${stripQuotes(connected?.SSID) ?: "-"}",
                )
                if (connected != null && matchesHint(connected, ssidHint)) {
                    return connected
                }
                if (connected != null && ssidHint == null) {
                    return connected
                }
            } catch (error: Exception) {
                Log.w("blan-ctl", "pskService privilegedConnected fail ${rootCause(error)}")
            }
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }
        val networks = try {
            val method = WifiManager::class.java.getMethod("getPrivilegedConfiguredNetworks")
            method.invoke(manager) as? List<*>
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService privilegedConfigured fail ${rootCause(error)}")
            null
        } ?: return pickConfig(emptyList(), ssidHint, manager)
        return pickConfig(networks.filterIsInstance<WifiConfiguration>(), ssidHint, manager)
    }

    /**
     * IWifiManager as this process (shell uid). Args match WiFiList, the
     * known-working Shizuku PSK reader: first string is the shell user name,
     * second is com.android.shell, extras carry AttributionSource(uid=2000).
     * Passing the app package makes WifiService throw
     * "Package com.brukb.blan does not belong to 2000". An empty extras
     * Bundle fails nearby-device attribution.
     */
    private fun iWifiManagerConfig(ssidHint: String?): WifiConfiguration? {
        val service = wifiBinder() ?: return null
        val connected = invokeWifi(service, "getPrivilegedConnectedNetwork")
        if (connected is WifiConfiguration && matchesHint(connected, ssidHint)) {
            Log.i(
                "blan-ctl",
                "pskService iWifi connected ssid=${stripQuotes(connected.SSID) ?: "-"}",
            )
            return connected
        }
        val slice = invokeWifi(service, "getPrivilegedConfiguredNetworks")
        val configs = sliceToConfigs(slice)
        Log.i("blan-ctl", "pskService iWifi configured n=${configs.size}")
        return pickConfig(configs, ssidHint, null)
    }

    private fun wifiBinder(): Any? {
        return try {
            val sm = Class.forName("android.os.ServiceManager")
            val raw = sm.getMethod("getService", String::class.java).invoke(null, "wifi") as IBinder
            val stub = Class.forName("android.net.wifi.IWifiManager\$Stub")
            stub.getMethod("asInterface", IBinder::class.java).invoke(null, raw)
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService iWifi bind fail ${rootCause(error)}")
            null
        }
    }

    private fun invokeWifi(service: Any, name: String): Any? {
        val methods = service.javaClass.methods.filter { it.name == name }
        if (methods.isEmpty()) {
            Log.w("blan-ctl", "pskService iWifi no method $name")
            return null
        }
        val user = when (Process.myUid()) {
            0 -> "root"
            1000 -> "system"
            else -> "shell"
        }
        val pkg = "com.android.shell"
        val extras = shellAttributionExtras(pkg)
        val stringOrders = listOf(
            listOf(user, pkg),
            listOf(pkg, pkg),
        )
        for (method in methods) {
            for (strings in stringOrders) {
                var stringAt = 0
                val args = method.parameterTypes.map { type ->
                    when (type) {
                        String::class.java -> strings[stringAt++.coerceAtMost(strings.lastIndex)]
                        Bundle::class.java -> extras
                        Integer.TYPE -> 0
                        java.lang.Boolean.TYPE -> false
                        else -> null
                    }
                }.toTypedArray()
                try {
                    method.isAccessible = true
                    return method.invoke(service, *args)
                } catch (error: Exception) {
                    Log.w(
                        "blan-ctl",
                        "pskService iWifi $name(${method.parameterTypes.joinToString { it.simpleName }}) ${strings[0]} ${rootCause(error)}",
                    )
                }
            }
        }
        return null
    }

    /** Same AttributionSource WiFiList stuffs in EXTRA_PARAM_KEY_ATTRIBUTION_SOURCE. */
    private fun shellAttributionExtras(pkg: String): Bundle {
        val uid = Process.myUid()
        val source = try {
            AttributionSource::class.java.getConstructor(
                Int::class.javaPrimitiveType,
                String::class.java,
                String::class.java,
                java.util.Set::class.java,
                AttributionSource::class.java,
            ).newInstance(uid, pkg, pkg, null, null) as AttributionSource
        } catch (_: Exception) {
            AttributionSource.Builder(uid).setPackageName(pkg).setAttributionTag(pkg).build()
        }
        return Bundle().apply {
            putParcelable("EXTRA_PARAM_KEY_ATTRIBUTION_SOURCE", source)
        }
    }

    private fun sliceToConfigs(slice: Any?): List<WifiConfiguration> {
        if (slice is List<*>) {
            return slice.filterIsInstance<WifiConfiguration>()
        }
        if (slice == null) {
            return emptyList()
        }
        return try {
            val list = slice.javaClass.getMethod("getList").invoke(slice) as? List<*>
            list?.filterIsInstance<WifiConfiguration>().orEmpty()
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService slice fail ${rootCause(error)}")
            emptyList()
        }
    }

    private fun pickConfig(
        configs: List<WifiConfiguration>,
        ssidHint: String?,
        manager: WifiManager?,
    ): WifiConfiguration? {
        if (configs.isNotEmpty()) {
            Log.i("blan-ctl", "pskService privilegedConfigured n=${configs.size}")
        }
        val current = ssidHint ?: stripQuotes(manager?.connectionInfo?.ssid)
        if (!current.isNullOrEmpty() && current != "<unknown ssid>") {
            val match = configs.firstOrNull { config ->
                stripQuotes(config.SSID) == current
            }
            if (match != null) {
                return match
            }
        }
        if (ssidHint != null) {
            return null
        }
        val personal = configs.filter { config ->
            val ssid = stripQuotes(config.SSID)
            !ssid.isNullOrEmpty() && config.status == WifiConfiguration.Status.CURRENT
        }
        return personal.singleOrNull()
    }

    private fun rootCause(error: Throwable): String {
        val cause = if (error is InvocationTargetException) error.cause ?: error else error
        val deep = generateSequence(cause) { it.cause }.last()
        return "${deep.javaClass.simpleName}: ${deep.message}"
    }

    private fun matchesHint(config: WifiConfiguration, ssidHint: String?): Boolean {
        if (ssidHint == null) {
            return true
        }
        return stripQuotes(config.SSID) == ssidHint
    }

    private fun personalJson(config: WifiConfiguration): String? {
        val bits: BitSet = config.allowedKeyManagement ?: return null
        if (bits.get(WifiConfiguration.KeyMgmt.WPA_EAP) ||
            bits.get(WifiConfiguration.KeyMgmt.IEEE8021X) ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                bits.get(WifiConfiguration.KeyMgmt.SUITE_B_192))
        ) {
            return null
        }
        val sae = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            bits.get(WifiConfiguration.KeyMgmt.SAE)
        val psk = bits.get(WifiConfiguration.KeyMgmt.WPA_PSK)
        if (!sae && !psk) {
            return null
        }
        val ssid = stripQuotes(config.SSID) ?: return null
        if (ssid.isEmpty()) {
            return null
        }
        val passphrase = stripQuotes(config.preSharedKey).orEmpty()
        val usable = passphrase.isNotEmpty() && passphrase != "*"
        val security = if (sae) "wpa3-sae" else "wpa2-psk"
        Log.i("blan-ctl", "pskService ssid=$ssid psk=${if (usable) "yes" else "no"}")
        return JSONObject()
            .put("ssid", ssid)
            .put("passphrase", if (usable) passphrase else "")
            .put("security", security)
            .toString()
    }

    private fun stripQuotes(value: String?): String? {
        if (value == null) {
            return null
        }
        return if (value.length >= 2 && value.startsWith("\"") && value.endsWith("\"")) {
            value.substring(1, value.length - 1)
        } else {
            value
        }
    }

    @Suppress("DEPRECATION")
    private fun wifiConfig(
        ssid: String,
        passphrase: String,
        security: String,
    ): WifiConfiguration {
        val config = WifiConfiguration()
        config.SSID = "\"$ssid\""
        config.preSharedKey = "\"$passphrase\""
        config.allowedAuthAlgorithms.set(WifiConfiguration.AuthAlgorithm.OPEN)
        if (security == "wpa3-sae" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.SAE)
        } else {
            config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
        }
        return config
    }

    private fun invokeConnect(manager: WifiManager, config: WifiConfiguration): Boolean {
        return try {
            val listenerClass = Class.forName("android.net.wifi.WifiManager\$ActionListener")
            val latch = CountDownLatch(1)
            val ok = java.util.concurrent.atomic.AtomicBoolean(false)
            val listener = Proxy.newProxyInstance(
                listenerClass.classLoader,
                arrayOf(listenerClass),
                InvocationHandler { _, method, args ->
                    when (method.name) {
                        "onSuccess" -> {
                            ok.set(true)
                            latch.countDown()
                        }
                        "onFailure" -> {
                            Log.w("blan-ctl", "pskService connect listener fail=${args?.firstOrNull()}")
                            latch.countDown()
                        }
                    }
                    null
                },
            )
            val connect = WifiManager::class.java.getMethod(
                "connect",
                WifiConfiguration::class.java,
                listenerClass,
            )
            connect.isAccessible = true
            connect.invoke(manager, config, listener)
            latch.await(8, TimeUnit.SECONDS)
            ok.get()
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService connect() miss ${rootCause(error)}")
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun addAndEnable(manager: WifiManager, config: WifiConfiguration): Boolean {
        return try {
            val netId = manager.addNetwork(config)
            Log.i("blan-ctl", "pskService addNetwork id=$netId")
            if (netId < 0) {
                return false
            }
            manager.enableNetwork(netId, true)
            manager.reconnect()
            true
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService addNetwork fail ${rootCause(error)}")
            false
        }
    }

    private fun cmdConnect(ssid: String, passphrase: String, security: String): Boolean {
        val mode = if (security == "wpa3-sae") "wpa3" else "wpa2"
        return try {
            val proc = ProcessBuilder(
                "cmd",
                "wifi",
                "connect-network",
                ssid,
                mode,
                passphrase,
            ).redirectErrorStream(true).start()
            val finished = proc.waitFor(15, TimeUnit.SECONDS)
            val code = if (finished) proc.exitValue() else -1
            if (!finished) {
                proc.destroyForcibly()
            }
            Log.i("blan-ctl", "pskService connect cmd exit=$code")
            code == 0
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService connect cmd fail ${error.javaClass.simpleName}")
            false
        }
    }

    private fun waitForSsid(ssid: String, budgetMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + budgetMs
        while (System.currentTimeMillis() < deadline) {
            if (observedSsid() == ssid) {
                return true
            }
            try {
                Thread.sleep(400)
            } catch (_: InterruptedException) {
                return observedSsid() == ssid
            }
        }
        return observedSsid() == ssid
    }

    /** App WifiManager throws from this uid. `cmd wifi status` does not. */
    private fun observedSsid(): String? {
        wifiManagerOrNull()?.let { manager ->
            try {
                val fromManager = stripQuotes(manager.connectionInfo?.ssid)
                if (!fromManager.isNullOrEmpty() && fromManager != "<unknown ssid>") {
                    return fromManager
                }
            } catch (error: Exception) {
                Log.w("blan-ctl", "pskService ssid manager ${rootCause(error)}")
            }
        }
        return try {
            val proc = ProcessBuilder("cmd", "wifi", "status")
                .redirectErrorStream(true)
                .start()
            val text = proc.inputStream.bufferedReader().use { it.readText() }
            if (!proc.waitFor(3, TimeUnit.SECONDS)) {
                proc.destroyForcibly()
            }
            val match = Regex("""SSID:\s*"?([^",\r\n]+)"?""").find(text) ?: return null
            val ssid = match.groupValues[1].trim()
            if (ssid.isEmpty() || ssid == "<unknown ssid>") null else ssid
        } catch (error: Exception) {
            Log.w("blan-ctl", "pskService ssid cmd ${rootCause(error)}")
            null
        }
    }
}
