# BitChat BLE Mesh 引擎技術規格

> 來源：https://github.com/permissionlesstech/bitchat-android
> 授權：Public Domain
> 平台：Android (Kotlin), iOS (Swift)

---

## 核心技術參數

| 參數 | 數值 |
|------|------|
| 最大跳數 (TTL) | 7 (`MESSAGE_TTL_HOPS = 7u`) |
| 同步 TTL | 0 (`SYNC_TTL_HOPS = 0u`, 僅鄰居) |
| 加密協議 | Noise Protocol Framework (XX handshake) |
| 壓縮 | LZ4 |
| BLE Library | Nordic BLE Library (`no.nordicsemi.android:ble`) |
| MTU | 517 bytes（Client 連線後 200ms 延遲請求） |
| 二進位協議 | 自定義 binary protocol (`BitchatPacket`) |
| GATT 模式 | 雙角色 (Client + Peripheral 同時運行) |
| 節點發現 | BLE Scan + GATT Service UUID 廣告 + PeerID |
| 最大 Payload | 256 bytes (Noise Protocol 限制) |

---

## GATT UUID 配置（關鍵！）

```kotlin
// AppConstants.Mesh.Gatt
SERVICE_UUID       = F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C
CHARACTERISTIC_UUID = A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D
DESCRIPTOR_UUID    = 00002902-0000-1000-8000-00805f9b34fb  // 標準 CCCD
```

> **注意**：`DESCRIPTOR_UUID` 是標準 BLE Client Characteristic Configuration Descriptor (CCCD)，
> 用於啟用/停用 Notification。

---

## 完整常數表

### Mesh 網路
| 常數 | 數值 | 說明 |
|------|------|------|
| `MESSAGE_TTL_HOPS` | 7 | 訊息最大跳數 |
| `SYNC_TTL_HOPS` | 0 | 同步封包僅鄰居 |
| `PEER_TIMEOUT_MS` | 180,000 (3min) | 節點超時 |
| `PEER_CLEANUP_INTERVAL_MS` | 60,000 (1min) | 清理間隔 |
| `BLE_RETRY_DELAY_MS` | 5,000 | 重試延遲 |
| `MAX_RETRY_ATTEMPTS` | 3 | 最大重試次數 |
| `RSSI_UPDATE_INTERVAL_MS` | 5,000 | RSSI 更新間隔 |

### 分片 (Fragmentation)
| 常數 | 數值 | 說明 |
|------|------|------|
| `FRAGMENT_SIZE_THRESHOLD` | 512 bytes | 超過此值才分片 |
| `MAX_FRAGMENT_SIZE` | 469 bytes | 單片最大大小 |
| `FRAGMENT_TIMEOUT_MS` | 30,000 (30s) | 分片重組超時 |

### 安全 & Noise Protocol
| 常數 | 數值 | 說明 |
|------|------|------|
| `MESSAGE_TIMEOUT_MS` | 300,000 (5min) | 訊息超時 |
| `MAX_PROCESSED_MESSAGES` | 10,000 | 已處理訊息上限 |
| `MAX_KEY_EXCHANGES` | 1,000 | 金鑰交換上限 |
| `REKEY_TIME_MS` | 3,600,000 (1hr) | 重新生成金鑰時間 |
| `REKEY_MESSAGE_LIMIT` | 1,000 | 重新生成金鑰訊息數 |
| `SESSION_LIMIT` | 10,000 | Session 上限 |
| `MAX_PAYLOAD` | 256 bytes | Noise 最大 payload |
| `NONCE_WARNING_THRESHOLD` | 1,000,000,000 | Nonce 警告閾值 |

### Store-and-Forward
| 常數 | 數值 | 說明 |
|------|------|------|
| `CACHE_TIMEOUT_MS` | 43,200,000 (12hr) | 快取超時 |
| `MAX_CACHED_MESSAGES` | 100 | 快取訊息上限 |
| `MAX_FAVORITES` | 1,000 | 收藏上限 |

### 電源管理
| 常數 | 數值 | 說明 |
|------|------|------|
| `CRITICAL_BATTERY` | 10% | 極低電量閾值 |
| `LOW_BATTERY` | 20% | 低電量閾值 |
| `MEDIUM_BATTERY` | 50% | 中電量閾值 |
| `CONN_LIMIT_NORMAL` | 8 | 正常模式最大連線 |
| `CONN_LIMIT_POWER_SAVE` | 8 | 省電模式最大連線 |
| `CONN_LIMIT_ULTRA_LOW` | 4 | 超低功耗最大連線 |

### 其他
| 常數 | 數值 | 說明 |
|------|------|------|
| `QR_MAX_AGE_SEC` | 300 (5min) | QR 驗證有效期 |
| `NICKNAME_MAX_LENGTH` | 15 | 暱稱最大長度 |
| `MAX_FILE_SIZE` | 50 MB | 檔案上限 |
| `TOR_SOCKS_PORT` | 9060 | Tor SOCKS 埠 |

---

## GATT Server 實作細節

