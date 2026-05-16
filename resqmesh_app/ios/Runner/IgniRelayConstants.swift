import Foundation
import CoreBluetooth

/// 烽傳 IgniRelay BLE Mesh 共用常數 (iOS).
///
/// UUID 透過 UUIDv5 (NAMESPACE_DNS + "ignirelay.com") 算出，與
/// `lib/app/mesh/mesh_constants.dart` 及
/// `android/.../IgniRelayConstants.kt` 鎖定一致。
enum IgniRelayConstants {
    // MARK: - BLE GATT UUID
    static let SERVICE_UUID       = CBUUID(string: "a4d11949-49d0-5230-96bb-43dd95d2cb2e")
    static let EVENT_CHAR_UUID    = CBUUID(string: "a932d89d-c24c-5d11-8320-55374c7feb74")
    static let BLOOM_CHAR_UUID    = CBUUID(string: "9b60940f-ca37-5c28-8620-42a89e7fdca7")
    static let HANDSHAKE_CHAR_UUID = CBUUID(string: "24b532d3-243f-5b61-92b0-50af4cf0bd1a")
    static let CCCD_UUID          = CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")

    // MARK: - BLE 連線參數
    static let REQUEST_MTU = 517
    static let MTU_REQUEST_DELAY_MS = 200

    // ═══════════════════════════════════════════════════════════════════
    // v0.3 Stage 0c — App-level chunking + envelope budgets
    // Spec: docs/specs/native_transport_v1_2026-05-13.md §4.6
    // Spec: docs/specs/envelope_v2_spec_2026-05-13.md §9
    //
    // Cross-platform single source of truth. Mirrored in:
    //   - lib/app/mesh/mesh_constants.dart
    //   - android/.../IgniRelayConstants.kt
    // CI guard tool/check_constants_parity.dart greps each file and fails
    // on divergence. Do not change a value here without updating both
    // sibling files.
    // ═══════════════════════════════════════════════════════════════════

    /// Wire protocol version. v0.3 uses EventEnvelope v2.
    static let PROTOCOL_VERSION_V2 = 2

    /// Hard cap on serialized envelope size (NORMAL priority cap).
    static let MAX_ENVELOPE_BYTES = 2048

    /// Chunk header = envelope_id (16) + chunk_index (1) + total_chunks (1).
    static let CHUNK_HEADER_SIZE = 18

    /// Bytes consumed by the BLE ATT header on a notify PDU.
    static let ATT_HEADER_SIZE = 3

    /// Maximum number of chunks per envelope.
    static let MAX_CHUNKS_PER_ENVELOPE = 16

    /// Reassembly timeout — partial chunks past this are discarded.
    static let REASSEMBLY_TIMEOUT_MS = 30_000

    /// Hard cap on total in-flight reassembly state per device.
    static let MAX_REASSEMBLY_BUFFER_BYTES = 65_536

    /// Hard cap on number of in-flight envelope_ids being reassembled.
    static let MAX_REASSEMBLY_BUFFER_ENTRIES = 64

    // MARK: - SOS / priority budgets

    /// SOS_RED / SOS_YELLOW / STATUS envelope budget (locked §20.6).
    static let SOS_ENVELOPE_BUDGET_BYTES = 240

    /// RESOURCE envelope budget.
    static let RESOURCE_ENVELOPE_BUDGET_BYTES = 400

    /// ALERT envelope budget (CAP messages).
    static let ALERT_ENVELOPE_BUDGET_BYTES = 800

    // MARK: - HELLO timing

    /// PROTOCOL_HELLO fallback timer (§5.2 §15.2). Starts at service-discovery-complete.
    static let HELLO_FALLBACK_TIMEOUT_MS = 5_000

    /// 10s subscribe→Bloom fallback (§3.2.5 §15.4).
    static let SUBSCRIBE_BLOOM_FALLBACK_MS = 10_000
}
