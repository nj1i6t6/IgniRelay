package network.resqmesh.resqmesh_app

import java.util.UUID

/**
 * 烽傳 IgniRelay BLE Mesh 共用常數
 *
 * UUID 透過 UUIDv5 (NAMESPACE_DNS + "ignirelay.com") 算出，
 * 由 Dart uuid ^4.4.2 驗證，永久鎖定供手機端 & nRF54H20 韌體使用。
 */
object ResQMeshConstants {
    // ── BLE GATT UUID ──────────────────────────────────────────────────────
    val SERVICE_UUID: UUID     = UUID.fromString("a4d11949-49d0-5230-96bb-43dd95d2cb2e")
    val EVENT_CHAR_UUID: UUID  = UUID.fromString("a932d89d-c24c-5d11-8320-55374c7feb74")
    val BLOOM_CHAR_UUID: UUID  = UUID.fromString("9b60940f-ca37-5c28-8620-42a89e7fdca7")
    val HANDSHAKE_CHAR_UUID: UUID = UUID.fromString("24b532d3-243f-5b61-92b0-50af4cf0bd1a")
    val CCCD_UUID: UUID        = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    // ── BLE 連線參數 ───────────────────────────────────────────────────────
    const val REQUEST_MTU = 517
    const val MTU_REQUEST_DELAY_MS = 200L
}