### Characteristic 配置
```kotlin
characteristic = BluetoothGattCharacteristic(
    AppConstants.Mesh.Gatt.CHARACTERISTIC_UUID,
    PROPERTY_READ or PROPERTY_WRITE or PROPERTY_WRITE_NO_RESPONSE or PROPERTY_NOTIFY,
    PERMISSION_READ or PERMISSION_WRITE
)
```
支援四種操作：Read、Write、Write No Response、Notify。

### 廣告方式
```kotlin
// 主廣告：包含 Service UUID（讓掃描器過濾）
val data = AdvertiseData.Builder()
    .addServiceUuid(ParcelUuid(SERVICE_UUID))
    .build()

// 掃描回應：包含 PeerID（讓掃描器識別節點身份）
val scanResponse = AdvertiseData.Builder()
    .addServiceData(ParcelUuid(SERVICE_UUID), peerIDBytes)  // 8-byte PeerID
    .build()

bleAdvertiser.startAdvertising(settings, data, scanResponse, advertiseCallback)
```
**關鍵設計**：PeerID 放在 Scan Response 的 Service Data 中，即使 MAC 地址輪換也能識別同一節點。

### 資料接收
```kotlin
override fun onCharacteristicWriteRequest(device, requestId, characteristic,
    preparedWrite, responseNeeded, offset, value) {
    val packet = BitchatPacket.fromBinaryData(value)
    if (packet != null) {
        delegate?.onPacketReceived(packet, peerID, device)
    }
    if (responseNeeded) {
        gattServer?.sendResponse(device, requestId, GATT_SUCCESS, 0, null)
    }
}
```

---

## GATT Client 實作細節

### 連線流程
```
connectGatt(context, autoConnect=false, callback, TRANSPORT_LE)
    ↓
onConnectionStateChange (STATE_CONNECTED)
    ↓ delay(200ms)
requestMtu(517)
    ↓
onMtuChanged (GATT_SUCCESS)
    ↓ 註冊到 ConnectionTracker
discoverServices()
    ↓
onServicesDiscovered
    ↓ 啟用 Notification
開始收發資料
```

### 掃描過濾
```kotlin
private fun handleScanResult(result: ScanResult) {
    // 1. 檢查是否有目標 Service UUID
    val hasOurService = scanRecord?.serviceUuids?.any {
        it.uuid == AppConstants.Mesh.Gatt.SERVICE_UUID
    } == true
    if (!hasOurService) return

    // 2. RSSI 過濾（根據電源模式動態調整閾值）
    if (rssi < powerManager.getRSSIThreshold()) return

    // 3. 去重：已連線的不再連
    if (connectionTracker.isDeviceConnected(deviceAddress)) return

    // 4. 防止重複連線嘗試
    if (connectionTracker.addPendingConnection(deviceAddress)) {
        connectToDevice(device, rssi, peerID)
    }
}
```

---

## BLE 通訊架構

### 雙角色 GATT
```
┌───────────────────────────────────────┐
│           BitChat Node                │
│                                       │
│  ┌──────────────┐ ┌──────────────┐    │
│  │  GATT Server │ │  GATT Client │    │
│  │  (被動接收)  │ │  (主動連線)  │    │
│  │              │ │              │    │
│  │ • 廣告 UUID  │ │ • 掃描 UUID  │    │
│  │ • 接收 Write │ │ • MTU 517    │    │
│  │ • 發送 Notify│ │ • Write 發送 │    │
│  └──────────────┘ └──────────────┘    │
│           │               │           │
│  ┌────────┴───────────────┴────────┐  │
│  │      PacketRelayManager         │  │
│  │  TTL-based + 自適應機率轉發     │  │
│  └─────────────────────────────────┘  │
│  ┌─────────────────────────────────┐  │
│  │        FragmentManager          │  │
│  │  512B 閾值 / 469B 分片 / 30s 逾時│  │
│  └─────────────────────────────────┘  │
│  ┌─────────────────────────────────┐  │
│  │    StoreForwardManager          │  │
│  │  離線快取 12hr / 最多 100 筆    │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

---

## 對 ResQMesh 的啟示

### 可直接借鏡的部分
1. **GATT UUID** — 使用相同的 Service/Characteristic UUID 可以與 BitChat 網路互通
2. **雙角色 GATT** — flutter_blue_plus 支援 Peripheral 模式需額外 plugin（如 `flutter_ble_peripheral`）
3. **MTU 517 + 200ms 延遲** — 連線後等 200ms 再請求 MTU，提高成功率
4. **PeerID in Scan Response** — 解決 MAC 輪換問題的關鍵
5. **RSSI 動態閾值** — 根據電源模式調整，省電時只連近距離節點
6. **連線數限制 (8/4)** — 避免過多連線導致 GATT 133

### 需注意的部分
1. Nordic BLE Library 是 Android 原生，Flutter 層需通過 MethodChannel 橋接
2. Noise Protocol 與現有 ECDSA 簽章機制不同，不需要完全採用
3. 256 bytes 的 Noise payload 上限比 ResQMesh 的 Protobuf 封包小，需評估
4. 二進位協議 `BitchatPacket` 與現有 Protobuf 不相容，不建議替換
