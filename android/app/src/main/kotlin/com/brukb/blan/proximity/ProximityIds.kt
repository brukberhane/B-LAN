package com.brukb.blan.proximity

import java.util.UUID

/** Shared ids for the nearby proximity radios. Must match Dart. */
object ProximityIds {
    /** 16-bit manufacturer data id carrying the 31-byte advert payload. */
    const val MANUFACTURER_ID = 0xFDA9

    /** BLE service UUID advertised alongside the manufacturer data. */
    val BLE_SERVICE_UUID: UUID = UUID.fromString("0000fda9-0000-1000-8000-00805f9b34fb")

    /** Classic Bluetooth RFCOMM control channel. */
    val RFCOMM_UUID: UUID = UUID.fromString("8e0c4a52-6d6e-4e4e-9f4c-3b2b1a0b5d01")

    /** GATT fallback control channel. */
    val GATT_SERVICE_UUID: UUID = UUID.fromString("9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7b")
    val GATT_CHARACTERISTIC_UUID: UUID = UUID.fromString("9f1c2b3a-4d5e-4f60-8a1b-2c3d4e5f6a7c")

    /** Client Characteristic Configuration descriptor: enables notify. */
    val CLIENT_CONFIG_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
}