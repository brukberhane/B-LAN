package com.brukb.blan.proximity

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.WifiNetworkSuggestion
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Local-only hotspot, Wi-Fi Direct group, and network join.
 * Blocking methods — the plugin calls these on a worker thread.
 * The passphrase is never logged.
 */
class WifiRadios(private val context: Context) {
    private val wifiManager =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    @Volatile
    private var disposed = false
    @Volatile
    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null
    @Volatile
    private var p2pChannel: WifiP2pManager.Channel? = null
    @Volatile
    private var p2pManager: WifiP2pManager? = null

    /** Final teardown: late async callbacks see this and self-close. */
    fun shutdown() {
        disposed = true
        stopHotspot()
        stopWifiDirect()
        leaveJoined()
    }

    // --- Hotspot -----------------------------------------------------------

    @SuppressLint("MissingPermission")
    fun startHotspot(): Creds {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val nearby = context.checkSelfPermission(android.Manifest.permission.NEARBY_WIFI_DEVICES)
            val granted = nearby == android.content.pm.PackageManager.PERMISSION_GRANTED
            Log.i("blan-ctl", "hotspot nearbyWifi=$granted")
            if (!granted) {
                throw RadioException("hotspotFailed")
            }
        }
        stopHotspot()
        val started = CountDownLatch(1)
        val holder = AtomicReference<WifiManager.LocalOnlyHotspotReservation?>()
        val failure = AtomicReference<Int?>()
        wifiManager.startLocalOnlyHotspot(
            object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation) {
                    if (disposed) {
                        try {
                            res.close()
                        } catch (_: Exception) {}
                        started.countDown()
                        return
                    }
                    holder.set(res)
                    started.countDown()
                }

                override fun onFailed(reason: Int) {
                    Log.w("blan-ctl", "hotspot onFailed reason=$reason")
                    failure.set(reason)
                    started.countDown()
                }

