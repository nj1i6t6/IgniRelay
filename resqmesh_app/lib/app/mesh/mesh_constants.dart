/// 烽傳 IgniRelay BLE Mesh 常數定義
///
/// UUID 透過 UUIDv5 (NAMESPACE_DNS + "ignirelay.com") 算出，
/// 由 Dart uuid ^4.4.2 驗證，永久鎖定供手機端 & nRF54H20 韌體使用。
library;

// ── BLE GATT UUID ──────────────────────────────────────────────────────────

/// 烽傳主服務 UUID — UUIDv5(DNS, "ignirelay.com")
const String kIgniRelayServiceUUID =
    'a4d11949-49d0-5230-96bb-43dd95d2cb2e';

/// 事件傳輸通道 — UUIDv5(DNS, "ignirelay.com/event")
const String kEventCharUUID =
    'a932d89d-c24c-5d11-8320-55374c7feb74';

/// Bloom Filter 同步通道 — UUIDv5(DNS, "ignirelay.com/bloom")
const String kBloomCharUUID =
    '9b60940f-ca37-5c28-8620-42a89e7fdca7';

/// 實體交接握手通道 — UUIDv5(DNS, "ignirelay.com/handshake")
const String kHandshakeCharUUID =
    '24b532d3-243f-5b61-92b0-50af4cf0bd1a';

/// 標準 BLE CCCD (Client Characteristic Configuration Descriptor)
const String kCccdUUID =
    '00002902-0000-1000-8000-00805f9b34fb';

// ── BLE 連線參數 ──────────────────────────────────────────────────────────

/// MTU 請求大小（BLE 5.0+）
/// 手機對手機：通常協商到 517
/// 手機對 nRF54H20：協商到硬體支援的最大值（~247）
const int kRequestMtu = 517;

/// MTU 請求前等待時間（ms）— 參考 BitChat/Zemzeme 的 200ms 延遲策略
const int kMtuRequestDelayMs = 200;

/// 連線逾時（秒）
const int kConnectTimeoutSec = 10;

/// 節點冷卻時間（秒）— 連線同步後等待再次連線的間隔
const int kPeerCooldownSec = 60;

/// 最大同時連線數（防 GATT 133）
const int kMaxConcurrentConnections = 8;

/// 掃描間隔（秒）— 掃描結束後等待再次掃描
const int kScanRestartDelaySec = 5;

/// 掃描持續時間（秒）
const int kScanDurationSec = 30;

// ── 電量 Tier 定義 ──────────────────────────────────────────────────────────

/// Tier 1 (全功能) 電量門檻
const int kTier1MinBattery = 50;

/// Tier 2 (省電中繼) 電量門檻
const int kTier2MinBattery = 20;

/// 遲滯帶：需高於門檻 +10% 才升級，防止邊界震盪
const int kTierHysteresis = 10;

// ═════════════════════════════════════════════════════════════════════════════
// v0.3 Stage 0c — App-level chunking + envelope budgets
// Spec: docs/specs/native_transport_v1_2026-05-13.md §4.6 (decisions §15.3, §15.8)
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §9 (decisions §20.6)
//
// Cross-platform single source of truth. Mirrored in:
//   - android/.../IgniRelayConstants.kt
//   - ios/Runner/IgniRelayConstants.swift
// CI guard tool/check_constants_parity.dart greps each file and fails on
// divergence. Do not change a value here without updating the other two files.
// ═════════════════════════════════════════════════════════════════════════════

/// Wire protocol version. v0.3 uses EventEnvelope v2.
const int kProtocolVersionV2 = 2;

/// Hard cap on serialized envelope size (NORMAL priority cap; bounds reassembly).
const int kMaxEnvelopeBytes = 2048;

/// Chunk header size = envelope_id (16) + chunk_index (1) + total_chunks (1).
const int kChunkHeaderSize = 18;

/// Bytes consumed by the BLE ATT header on a notify PDU.
const int kAttHeaderSize = 3;

/// Maximum number of chunks per envelope. 16 × (185-3-18) = 2624 B headroom > 2048 cap.
const int kMaxChunksPerEnvelope = 16;

/// Reassembly buffer timeout — partial chunks past this are discarded.
const int kReassemblyTimeoutMs = 30000;

/// Hard cap on total in-flight reassembly state per device.
const int kMaxReassemblyBufferBytes = 65536;

/// Hard cap on number of in-flight envelope_ids being reassembled.
const int kMaxReassemblyBufferEntries = 64;

// ── SOS / priority budgets ──────────────────────────────────────────────────

/// SOS_RED / SOS_YELLOW / STATUS envelope budget (locked §20.6).
/// 240 B → 2 chunks at MTU=185 and 247; 1 chunk at MTU=512.
const int kSosEnvelopeBudgetBytes = 240;

/// RESOURCE envelope budget (match negotiation; chunking allowed but disfavor).
const int kResourceEnvelopeBudgetBytes = 400;

/// ALERT envelope budget (CAP messages; chunking required).
const int kAlertEnvelopeBudgetBytes = 800;

// ── HELLO timing ────────────────────────────────────────────────────────────

/// PROTOCOL_HELLO fallback timer (§5.2 §15.2). Starts at service-discovery-complete.
const int kHelloFallbackTimeoutMs = 5000;

/// 10s subscribe→Bloom fallback (§3.2.5 §15.4).
const int kSubscribeBloomFallbackMs = 10000;

// ── Tombstone / GC (envelope_v2_spec §13.4) ────────────────────────────────

/// Default grace period before an expired envelope becomes a tombstone.
const int kTombstoneGracePeriodDefaultMs = 60 * 60 * 1000; // 1 hour

/// SOS-class grace period (longer for diagnostic).
const int kTombstoneGracePeriodSosMs = 6 * 60 * 60 * 1000; // 6 hours

/// Chat-class grace period (decays fast).
const int kTombstoneGracePeriodChatMs = 5 * 60 * 1000; // 5 minutes

/// Tombstone TTL — kept after grace period to suppress IBLT/Bloom re-circulation.
const int kTombstoneTtlMs = 7 * 24 * 60 * 60 * 1000; // 7 days

/// Hard cap on tombstone rows; oldest evicted on overflow.
const int kMaxTombstoneRows = 100000;

/// Hard cap on envelope rows; defensive bound to keep DB lean.
const int kMaxEnvelopeRows = 50000;

/// Per-author rate limit (§13.7 §20.5). 120/h average; token bucket size 20.
const int kMaxEnvelopesPerAuthorPerHour = 120;
const int kAuthorRateLimitBucketSize = 20;

/// Mesh trace log retention.
const int kMeshTraceRetentionMs = 24 * 60 * 60 * 1000; // 24 hours
const int kMaxTraceRows = 200000;
