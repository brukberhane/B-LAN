package com.brukb.blan.proximity

import android.annotation.SuppressLint
import android.content.Context
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.os.Build
import org.json.JSONObject
import java.util.BitSet

/**
 * Runs inside the Shizuku user-service process (shell uid). Hidden WifiManager
 * getters only return a personal PSK from that identity. Never log the result.
 */
class WifiPskService : IWifiPsk.Stub() {
    override fun readPersonal(): String {
        return try {
            val context = currentApplication() ?: return ""
            val manager =
                context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val config = connectedConfig(manager) ?: return ""
            personalJson(config) ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    override fun destroy() {}

    private fun currentApplication(): Context? {
        val thread = Class.forName("android.app.ActivityThread")
        val method = thread.getMethod("currentApplication")
        return method.invoke(null) as? Context
    }

    @SuppressLint("MissingPermission")
    private fun connectedConfig(manager: WifiManager): WifiConfiguration? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val method = WifiManager::class.java.getMethod("getPrivilegedConnectedNetwork")
            val connected = method.invoke(manager) as? WifiConfiguration
            if (connected != null) {
                return connected
            }
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }
        val method = WifiManager::class.java.getMethod("getPrivilegedConfiguredNetworks")
        val networks = method.invoke(manager) as? List<*> ?: return null
        @Suppress("DEPRECATION")
        val current = stripQuotes(manager.connectionInfo?.ssid)
        if (current.isNullOrEmpty()) {
            return null
        }
        return networks.filterIsInstance<WifiConfiguration>().firstOrNull { config ->
            stripQuotes(config.SSID) == current
        }
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
        val passphrase = stripQuotes(config.preSharedKey) ?: return null
        if (ssid.isEmpty() || passphrase.isEmpty() || passphrase == "*") {
            return null
        }
        val security = if (sae) "wpa3-sae" else "wpa2-psk"
        return JSONObject()
            .put("ssid", ssid)
            .put("passphrase", passphrase)
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
}