                override fun onStopped() {
                    reservation?.let { res ->
                        reservation = null
                        try {
                            res.close()
                        } catch (_: Exception) {}
                    }
                }
            },
            Handler(Looper.getMainLooper()),
        )
        if (!started.await(20, TimeUnit.SECONDS)) {
            Log.w("blan-ctl", "hotspot timeout")
            throw RadioException("hotspotFailed")
        }
        failure.get()?.let { reason ->
            Log.w("blan-ctl", "hotspot failed reason=$reason")
            throw RadioException("hotspotFailed")
        }
        val res = holder.get() ?: throw RadioException("hotspotFailed")
        reservation = res
        val creds = credsFromReservation(res)
        if (creds == null) {
            Log.w("blan-ctl", "hotspot missing creds")
            res.close()
            reservation = null
            throw RadioException("hotspotFailed")
        }
        return creds
    }

    fun stopHotspot() {
        reservation?.let { res ->
            reservation = null
            try {
                res.close()
            } catch (_: Exception) {}
        }
    }

    private fun credsFromReservation(
        res: WifiManager.LocalOnlyHotspotReservation,
    ): Creds? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val config = res.softApConfiguration ?: return fallbackCreds(res)
            val ssid = config.ssid
            val passphrase = config.passphrase
            if (ssid.isNullOrEmpty() || passphrase.isNullOrEmpty()) return null
            return Creds(ssid, passphrase, "wpa2-psk")
        }
        return fallbackCreds(res)
    }

    @Deprecated("pre-R path")
    private fun fallbackCreds(res: WifiManager.LocalOnlyHotspotReservation): Creds? {
        val config: WifiConfiguration? = try {
            @Suppress("DEPRECATION")
            res.wifiConfiguration
        } catch (_: Exception) {
            null
        } ?: return null
        val ssid = config?.SSID?.removeSurrounding("\"") ?: return null
        val passphrase = config.preSharedKey ?: return null
        if (ssid.isEmpty() || passphrase.isEmpty()) return null
        return Creds(ssid, passphrase, "wpa2-psk")
    }

    // --- Wi-Fi Direct ------------------------------------------------------

    @SuppressLint("MissingPermission")
    fun startWifiDirect(): Creds {
        stopWifiDirect()
        val manager = p2pManager
            ?: (context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager)
                ?.also { p2pManager = it }
            ?: throw RadioException("wifiDirectFailed")
        val channel = p2pChannel ?: manager.initialize(context, Looper.getMainLooper(), null).also {
            p2pChannel = it
        }
        val created = CountDownLatch(1)
        val createFailed = AtomicReference<Boolean>()
        manager.createGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                created.countDown()
            }

            override fun onFailure(reason: Int) {
                createFailed.set(true)
                created.countDown()
            }
        })
        if (!created.await(20, TimeUnit.SECONDS) || createFailed.get() == true) {
            throw RadioException("wifiDirectFailed")
        }
        // Group creation is async internally; poll group info briefly (~10s budget).
        var group: android.net.wifi.p2p.WifiP2pGroup? = null
        for (attempt in 0..9) {
            val latch = CountDownLatch(1)
            val holder = AtomicReference<android.net.wifi.p2p.WifiP2pGroup?>()
            manager.requestGroupInfo(channel) { info ->
                holder.set(info)
                latch.countDown()
            }
            latch.await(1, TimeUnit.SECONDS)
            val info = holder.get()
            if (info != null && !info.networkName.isNullOrEmpty()) {
                group = info
                break
            }
            Thread.sleep(100)
        }
        val networkName = group?.networkName
        val passphrase = group?.passphrase
        if (group == null || networkName.isNullOrEmpty() || passphrase.isNullOrEmpty()) {
            throw RadioException("wifiDirectFailed")
        }
        return Creds(networkName, passphrase, "wpa2-psk")
    }

    fun stopWifiDirect() {
        val manager = p2pManager ?: return
        val channel = p2pChannel ?: return
        try {
            manager.removeGroup(channel, null)
        } catch (_: Exception) {}
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                channel.close()
            }
        } catch (_: Exception) {}
        p2pChannel = null
    }

    // --- Join --------------------------------------------------------------

    fun join(ssid: String, passphrase: String, security: String, localOnly: Boolean) {
        if (localOnly) {
            joinSpecifier(ssid, passphrase, security)
            return
        }
        joinLan(ssid, passphrase, security)
    }

    /** Save PSK, open the system Wi-Fi panel, wait until the STA SSID matches. */
    private fun joinLan(ssid: String, passphrase: String, security: String) {
        try {
            suggestNetwork(ssid, passphrase, security)
        } catch (_: RadioException) {
            android.util.Log.w("blan-ctl", "lan suggestion persist failed")
        }
        android.util.Log.i("blan-ctl", "lan wifi panel")
        val intent = Intent(Settings.Panel.ACTION_WIFI).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        val deadline = SystemClock.elapsedRealtime() + 60_000L
        while (SystemClock.elapsedRealtime() < deadline) {
            if (currentSsid() == ssid) {
                android.util.Log.i("blan-ctl", "lan ssid match")
                return
            }
            Thread.sleep(400)
        }
        throw RadioException("joinFailed")
    }

    /** Saved network, no passphrase: open the system Wi-Fi sheet and wait for the SSID. */
    fun waitOnWifiPanel(ssid: String) {
        Log.i("blan-ctl", "lan wifi panel saved")
        val intent = Intent(Settings.Panel.ACTION_WIFI).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        val deadline = SystemClock.elapsedRealtime() + 60_000L
        while (SystemClock.elapsedRealtime() < deadline) {
            if (currentSsid() == ssid) {
                Log.i("blan-ctl", "lan ssid match")
                return
            }
            Thread.sleep(400)
        }
        throw RadioException("joinFailed")
    }

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    @Volatile
    private var joinedCallback: ConnectivityManager.NetworkCallback? = null
    @Volatile
    private var joinedNetwork: Network? = null
    @Volatile
    private var suggestion: WifiNetworkSuggestion? = null

    private fun joinSpecifier(
        ssid: String,
        passphrase: String,
        security: String,
    ) {
        // WifiNetworkSpecifier is API 29+; the 3-arg requestNetwork (timeout)
        // is API 28+. Older devices cannot join a local-only network.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw RadioException("joinFailed")
        }
        leaveJoined()
        val builder = WifiNetworkSpecifier.Builder().setSsid(ssid)
        if (security == "wpa3-sae") {
            builder.setWpa3Passphrase(passphrase)
        } else {
            builder.setWpa2Passphrase(passphrase)
        }
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(builder.build())
            .build()
        val available = CountDownLatch(1)
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                joinedNetwork = network
                try {
                    connectivityManager.bindProcessToNetwork(network)
                } catch (_: Exception) {
                }
                android.util.Log.i("blan-ctl", "joinSpecifier onAvailable")
                available.countDown()
            }

            override fun onUnavailable() {
                android.util.Log.w("blan-ctl", "joinSpecifier onUnavailable")
                available.countDown()
            }
        }
        joinedCallback = callback
        android.util.Log.i("blan-ctl", "joinSpecifier")
        connectivityManager.requestNetwork(request, callback, 60_000)
        if (!available.await(65, TimeUnit.SECONDS) || joinedNetwork == null) {
            leaveJoined()
            throw RadioException("joinFailed")
        }
    }

    private fun suggestNetwork(ssid: String, passphrase: String, security: String) {
        val builder = WifiNetworkSuggestion.Builder().setSsid(ssid)
        if (security == "wpa3-sae") {
            builder.setWpa3Passphrase(passphrase)
        } else {
            builder.setWpa2Passphrase(passphrase)
        }
        val suggestion = builder.build()
        val result = wifiManager.addNetworkSuggestions(listOf(suggestion))
        android.util.Log.i("blan-ctl", "suggestNetwork status=$result")
        if (result != WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS &&
            result != WifiManager.STATUS_NETWORK_SUGGESTIONS_ERROR_ADD_DUPLICATE
        ) {
            throw RadioException("joinFailed")
        }
        this.suggestion = suggestion
    }

    fun leaveJoined() {
        try {
            connectivityManager.bindProcessToNetwork(null)
        } catch (_: Exception) {
        }
        joinedCallback?.let { cb ->
            joinedCallback = null
            joinedNetwork = null
            try {
                connectivityManager.unregisterNetworkCallback(cb)
            } catch (_: Exception) {}
        }
        suggestion?.let { s ->
            suggestion = null
            try {
                wifiManager.removeNetworkSuggestions(listOf(s))
            } catch (_: Exception) {}
        }
    }

    /** Connected SSID, or null when unknown / off / redacted. Never a passphrase. */
    @SuppressLint("MissingPermission")
    /**
     * Saved-SSID check from this app's identity. No passphrase is read.
     * Android 10+ usually returns an empty list here; the shell list is the
     * fallback in [ShizukuBridge].
     */
    @Suppress("DEPRECATION")
    fun hasSavedSsid(ssid: String): Boolean {
        if (ssid.isEmpty()) {
            return false
        }
        val configs = ArrayList<WifiConfiguration>()
        try {
            wifiManager.configuredNetworks?.let { configs.addAll(it) }
        } catch (error: Exception) {
            Log.w("blan-ctl", "savedNetworks app ${error.javaClass.simpleName}")
        }
        if (configs.isEmpty()) {
            configs.addAll(semConfigured())
        }
        val hit = configs.any { config ->
            sanitizeSsid(config.SSID) == ssid && config.networkId >= 0
        }
        Log.i("blan-ctl", "savedNetworks app n=${configs.size} hit=$hit")
        return hit
    }

    /** Switch using a saved network id. No passphrase. Returns false when the platform rejects it. */
    @Suppress("DEPRECATION")
    fun connectSavedById(ssid: String): Boolean {
        val id = try {
            wifiManager.configuredNetworks
                ?.firstOrNull { sanitizeSsid(it.SSID) == ssid && it.networkId >= 0 }
                ?.networkId
        } catch (_: Exception) {
            null
        } ?: semConfigured().firstOrNull { sanitizeSsid(it.SSID) == ssid && it.networkId >= 0 }
            ?.networkId
        if (id == null) {
            return false
        }
        val enabled = try {
            wifiManager.enableNetwork(id, true)
        } catch (error: Exception) {
            Log.w("blan-ctl", "saved connect id=$id ${error.javaClass.simpleName}")
            false
        }
        Log.i("blan-ctl", "saved connect id=$id enabled=$enabled")
        if (!enabled) {
            return false
        }
        try {
            wifiManager.reconnect()
        } catch (_: Exception) {}
        val deadline = SystemClock.elapsedRealtime() + 8_000L
        while (SystemClock.elapsedRealtime() < deadline) {
            if (currentSsid() == ssid) {
                return true
            }
            Thread.sleep(400)
        }
        return currentSsid() == ssid
    }

    @Suppress("DEPRECATION")
    private fun semConfigured(): List<WifiConfiguration> {
        return try {
            val sem = context.getSystemService("sem_wifi") ?: return emptyList()
            val method = sem.javaClass.methods.firstOrNull { candidate ->
                candidate.name == "getConfiguredNetworks" && candidate.parameterTypes.isEmpty()
            } ?: return emptyList()
            val raw = method.invoke(sem) as? List<*> ?: return emptyList()
            raw.filterIsInstance<WifiConfiguration>()
        } catch (error: Exception) {
            Log.w("blan-ctl", "savedNetworks sem ${error.javaClass.simpleName}")
            emptyList()
        }
    }

    fun currentSsid(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val network = connectivityManager.activeNetwork
            val caps = connectivityManager.getNetworkCapabilities(network)
            val info = caps?.transportInfo as? WifiInfo
            sanitizeSsid(info?.ssid)?.let { return it }
        }
        @Suppress("DEPRECATION")
        return sanitizeSsid(wifiManager.connectionInfo?.ssid)
    }

    private fun sanitizeSsid(raw: String?): String? {
        if (raw.isNullOrEmpty()) return null
        val ssid = if (raw.length >= 2 && raw.startsWith("\"") && raw.endsWith("\"")) {
            raw.substring(1, raw.length - 1)
        } else {
            raw
        }
        if (ssid.isEmpty() || ssid == "<unknown ssid>") return null
        return ssid
    }

    data class Creds(val ssid: String, val passphrase: String, val security: String)

    class RadioException(val code: String) : Exception(code)
}