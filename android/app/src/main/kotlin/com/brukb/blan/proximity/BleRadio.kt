package com.brukb.blan.proximity

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSet
import android.bluetooth.le.AdvertisingSetCallback
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanRecord
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid

/**
 * BLE advert/scan. The advert payload is already packed by Dart (31 bytes).
 * Android runs two sets: one extended non-scannable packet with the payload
 * and the nick as service data (phones receive that reliably), plus one legacy
 * set with the first 16 payload bytes (the rest is zero padding, and a legacy
 * PDU cannot fit all 31) and the nick in its scan response — some desktop
 * controllers, notably Intel AX211 on BlueZ 5.87, never deliver the extended
 * aux packet. Scanners accept 31 or 16 bytes and pad 16 to 31. Never a
 * fingerprint or a PSK.
 */
class BleRadio(
    private val context: Context,
    private val onScanHit: (peerHandle: String, advert: ByteArray, scanResponse: ByteArray) -> Unit,
) {
    private val adapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private var advertiser: BluetoothLeAdvertiser? = null
    private var legacyAdvertiseCallback: AdvertiseCallback? = null
    private var advertiseSetCallback: AdvertisingSetCallback? = null
    private var legacySetCallback: AdvertisingSetCallback? = null
    /** Set by async advertise callbacks; surfaced on the next startAdvert reply. */
    @Volatile
    var advertiseError: String? = null
    private var scanner: BluetoothLeScanner? = null
    private var scanCallback: ScanCallback? = null

    fun startAdvert(payload: ByteArray, scanResponse: ByteArray, dualAdvert: Boolean) {
        val advertiser = adapter?.bluetoothLeAdvertiser
            ?: throw IllegalStateException("no BLE advertiser")
        stopAdvert()
        advertiseError = null
        this.advertiser = advertiser
        // Bytes past 15 are zero padding; a legacy PDU cannot fit all 31.
        val trimmed = if (payload.size > 16) payload.copyOf(16) else payload
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addManufacturerData(ProximityIds.MANUFACTURER_ID, payload)
            .addServiceData(ParcelUuid(ProximityIds.BLE_SERVICE_UUID), scanResponse)
            .build()

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            // 31-byte manufacturer data does not fit a legacy PDU. One extended
            // packet holds the payload and the nick. Scannable would split them.
            // Connectable: an unbonded peer can only open a GATT connection
            // while this device advertises connectable — the control channel
            // rides that connection, so the advert must be connectable.
            val parameters = AdvertisingSetParameters.Builder()
                .setInterval(AdvertisingSetParameters.INTERVAL_MEDIUM)
                .setTxPowerLevel(AdvertisingSetParameters.TX_POWER_MEDIUM)
                .setConnectable(true)
                .setScannable(false)
                .setLegacyMode(false)
                .build()
            val callback = object : AdvertisingSetCallback() {
                override fun onAdvertisingSetStarted(set: AdvertisingSet?, txPower: Int, status: Int) {
                    if (status != AdvertisingSetCallback.ADVERTISE_SUCCESS) {
                        advertiseError = "advertise set failed: $status"
                    }
                }
            }
            advertiseSetCallback = callback
            advertiser.startAdvertisingSet(parameters, data, null, null, null, callback)

            // Second legacy set for scanners that never deliver the extended
            // aux packet (Intel AX211 + BlueZ 5.87). Legacy PDUs are universally
            // received; the trimmed payload fits and the nick rides the scan
            // response, which legacy scanners merge into one record. The
            // "Extra legacy advert" setting can turn this set off.
            if (!dualAdvert) {
                return
            }
            val legacyParameters = AdvertisingSetParameters.Builder()
                .setInterval(AdvertisingSetParameters.INTERVAL_MEDIUM)
                .setTxPowerLevel(AdvertisingSetParameters.TX_POWER_MEDIUM)
                .setConnectable(false)
                .setScannable(true)
                .setLegacyMode(true)
                .build()
            val legacyData = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addManufacturerData(ProximityIds.MANUFACTURER_ID, trimmed)
                .build()
            val legacyResponse = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceData(ParcelUuid(ProximityIds.BLE_SERVICE_UUID), scanResponse)
                .build()
            val legacyCallback = object : AdvertisingSetCallback() {
                override fun onAdvertisingSetStarted(set: AdvertisingSet?, txPower: Int, status: Int) {
                    if (status != AdvertisingSetCallback.ADVERTISE_SUCCESS) {
                        advertiseError = "legacy advertise set failed: $status"
                    }
                }
            }
            legacySetCallback = legacyCallback
            advertiser.startAdvertisingSet(
                legacyParameters, legacyData, legacyResponse, null, null, legacyCallback,
            )
        } else {
            // Pre-O PDUs are 31 bytes, so the trimmed payload and the nick in
            // the scan response are the only fit.
            val response = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceData(ParcelUuid(ProximityIds.BLE_SERVICE_UUID), scanResponse)
                .build()
            val legacyData = AdvertiseData.Builder()
                .addManufacturerData(ProximityIds.MANUFACTURER_ID, trimmed)
                .build()
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(false)
                .build()
            val callback = object : AdvertiseCallback() {
                override fun onStartFailure(errorCode: Int) {
                    advertiseError = "advertise failed: $errorCode"
                }
            }
            legacyAdvertiseCallback = callback
            advertiser.startAdvertising(settings, legacyData, response, callback)
        }
    }

    fun stopAdvert() {
        val advertiser = this.advertiser
        advertiseSetCallback?.let { advertiser?.stopAdvertisingSet(it) }
        legacySetCallback?.let { advertiser?.stopAdvertisingSet(it) }
        legacyAdvertiseCallback?.let { advertiser?.stopAdvertising(it) }
        advertiseSetCallback = null
        legacySetCallback = null
        legacyAdvertiseCallback = null
        this.advertiser = null
    }

    @SuppressLint("MissingPermission")
    fun startScan() {
        val scanner = adapter?.bluetoothLeScanner
            ?: throw IllegalStateException("no BLE scanner")
        stopScan()
        this.scanner = scanner
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            .apply {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    // Default scans are legacy-only and miss the extended advert.
                    setLegacy(false)
                }
            }
            .build()
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val record: ScanRecord = result.scanRecord ?: return
                val raw = record.getManufacturerSpecificData(ProximityIds.MANUFACTURER_ID)
                    ?: return
                // The extended set sends 31 bytes, the legacy set the first 16.
                val payload = when (raw.size) {
                    31 -> raw
                    16 -> raw.copyOf(31) // copyOf pads with zeros.
                    else -> return
                }
                val scanResponse = record.getServiceData(ParcelUuid(ProximityIds.BLE_SERVICE_UUID))
                    ?: ByteArray(0)
                onScanHit(result.device.address, payload, scanResponse)
            }
        }
        scanCallback = callback
        // No controller filter. An empty manufacturer mask drops extended hits.
        scanner.startScan(null, settings, callback)
    }

    fun stopScan() {
        scanCallback?.let { scanner?.stopScan(it) }
        scanCallback = null
        scanner = null
    }

    fun shutdown() {
        stopAdvert()
        stopScan()
    }
}