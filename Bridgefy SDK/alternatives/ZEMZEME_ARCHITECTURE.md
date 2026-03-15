# Zemzeme BLE Mesh 架構詳解

> 來源：https://github.com/nicokimmel/zemzeme
> 版本：基於 BitChat v1.7.0 fork
> 授權：Public Domain

---

## 核心架構

### BluetoothMeshService（協調層）
頂層 Android Service，負責啟動/停止所有子管理器：
- `BluetoothConnectionManager` — 掃描、連線
- `PacketRelayManager` — 封包中繼
- `FragmentManager` — 大封包分片重組
- `PeerManager` — 鄰居節點管理

### BluetoothConnectionManager（連線管理）
管理 BLE 連線生命週期：
- 最大連線數限制（防止資源耗盡）
- 自動掃描附近裝置
- 連線失敗自動重試
- 內含兩個子管理器：

#### BluetoothGattServerManager（GATT Server）
```
功能：被動接收資料
- 註冊自定義 Service UUID
- 廣告封包 = Service UUID + 8-byte Peer ID
- 收到 Client Write → 觸發封包處理管線
- 支援 Notification 回傳
```

#### BluetoothGattClientManager（GATT Client）
```
功能：主動連線並發送資料
- 連線後立即請求 MTU 517
- 自動 Service Discovery
- 透過 Write Characteristic 發送資料
- 支援 Read Characteristic 接收回應
```

### PacketRelayManager（中繼管理）
```
TTL-based relay:
- 每個封包帶有 TTL 值（BitChat 預設 7）
- 轉發時 TTL -= 1
- TTL == 0 時丟棄

自適應機率轉發:
- 根據鄰居數量動態調整轉發機率
- 鄰居多 → 降低轉發機率（避免廣播風暴）
- 鄰居少 → 提高轉發機率（確保傳遞）

去重:
- 維護已見封包 ID 集合
- 重複封包直接丟棄
```

### FragmentManager（分片管理）
```
大封包處理:
- 根據 MTU 大小切割封包
- 每個分片帶有序號和總數
- 接收端重組完整封包
- 逾時未收齊則丟棄
```

---

## 與 ResQMesh 現有實作對比

| 特性 | Zemzeme | ResQMesh (NativeBLE) | 差異 |
|------|---------|---------------------|------|
| GATT 模式 | 雙角色 (Server+Client) | 主要 Client | 需加 Server |
| MTU | 517 (主動請求) | 預設值 | 需請求 517 |
| 中繼 | TTL-based + 機率 | Bloom Filter 驅動 | 互補 |
| 去重 | 封包 ID 集合 | event_id 集合 | 類似 |
| 分片 | FragmentManager | Protobuf 序列化 | 可能需要 |
| 加密 | Noise Protocol | ECDSA 簽章 | 不同層級 |
| 節點發現 | GATT Server 廣告 | BLE Scan | 需改進 |
| 跨廠牌 | Nordic BLE Library | flutter_blue_plus | 需驗證 |

---

## 可移植到 ResQMesh 的核心概念

### 1. GATT Server 廣告（最重要）
現有 NativeBLE 可能缺少 GATT Server 角色，導致部分廠牌裝置無法被發現。
加入 GATT Server 並廣告 Service UUID 是解決跨廠牌問題的關鍵。

### 2. MTU 517 請求
連線建立後立即請求 MTU 517 可以：
- 減少 GATT 133 錯誤
- 提高單次傳輸資料量
- 減少分片需求

### 3. TTL-based Relay
可與現有 Bloom Filter 策略互補：
- Bloom Filter：週期性同步所有事件
- TTL Relay：即時轉發新事件（特別是 SOS）

### 4. 連線數量限制
避免同時維護過多 BLE 連線，減少 GATT 133 錯誤發生。
