# IgniRelay 烽傳 測試索引

> 所有可在電腦上執行的 unit test（不需實機/BLE 硬體）。
> 需要 VillageGeofence geodata asset 的測試已標記 `skip`，歸類為 integration test。

---

## 執行方式

```bash
cd ignirelay_app

# 全部跑
flutter test

# 只跑特定目錄
flutter test test/mesh/
flutter test test/pipeline/
flutter test test/event/

# 詳細輸出
flutter test --reporter=expanded
```

---

## 測試檔案一覽

### `test/mesh/` — 通訊層核心（純 Dart，無 DB/硬體）

| 檔案 | 測試項目 | 測試數量 |
|------|---------|---------|
| [wire_codec_test.dart](mesh/wire_codec_test.dart) | Protobuf encode/decode roundtrip、Legacy pipe fallback、邊界輸入不崩潰 | 17 |
| [bloom_filter_test.dart](mesh/bloom_filter_test.dart) | parseBloomFilter：單筆/多筆/空值/重複/CRLF | 8 |
| [triage_queue_test.dart](mesh/triage_queue_test.dart) | 優先級排序、SOS_RED preemption flag、overflow cap | 12 |
| [dedup_test.dart](mesh/dedup_test.dart) | hasSeen/markSeen/seenEventsCount singleton 狀態 | 6 |

### `test/crdt/` — 時鐘同步

| 檔案 | 測試項目 | 測試數量 |
|------|---------|---------|
| [hlc_extended_test.dart](crdt/hlc_extended_test.dart) | now() 單調性、merge() 行為、compareTo()、equality/hashCode | 15 |
| [crdt_test.dart](../test/crdt_test.dart) *(原有)* | HLC merge、衝突解析 | 5 |

### `test/medical/` — 醫療卡模型

| 檔案 | 測試項目 | 測試數量 |
|------|---------|---------|
| [medical_card_test.dart](medical/medical_card_test.dart) | hasData、序列化 roundtrip、applyPreset、AllergyEntry、EmergencyContact、MedicalField metadata | 22 |
| [medical_payload_test.dart](medical/medical_payload_test.dart) | buildMedicalPayload flag filtering → Protobuf MedicalSummary 欄位驗證 | 10 |

### `test/routing/` — 路由決策

| 檔案 | 測試項目 | 測試數量 |
|------|---------|---------|
| [routing_extended_test.dart](routing/routing_extended_test.dart) | Tier 0/1 豁免（hardware mule / Android tier1）、SOS_RED identity 豁免、quarantine 介面 | 10 |
| [routing_test.dart](../test/routing_test.dart) *(修正版)* | 豁免路徑 + 需要 VillageGeofence 的測試（skip） | 7（2 skip） |

### `test/pipeline/` — 上行管道（需要 sqflite_ffi）

| 檔案 | 測試項目 | 測試數量 |
|------|---------|---------|
| [up_pipeline_test.dart](pipeline/up_pipeline_test.dart) | BLE bytes → stream emit、receivedEventCount、hasSeen、DB 寫入、TTL decrement、去重、Hazard → Hazards_State、錯誤韌性、Legacy pipe | 14 |

### `test/event/` — 下行管道（需要 sqflite_ffi）

| 檔案 | 測試項目 | 測試數量 |
|------|---------|---------|
| [event_manager_test.dart](event/event_manager_test.dart) | publishEvent/Supply/Hazard → DB + TriageQueue、completeHandoff/cancelHandoff、rate limit、confirmHazard、getRecentEvents | 17 |

### `test/` — 原有測試（維持不動）

| 檔案 | 測試項目 |
|------|---------|
| [crypto_test.dart](../test/crypto_test.dart) | Ed25519 簽名驗證、篡改拒絕 |
| [crdt_test.dart](../test/crdt_test.dart) | HLC merge、conflict resolver |
| [widget_test.dart](../test/widget_test.dart) | Widget 渲染基本測試 |

---

## 分層說明

```
測試分層
├── 純 Dart（無 I/O）
│   ├── wire_codec_test         ← encodeWirePayload / decodeWirePayload
│   ├── bloom_filter_test       ← parseBloomFilter
│   ├── triage_queue_test       ← TriageQueue priority / overflow
│   ├── dedup_test              ← MeshEventHandler._seenEvents
│   ├── hlc_extended_test       ← HLC state machine
│   ├── medical_card_test       ← MedicalCard model
│   ├── medical_payload_test    ← buildMedicalPayload
│   └── routing_extended_test   ← MeshRouter exemption paths
│
├── sqflite_ffi（in-memory DB）
│   ├── up_pipeline_test        ← handleIncomingData → DB + stream
│   └── event_manager_test      ← publishEvent/Supply/Hazard → DB + queue
│
└── Integration（需 VillageGeofence geodata + 實機）[SKIP]
    ├── 行政區距離路由測試         ← routing_test.dart (skipped)
    └── BLE 連線行為              ← 實機測試，無對應 unit test
```

---

## 不在此測試的項目

| 項目 | 原因 |
|------|------|
| BLE GATT 連線 / MTU negotiation | 需要兩台實機 BLE 硬體 |
| NordicMeshManager.kt（Android） | 需要 Robolectric + Android instrumented test |
| VillageGeofence 行政區查詢 | 需要 village_boundary.db asset + path_provider |
| MethodChannel / EventChannel 整合 | 需要 Flutter integration_test + 平台 |
