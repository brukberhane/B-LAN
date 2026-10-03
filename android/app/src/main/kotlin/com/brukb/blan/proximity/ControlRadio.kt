package com.brukb.blan.proximity

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.Context
import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Classic Bluetooth RFCOMM control channel with a GATT fallback.
 * Frames are length-prefixed JSON maps; this layer is an opaque pipe —
 * Dart owns signing and decoding. No system pairing dialog: insecure sockets only.
 */
class ControlRadio(
    private val context: Context,
    private val onInboundLink: (linkId: Int, transport: String) -> Unit,
    private val onFrame: (linkId: Int, json: String) -> Unit,
    private val onLinkClosed: (linkId: Int) -> Unit,
) {
    private val adapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private val nextLinkId = AtomicInteger(1)
    private val links = ConcurrentHashMap<Int, Link>()
    private val ioPool = Executors.newCachedThreadPool()
    private var serverSocket: BluetoothServerSocket? = null
    private var gattServer: BluetoothGattServer? = null
    private var listening = false

    // GATT server: per-client append buffers keyed by device address.
    private val gattServerBuffers = mutableMapOf<String, ByteBuffer>()
    // GATT client connections keyed by device address.
    private val gattClients = ConcurrentHashMap<String, GattClient>()
    private val linksByGattHandle = ConcurrentHashMap<String, Int>()

    class Link internal constructor(
        val id: Int,
        val transport: String,
        val writer: (ByteArray) -> Unit,
        val closer: () -> Unit,
    )

    @SuppressLint("MissingPermission")
    fun startListening() {
        if (listening) return
        val adapter = adapter ?: throw IllegalStateException("no Bluetooth adapter")
        listening = true
        serverSocket =
            adapter.listenUsingInsecureRfcommWithServiceRecord("blan-ctl", ProximityIds.RFCOMM_UUID)
        ioPool.execute {
            while (listening) {
                val socket = try {
                    serverSocket?.accept() ?: break
                } catch (_: Exception) {
                    break
                }
                val linkId = nextLinkId.getAndIncrement()
                attachStreamLink(linkId, "rfcomm", socket)
            }
        }
        startGattServer()
    }

    fun stopListening() {
        listening = false
        serverSocket?.let { socket ->
            ioPool.execute {
                try {
                    socket.close()
                } catch (_: Exception) {}
            }
        }
        serverSocket = null
        gattServer?.let {
            it.clearServices()
            it.close()
        }
        gattServer = null
        synchronized(gattServerBuffers) { gattServerBuffers.clear() }
    }

    @SuppressLint("MissingPermission")
    fun connect(peerHandle: String, transport: String): Link {
        val adapter = adapter ?: throw IllegalStateException("no Bluetooth adapter")
        val device: BluetoothDevice = try {
            adapter.getRemoteDevice(peerHandle)
        } catch (_: IllegalArgumentException) {
            throw IllegalStateException("bad peer handle $peerHandle")
        }
        val linkId = nextLinkId.getAndIncrement()
        return when (transport) {
            "rfcomm" -> {
                val socket =
                    device.createInsecureRfcommSocketToServiceRecord(ProximityIds.RFCOMM_UUID)
                socket.connect()
                attachStreamLink(linkId, transport, socket)
                links[linkId]!!
            }
            "gatt" -> attachGattClientLink(linkId, device)
            else -> throw IllegalArgumentException("unknown transport $transport")
        }
    }

    fun sendFrame(linkId: Int, json: String) {
        val link = links[linkId] ?: throw IllegalStateException("no link $linkId")
        val bytes = json.toByteArray(Charsets.UTF_8)
        val frame = ByteBuffer.allocate(4 + bytes.size)
            .putInt(bytes.size)
            .put(bytes)
            .array()
        link.writer(frame)
    }

    fun closeLink(linkId: Int) {
        links.remove(linkId)?.closer()
        onLinkClosed(linkId)
    }

    fun shutdown() {
        stopListening()
        links.keys.toList().forEach { closeLink(it) }
        ioPool.shutdown()
    }

    // --- RFCOMM ------------------------------------------------------------

    private fun attachStreamLink(linkId: Int, transport: String, socket: BluetoothSocket) {
        try {
            val output: OutputStream = socket.outputStream
            val input: InputStream = socket.inputStream
            val writeLock = Any()
            val writer = { frame: ByteArray ->
                synchronized(writeLock) {
                    output.write(frame)
                    output.flush()
                }
            }
            val closer = {
                try {
                    socket.close()
                } catch (_: Exception) {}
            }
            links[linkId] = Link(linkId, transport, writer, closer)
            onInboundLink(linkId, transport)
            ioPool.execute { readStream(linkId, input) }
        } catch (_: Exception) {
            onLinkClosed(linkId)
        }
    }

    private fun readStream(linkId: Int, input: InputStream) {
        try {
            while (true) {
                val header = ByteArray(4)
                var read = 0
                while (read < 4) {
                    val n = input.read(header, read, 4 - read)
                    if (n < 0) return
                    read += n
                }
                val length = ByteBuffer.wrap(header).int
                if (length <= 0 || length > 64 * 1024) return
                val body = ByteArray(length)
                read = 0
                while (read < length) {
                    val n = input.read(body, read, length - read)
                    if (n < 0) return
                    read += n
                }
                onFrame(linkId, String(body, Charsets.UTF_8))
            }
        } catch (_: Exception) {
        } finally {
            links.remove(linkId)
            onLinkClosed(linkId)
        }
    }

    // --- GATT fallback -----------------------------------------------------

    private fun startGattServer() {
        val manager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager ?: return
        val server = manager.openGattServer(context, object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(
                device: BluetoothDevice,
                status: Int,
                newState: Int,
            ) {
                if (newState == BluetoothProfile.STATE_CONNECTED) return
                val handle = device.address
                synchronized(gattServerBuffers) { gattServerBuffers.remove(handle) }
                linksByGattHandle.remove(handle)?.let { linkId ->
                    links.remove(linkId)
                    onLinkClosed(linkId)
                }
            }

            @Deprecated("pre-T overload")
            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray,
            ) {
                if (offset != 0 ||
                    characteristic.uuid != ProximityIds.GATT_CHARACTERISTIC_UUID
                ) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_INVALID_OFFSET,
                        0,
                        value,
                    )
                    return
                }
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value)
                val frames = try {
                    synchronized(gattServerBuffers) {
                        val buffer = gattServerBuffers.getOrPut(device.address) {
                            ByteBuffer.allocate(64 * 1024)
                        }
                        buffer.put(value)
                        drainFrames(buffer)
                    }
                } catch (_: Exception) {
                    // Malformed / oversized write — drop the peer's reassembly
                    // buffer rather than crashing the app.
                    synchronized(gattServerBuffers) { gattServerBuffers.remove(device.address) }
                    return
                }
                frames.forEach { onFrame(linkIdFor(device.address), it) }
            }
        }) ?: return
        val service =
            BluetoothGattService(ProximityIds.GATT_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val characteristic = BluetoothGattCharacteristic(
            ProximityIds.GATT_CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
        )
        service.addCharacteristic(characteristic)
        server.addService(service)
        gattServer = server
    }

    private var gattServerNextLinkId = 10_000

    private fun linkIdFor(handle: String): Int {
        val existing = linksByGattHandle[handle]
        if (existing != null) return existing
        val linkId = gattServerNextLinkId++
        linksByGattHandle[handle] = linkId
        links[linkId] = Link(linkId, "gatt", { _ -> }, {})
        onInboundLink(linkId, "gatt")
        return linkId
    }

    private fun drainFrames(buffer: ByteBuffer): List<String> {
        val out = mutableListOf<String>()
        buffer.flip()
        while (buffer.remaining() >= 4) {
            buffer.mark()
            val length = buffer.int
            if (length <= 0 || length > 64 * 1024) {
                // Hostile length prefix — kill the peer's reassembly buffer.
                throw IllegalStateException("bad frame length $length")
            }
            if (buffer.remaining() < length) {
                buffer.reset()
                break
            }
            val body = ByteArray(length)
            buffer.get(body)
            out.add(String(body, Charsets.UTF_8))
        }
        buffer.compact()
        return out
    }

    @SuppressLint("MissingPermission")
    private fun attachGattClientLink(linkId: Int, device: BluetoothDevice): Link {
        val holder = GattClientHolder()
        val writer = { frame: ByteArray ->
            holder.client?.write(frame) ?: throw IllegalStateException("gatt link not ready")
        }
        val closer: () -> Unit = { holder.client?.close() }
        val link = Link(linkId, "gatt", writer, closer)
        val ready = CountDownLatch(1)
        val gatt = device.connectGatt(context, false, object : BluetoothGattCallback() {
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    g.discoverServices()
                } else {
                    onLinkClosed(linkId)
                }
            }

            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                val characteristic = g
                    .getService(ProximityIds.GATT_SERVICE_UUID)
                    ?.getCharacteristic(ProximityIds.GATT_CHARACTERISTIC_UUID)
                if (characteristic == null) {
                    ready.countDown()
                    return
                }
                val newClient = GattClient(linkId, g, characteristic, onLinkClosed)
                gattClients[device.address] = newClient
                holder.client = newClient
                g.requestMtu(247)
                links[linkId] = link
                ready.countDown()
                onInboundLink(linkId, "gatt")
            }

            override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) {
                holder.client?.onMtuChanged(mtu)
            }

            @Deprecated("pre-T overload")
            override fun onCharacteristicWrite(
                g: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                gattClients[device.address]?.onWriteDone()
            }
        })
        if (!ready.await(8, TimeUnit.SECONDS) || holder.client == null) {
            gatt.close()
            throw IllegalStateException("gatt connect timeout")
        }
        return link
    }

    /** Holder written on the GATT binder thread, read after the ready latch. */
    private class GattClientHolder {
        @Volatile
        var client: GattClient? = null
    }

    /** GATT client side: queues frame chunks and writes them one at a time. */
    private class GattClient(
        val linkId: Int,
        private val gatt: BluetoothGatt,
        private val characteristic: BluetoothGattCharacteristic,
        private val onClosed: (Int) -> Unit,
    ) {
        private val pending = ArrayDeque<ByteArray>()
        private var writing = false
        private var closed = false

        /** Effective payload size = negotiated ATT MTU - 3 opcode/header bytes. */
        @Volatile
        private var chunkSize = 20

        fun onMtuChanged(mtu: Int) {
            if (mtu > 23) chunkSize = mtu - 3
        }

        fun write(frame: ByteArray) {
            synchronized(pending) {
                if (closed) throw IllegalStateException("link closed")
                var offset = 0
                while (offset < frame.size) {
                    val end = minOf(offset + chunkSize, frame.size)
                    pending.add(frame.copyOfRange(offset, end))
                    offset = end
                }
                if (!writing) pump()
            }
        }

        private fun pump() {
            val chunk = pending.removeFirstOrNull() ?: return
            writing = true
            characteristic.value = chunk
            val ok = gatt.writeCharacteristic(characteristic)
            if (!ok) {
                writing = false
                fail()
            }
        }

        fun onWriteDone() {
            synchronized(pending) {
                writing = false
                try {
                    pump()
                } catch (_: Exception) {
                    fail()
                }
            }
        }

        private fun fail() {
            closed = true
            onClosed(linkId)
        }

        fun close() {
            synchronized(pending) {
                closed = true
                pending.clear()
            }
            try {
                gatt.close()
            } catch (_: Exception) {}
        }
    }
}