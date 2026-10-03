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
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanRecord
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid

/**
 * BLE advert/scan. The advert payload is already packed by Dart (31 bytes);
 * nick rides in the scan response. Never a fingerprint or a PSK.
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
    /** Set by async advertise callbacks; surfaced on the next startAdvert reply. */
    @Volatile
    var advertiseError: String? = null
    private var scanner: BluetoothLeScanner? = null
    private var scanCallback: ScanCallback? = null

    fun startAdvert(payload: ByteArray, scanResponse: ByteArray) {
        val advertiser = adapter?.bluetoothLeAdvertiser
            ?: throw IllegalStateException("no BLE advertiser")
        stopAdvert()
        advertiseError = null
        this.advertiser = advertiser
        val data = AdvertiseData.Builder()
            .addManufacturerData(ProximityIds.MANUFACTURER_ID, payload)
            .build()
        val response = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceData(ParcelUuid(ProximityIds.BLE_SERVICE_UUID), scanResponse)
            .build()

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val parameters = AdvertisingSetParameters.Builder()
                .setInterval(AdvertisingSetParameters.INTERVAL_MEDIUM)
                .setTxPowerLevel(AdvertisingSetParameters.TX_POWER_MEDIUM)
                .build()
            val callback = object : AdvertisingSetCallback() {
                override fun onAdvertisingSetStarted(set: AdvertisingSet?, txPower: Int, status: Int) {
                    if (status != AdvertisingSetCallback.ADVERTISE_SUCCESS) {
                        advertiseError = "advertise set failed: $status"
                    }
                }
            }
            advertiseSetCallback = callback
            advertiser.startAdvertisingSet(parameters, data, response, null, null, callback)
        } else {
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
            advertiser.startAdvertising(settings, data, response, callback)
        }
    }

    fun stopAdvert() {
        val advertiser = this.advertiser
        advertiseSetCallback?.let { advertiser?.stopAdvertisingSet(it) }
        legacyAdvertiseCallback?.let { advertiser?.stopAdvertising(it) }
        advertiseSetCallback = null
        legacyAdvertiseCallback = null
        this.advertiser = null
    }

    @SuppressLint("MissingPermission")
    fun startScan() {
        val scanner = adapter?.bluetoothLeScanner
            ?: throw IllegalStateException("no BLE scanner")
        stopScan()
        this.scanner = scanner
        val filter = ScanFilter.Builder()
            .setManufacturerData(ProximityIds.MANUFACTURER_ID, ByteArray(0), ByteArray(0))
            .build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            .build()
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val record: ScanRecord = result.scanRecord ?: return
                val payload = record.getManufacturerSpecificData(ProximityIds.MANUFACTURER_ID)
                if (payload == null || payload.size != 31) return
                val scanResponse = record.getServiceData(ParcelUuid(ProximityIds.BLE_SERVICE_UUID))
                    ?: ByteArray(0)
                onScanHit(result.device.address, payload, scanResponse)
            }
        }
        scanCallback = callback
        scanner.startScan(listOf(filter), settings, callback)
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