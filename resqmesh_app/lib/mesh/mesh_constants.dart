/// 烽傳 IgniRelay BLE Mesh 常數定義
///
/// UUID 透過 UUIDv5 (NAMESPACE_DNS + "ignirelay.com") 算出，
/// 由 Dart uuid ^4.4.2 驗證，永久鎖定供手機端 & nRF54H20 韌體使用。
library;

// ── BLE GATT UUID ──────────────────────────────────────────────────────────

/// 烽傳主服務 UUID — UUIDv5(DNS, "ignirelay.com")
const String kResQMeshServiceUUID =
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
