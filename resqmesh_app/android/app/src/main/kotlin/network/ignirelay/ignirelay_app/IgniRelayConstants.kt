package network.ignirelay.ignirelay_app

import java.util.UUID

/**
 * 烽傳 IgniRelay BLE Mesh 共用常數
 *
 * UUID 透過 UUIDv5 (NAMESPACE_DNS + "ignirelay.com") 算出，
 * 由 Dart uuid ^4.4.2 驗證，永久鎖定供手機端 & nRF54H20 韌體使用。
 */
object IgniRelayConstants {
    // ── BLE GATT UUID ──────────────────────────────────────────────────────
    val SERVICE_UUID: UUID     = UUID.fromString("a4d11949-49d0-5230-96bb-43dd95d2cb2e")
    val EVENT_CHAR_UUID: UUID  = UUID.fromString("a932d89d-c24c-5d11-8320-55374c7feb74")
    val BLOOM_CHAR_UUID: UUID  = UUID.fromString("9b60940f-ca37-5c28-8620-42a89e7fdca7")
    val HANDSHAKE_CHAR_UUID: UUID = UUID.fromString("24b532d3-243f-5b61-92b0-50af4cf0bd1a")
    val CCCD_UUID: UUID        = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    // ── BLE 連線參數 ───────────────────────────────────────────────────────
    const val REQUEST_MTU = 517
    const val MTU_REQUEST_DELAY_MS = 200L

    // ═════════════════════════════════════════════════════════════════════
    // v0.3 Stage 0c — App-level chunking + envelope budgets
    // Spec: docs/specs/native_transport_v1_2026-05-13.md §4.6
    // Spec: docs/specs/envelope_v2_spec_2026-05-13.md §9
    //
    // Cross-platform single source of truth. Mirrored in:
    //   - lib/app/mesh/mesh_constants.dart
    //   - ios/Runner/IgniRelayConstants.swift
    // CI guard tool/check_constants_parity.dart greps each file and fails
    // on divergence. Do not change a value here without updating both
    // sibling files.
    // ═════════════════════════════════════════════════════════════════════

    /** Wire protocol version. v0.3 uses EventEnvelope v2. */
    const val PROTOCOL_VERSION_V2 = 2

    /** Hard cap on serialized envelope size (NORMAL priority cap). */
    const val MAX_ENVELOPE_BYTES = 2048

    /** Chunk header = envelope_id (16) + chunk_index (1) + total_chunks (1). */
    const val CHUNK_HEADER_SIZE = 18

    /** Bytes consumed by the BLE ATT header on a notify PDU. */
    const val ATT_HEADER_SIZE = 3

    /** Maximum number of chunks per envelope. */
    const val MAX_CHUNKS_PER_ENVELOPE = 16

    /** Reassembly timeout — partial chunks past this are discarded. */
    const val REASSEMBLY_TIMEOUT_MS = 30_000L

    /** Hard cap on total in-flight reassembly state per device. */
    const val MAX_REASSEMBLY_BUFFER_BYTES = 65_536

    /** Hard cap on number of in-flight envelope_ids being reassembled. */
    const val MAX_REASSEMBLY_BUFFER_ENTRIES = 64

    // ── SOS / priority budgets ─────────────────────────────────────────

    /** SOS_RED / SOS_YELLOW / STATUS envelope budget (locked §20.6). */
    const val SOS_ENVELOPE_BUDGET_BYTES = 240

    /** RESOURCE envelope budget. */
    const val RESOURCE_ENVELOPE_BUDGET_BYTES = 400

    /** ALERT envelope budget (CAP messages). */
    const val ALERT_ENVELOPE_BUDGET_BYTES = 800

    // ── HELLO timing ───────────────────────────────────────────────────

    /** PROTOCOL_HELLO fallback timer (§5.2 §15.2). */
    const val HELLO_FALLBACK_TIMEOUT_MS = 5_000L

    /** 10s subscribe→Bloom fallback (§3.2.5 §15.4). */
    const val SUBSCRIBE_BLOOM_FALLBACK_MS = 10_000L
}
