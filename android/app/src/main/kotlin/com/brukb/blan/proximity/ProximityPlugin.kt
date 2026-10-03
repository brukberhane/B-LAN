package com.brukb.blan.proximity

import android.content.Context
import android.os.Handler
import android.os.Looper
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
            main.post { inboundSink?.success(mapOf("linkId" to linkId, "transport" to transport)) }
        },
        onFrame = { linkId, json ->
            main.post { frameSink?.success(mapOf("linkId" to linkId, "frameJson" to json)) }
        },
        onLinkClosed = { _ ->
            // Link closure is surfaced by Dart when a send/read fails; nothing to push yet.
        },
    )

    private val wifi = WifiRadios(context)

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
                if (payload == null || scanResponse == null) {
                    result.success(mapOf("error" to "badArgs"))
                    return
                }
                try {
                    ble.startAdvert(payload, scanResponse)
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
                radioPool.execute {
                    try {
                        val link = control.connect(peerHandle, transport)
                        main.post { result.success(link.id) }
                    } catch (error: Exception) {
                        main.post { result.success(mapOf("error" to "connectFailed")) }
                    }
                }
            }

            "startListening" -> {
                try {
                    control.startListening()
                    result.success(null)
                } catch (error: Exception) {
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
                try {
                    val path = InvitePresenter.showInvite(context, nick, code)
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

            else -> result.notImplemented()
        }
    }

    fun dispose() {
        InviteBus.sink = null
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