package com.brukb.blan.proximity

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Host for the proximity channel family:
 * - MethodChannel `com.brukb.blan/proximity`
 * - EventChannels `…/scans`, `…/inbound`, `…/frames`, `…/inviteResult`
 *
 * Frames are opaque JSON strings; Dart owns signing and decoding.
 * Radio failures reply `Map{error: <code>}` — Dart maps to
 * PrivateNetworkException. The join passphrase is never logged.
 */
class ProximityPlugin(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    private val main = Handler(Looper.getMainLooper())
    private val radioPool = Executors.newCachedThreadPool()

    private val ble = BleRadio(context) { peerHandle, advert, scanResponse ->
        main.post {
            scanSink?.success(
                mapOf(
                    "peerHandle" to peerHandle,
                    "advert" to advert,
                    "scanResponse" to scanResponse,
                ),
            )
        }
    }

    private val control = ControlRadio(
        context,
        onInboundLink = { linkId, transport ->
            Log.i("blan-ctl", "inbound link id=$linkId transport=$transport")
            main.post { inboundSink?.success(mapOf("linkId" to linkId, "transport" to transport)) }
        },
        onFrame = { linkId, json ->
            Log.i(
                "blan-ctl",
                "frame link=$linkId bytes=${json.take(120)}",
            )
            main.post { frameSink?.success(mapOf("linkId" to linkId, "frameJson" to json)) }
        },
        onLinkClosed = { linkId ->
            Log.i("blan-ctl", "link closed id=$linkId")
        },
    )

    private val wifi = WifiRadios(context)
    private val shizuku = ShizukuBridge(context)

    private var scanSink: EventChannel.EventSink? = null
    private var inboundSink: EventChannel.EventSink? = null
    private var frameSink: EventChannel.EventSink? = null
    private var inviteSink: EventChannel.EventSink? = null

    private val methodChannel =
        MethodChannel(messenger, "com.brukb.blan/proximity").also { channel ->
            channel.setMethodCallHandler(::onMethodCall)
        }

    private val scanEvents = EventChannel(messenger, "com.brukb.blan/proximity/scans").also {
        it.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                scanSink = sink
            }

            override fun onCancel(args: Any?) {
                scanSink = null
            }
        })
    }

    private val inboundEvents = EventChannel(messenger, "com.brukb.blan/proximity/inbound").also {
        it.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                inboundSink = sink
            }

            override fun onCancel(args: Any?) {
                inboundSink = null
            }
        })
    }

    private val frameEvents = EventChannel(messenger, "com.brukb.blan/proximity/frames").also {
        it.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                frameSink = sink
            }

            override fun onCancel(args: Any?) {
                frameSink = null
            }
        })
    }

    private val inviteEvents = EventChannel(messenger, "com.brukb.blan/proximity/inviteResult").also {
        it.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                inviteSink = sink
                InviteBus.sink = { accepted ->
                    main.post { sink.success(if (accepted) "accept" else "decline") }
                }
            }

            override fun onCancel(args: Any?) {
                InviteBus.sink = null
                inviteSink = null
            }
        })
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startAdvert" -> {
                val payload = call.argument<ByteArray>("payload")
                val scanResponse = call.argument<ByteArray>("scanResponse")
                val dualAdvert = call.argument<Boolean>("dualAdvert") ?: true
                if (payload == null || scanResponse == null) {
                    result.success(mapOf("error" to "badArgs"))
                    return
                }
                try {
                    ble.startAdvert(payload, scanResponse, dualAdvert)
                    result.success(null)
                } catch (error: Exception) {
                    result.success(mapOf("error" to "advertFailed"))
                }
            }

            "stopAdvert" -> {
                ble.stopAdvert()
                result.success(null)
            }

            "startScan" -> {
                try {
                    ble.startScan()
                    result.success(null)
                } catch (error: Exception) {
                    result.success(mapOf("error" to "scanFailed"))
                }
            }

            "stopScan" -> {
                ble.stopScan()
                result.success(null)
            }

            "connectControl" -> {
                val peerHandle = call.argument<String>("peerHandle")
                val transport = call.argument<String>("transport") ?: "rfcomm"
                if (peerHandle == null) {
                    result.success(mapOf("error" to "badArgs"))
                    return
                }
                Log.i("blan-ctl", "connect to $peerHandle transport=$transport")
                radioPool.execute {
                    try {
                        val link = control.connect(peerHandle, transport)
                        Log.i("blan-ctl", "connect ok linkId=${link.id}")
                        main.post { result.success(link.id) }
                    } catch (error: Exception) {
                        Log.w("blan-ctl", "connect failed: $error", error)
                        main.post { result.success(mapOf("error" to "connectFailed")) }
                    }
                }
            }

            "startListening" -> {
                try {
                    control.startListening()
                    Log.i("blan-ctl", "listening (rfcomm + gatt server)")
                    result.success(null)
                } catch (error: Exception) {
                    Log.w("blan-ctl", "listen failed: $error", error)
                    result.success(mapOf("error" to "listenFailed"))
                }
            }

            "stopListening" -> {
                control.stopListening()
                result.success(null)
            }

            "sendFrame" -> {
                val linkId = call.argument<Int>("linkId")
                val frameJson = call.argument<String>("frameJson")
                if (linkId == null || frameJson == null) {
                    result.success(mapOf("error" to "badArgs"))
                    return
                }
                radioPool.execute {
                    try {
                        control.sendFrame(linkId, frameJson)
                        main.post { result.success(null) }
                    } catch (error: Exception) {
                        Log.w("blan-ctl", "send failed link=$linkId: $error", error)
                        main.post { result.success(mapOf("error" to "sendFailed")) }
                    }
                }
            }

            "closeLink" -> {
                val linkId = call.argument<Int>("linkId")
                if (linkId == null) {
                    result.success(mapOf("error" to "badArgs"))
                    return
                }
                control.closeLink(linkId)
                result.success(null)
            }

            "startHotspot" -> radioPool.execute {
                try {
                    val creds = wifi.startHotspot()
                    main.post {
                        result.success(
                            mapOf(
                                "ssid" to creds.ssid,
                                "passphrase" to creds.passphrase,
                                "security" to creds.security,
                            ),
                        )
                    }
                } catch (error: WifiRadios.RadioException) {
                    main.post { result.success(mapOf("error" to error.code)) }
                } catch (error: Exception) {
                    main.post { result.success(mapOf("error" to "hotspotFailed")) }
                }
            }

            "stopHotspot" -> {
                radioPool.execute {
                    wifi.stopHotspot()
                    main.post { result.success(null) }
                }
            }

            "startWifiDirect" -> radioPool.execute {
                try {
                    val creds = wifi.startWifiDirect()
                    main.post {
                        result.success(
                            mapOf(
                                "ssid" to creds.ssid,
                                "passphrase" to creds.passphrase,
                                "security" to creds.security,
                            ),
                        )
                    }
                } catch (error: WifiRadios.RadioException) {
                    main.post { result.success(mapOf("error" to error.code)) }
                } catch (error: Exception) {
                    main.post { result.success(mapOf("error" to "wifiDirectFailed")) }
                }
            }

            "stopWifiDirect" -> {
                radioPool.execute {
                    wifi.stopWifiDirect()
                    main.post { result.success(null) }
                }
            }

            "join" -> {
                val ssid = call.argument<String>("ssid")
                val passphrase = call.argument<String>("passphrase")
                val security = call.argument<String>("security") ?: "wpa2-psk"
                val localOnly = call.argument<Boolean>("localOnly") ?: true
                if (ssid == null || passphrase == null) {
                    result.success(mapOf("error" to "badArgs"))
                    return
                }
                radioPool.execute {
                    try {
                        if (!localOnly && shizuku.connectPersonal(ssid, passphrase, security)) {
                            Log.i("blan-ctl", "lan shizuku connect ok")
                            main.post { result.success(null) }
                            return@execute
                        }
                        if (!localOnly) {
                            Log.w("blan-ctl", "lan shizuku connect miss, wifi panel")
                        }
                        wifi.join(ssid, passphrase, security, localOnly)
                        main.post { result.success(null) }
                    } catch (error: WifiRadios.RadioException) {
                        main.post { result.success(mapOf("error" to error.code)) }
                    } catch (error: Exception) {
                        main.post { result.success(mapOf("error" to "joinFailed")) }
                    }
                }
            }

            "leaveJoined" -> {
                radioPool.execute {
                    wifi.leaveJoined()
                    main.post { result.success(null) }
                }
            }

            "showInvite" -> {
                val nick = call.argument<String>("nick") ?: "Unknown peer"
                val code = call.argument<String>("code") ?: "------"
                val foreground = call.argument<Boolean>("foreground") ?: false
                val inviteIntent = InviteIntent(
                    useLanTheirs = call.argument<Boolean>("useLanTheirs") ?: false,
                    useLanMine = call.argument<Boolean>("useLanMine") ?: false,
                    usePrivateNetwork =
                        call.argument<Boolean>("usePrivateNetwork") ?: false,
                )
                try {
                    val path =
                        InvitePresenter.showInvite(context, nick, code, foreground, inviteIntent)
                    result.success(path)
                } catch (error: Exception) {
                    result.success(mapOf("error" to "inviteFailed"))
                }
            }

            "hasFullScreenIntent" ->
                result.success(InvitePresenter.hasFullScreenIntent(context))

            "hasOverlayPermission" ->
                result.success(InvitePresenter.hasOverlayPermission(context))

            "requestInvitePermissions" -> {
                InvitePresenter.requestInvitePermissions(context)
                result.success(null)
            }

            "shizukuFacts" -> result.success(shizuku.facts())

            "shizukuStartListening" -> {
                shizuku.startListening()
                result.success(null)
            }

            "shizukuStopListening" -> {
                shizuku.stopListening()
                result.success(null)
            }

            "shizukuState" -> result.success(shizuku.state())

            "shizukuRequestPermission" -> radioPool.execute {
                val reply = try {
                    shizuku.requestPermission()
                } catch (_: Exception) {
                    mapOf("result" to "error", "message" to "Failed to request Shizuku permission")
                }
                main.post { result.success(reply) }
            }

            "confirmShizukuUse" -> shizuku.confirm(ShizukuBridge.activity) { allowed ->
                main.post {
                    if (allowed == null) {
                        result.error(
                            "noActivity",
                            "Shizuku consent needs a resumed activity",
                            null,
                        )
                    } else {
                        result.success(allowed)
                    }
                }
            }

            "readPersonalPsk" -> radioPool.execute {
                val creds = try {
                    shizuku.readPersonalPsk(wifi.currentSsid())
                } catch (_: Exception) {
                    null
                }
                Log.i(
                    "blan-ctl",
                    "readPersonalPsk ssid=${creds?.get("ssid") ?: "-"} psk=${if (creds?.get("passphrase").isNullOrEmpty()) "no" else "yes"}",
                )
                main.post { result.success(creds) }
            }

            "currentSsid" -> radioPool.execute {
                val ssid = try {
                    wifi.currentSsid()
                        ?: shizuku.readPersonalPsk(null)?.get("ssid")?.takeIf { it.isNotEmpty() }
                } catch (_: Exception) {
                    null
                }
                Log.i("blan-ctl", "currentSsid=${ssid ?: "-"}")
                main.post { result.success(ssid) }
            }

            else -> result.notImplemented()
        }
    }

    fun dispose() {
        InviteBus.sink = null
        shizuku.stopListening()
        ble.shutdown()
        wifi.shutdown()
        control.shutdown()
        radioPool.shutdown()
        InvitePresenter.cancelNotification(context)
        methodChannel.setMethodCallHandler(null)
        listOf(scanEvents, inboundEvents, frameEvents, inviteEvents).forEach {
            it.setStreamHandler(null)
        }
    }
}