package com.brukb.blan

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.brukb.blan/platform"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticastLock" -> {
                        val wifi =
                            applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        if (multicastLock == null) {
                            multicastLock = wifi.createMulticastLock("blan-mdns").apply {
                                setReferenceCounted(true)
                            }
                        }
                        multicastLock?.acquire()
                        result.success(true)
                    }

                    "releaseMulticastLock" -> {
                        multicastLock?.let {
                            if (it.isHeld) {
                                it.release()
                            }
                        }
                        result.success(null)
                    }

                    "startForeground" -> {
                        val taskId = call.argument<String>("taskId") ?: "default"
                        val title = call.argument<String>("title") ?: "B-LAN"
                        val body = call.argument<String>("body") ?: ""
                        BlanForegroundService.start(this, taskId, title, body)
                        result.success(null)
                    }

                    "updateForeground" -> {
                        val taskId = call.argument<String>("taskId") ?: "default"
                        val title = call.argument<String>("title") ?: "B-LAN"
                        val body = call.argument<String>("body") ?: ""
                        BlanForegroundService.update(this, taskId, title, body)
                        result.success(null)
                    }

                    "stopForeground" -> {
                        val taskId = call.argument<String>("taskId") ?: "default"
                        BlanForegroundService.stop(this, taskId)
                        result.success(null)
                    }

                    "statSafFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        val stats = SafFileStats.stat(path)
                        result.success(stats)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
