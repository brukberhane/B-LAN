package com.brukb.blan

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.brukb.blan/platform"
    private val sharingChannelName = "com.brukb.blan/sharing"
    private var multicastLock: WifiManager.MulticastLock? = null
    private var sharingChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sharingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            sharingChannelName,
        )
        BlanForegroundService.setStopSharingListener {
            Handler(Looper.getMainLooper()).post {
                sharingChannel?.invokeMethod("stopSharing", null)
            }
        }
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

                    "listSafFiles" -> {
                        val treeUri = call.argument<String>("treeUri") ?: ""
                        try {
                            result.success(SafFiles.list(applicationContext, treeUri))
                        } catch (error: Exception) {
                            result.error("saf_list_failed", error.message, null)
                        }
                    }

                    "hashSafFile" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        val chunkSize = call.argument<Int>("chunkSize") ?: 0
                        try {
                            result.success(SafFiles.hash(applicationContext, uri, chunkSize))
                        } catch (error: Exception) {
                            result.error("saf_hash_failed", error.message, null)
                        }
                    }

                    "readSafFileRange" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        val offset = (call.argument<Number>("offset") ?: 0).toLong()
                        val length = (call.argument<Number>("length") ?: 0).toInt()
                        try {
                            result.success(
                                SafFiles.readRange(
                                    applicationContext,
                                    uri,
                                    offset,
                                    length,
                                ),
                            )
                        } catch (error: Exception) {
                            result.error("saf_read_failed", error.message, null)
                        }
                    }

                    "safFileExists" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        try {
                            result.success(SafFiles.exists(applicationContext, uri))
                        } catch (error: Exception) {
                            result.success(false)
                        }
                    }

                    "defaultDownloadsDirectory" -> {
                        result.success(DownloadsPublisher.defaultDownloadsDir())
                    }

                    "downloadStagingDirectory" -> {
                        result.success(DownloadsPublisher.stagingDir(applicationContext))
                    }

                    "requiresDownloadStaging" -> {
                        val targetPath = call.argument<String>("targetPath") ?: ""
                        result.success(
                            DownloadsPublisher.requiresStaging(
                                targetPath,
                                applicationContext,
                            ),
                        )
                    }

                    "publishDownloadFile" -> {
                        val stagingPath = call.argument<String>("stagingPath") ?: ""
                        val targetPath = call.argument<String>("targetPath") ?: ""
                        val safTreePath = call.argument<String>("safTreePath")
                        val downloadsRoot = call.argument<String>("downloadsRoot")
                        try {
                            DownloadsPublisher.publishFile(
                                applicationContext,
                                stagingPath,
                                targetPath,
                                safTreePath,
                                downloadsRoot,
                            )
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("publish_download_failed", error.message, null)
                        }
                    }

                    "getDeviceName" -> {
                        result.success(resolveDeviceName(applicationContext))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun resolveDeviceName(context: Context): String {
        val globalName =
            Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
        if (!globalName.isNullOrBlank()) {
            return globalName.trim()
        }
        val bluetoothName =
            Settings.Secure.getString(context.contentResolver, "bluetooth_name")
        if (!bluetoothName.isNullOrBlank()) {
            return bluetoothName.trim()
        }
        return Build.MODEL.trim()
    }
}
