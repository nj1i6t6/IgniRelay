# BLE Mesh 傳輸層替代方案分析

> 建立日期：2026-03-15
> 專案：烽傳 IgniRelay (ResQMesh)
> 背景：Bridgefy SDK maven repo 故障，需評估替代方案

---

## 1. Bridgefy SDK 現況

### 問題描述
Bridgefy 的 Maven 私有倉庫 (`http://34.82.5.94:8081/artifactory/libs-release-local`) 回傳 HTTP 500 錯誤。

### 錯誤訊息
```
Artifactory failed to initialize: check Artifactory logs for errors.
Spring Bean: IllegalArgumentException: ListableBeanFactory must not be null
```

### 影響範圍
- 所有替代端點均無法使用：
  - `maven.bridgefy.com` → DNS 解析失敗
  - `104.196.228.98` → 連線逾時
- GitHub Issue #28（2026-03-14 由其他開發者回報）— 同樣問題，Bridgefy 團隊尚未回應
- **結論**：100% 伺服器端問題，非應用程式端問題

### 已完成的準備工作
即使 Bridgefy 暫時不可用，MeshTransport 抽象層已完整實作：
- `MeshTransport` 抽象介面
- `BridgefyTransport` 完整實作（已通過 `flutter analyze` 零錯誤）
- `TransportFactory` 含自動 fallback 機制
- 待 maven repo 恢復後，只需取消 `pubspec.yaml` 和 `transport_factory.dart` 中的註解即可啟用

---

## 2. 替代方案排名

### 方案 1（推薦）：抽取 BitChat BLE Mesh 引擎核心邏輯
**可行性：★★★★☆ | 工作量：中 | 風險：低**

將 BitChat 的 BLE Mesh 核心邏輯（Kotlin/Android）移植到 Flutter 層，作為 `NativeBleTransport` 的升級版。

**優點：**
- Public Domain 授權，可自由使用
- 已驗證的跨廠牌相容性（使用 Nordic BLE Library）
- 完整的 GATT 雙角色架構（同時作為 Client + Peripheral）
- 成熟的封包分片、重組、中繼邏輯

**BitChat 核心技術特性：**
| 特性 | 數值 |
|------|------|
| 最大跳數 (TTL) | 7 |
| 加密協議 | Noise Protocol (XX handshake) |
| 二進位協議 | 自定義 binary protocol |
| 壓縮 | LZ4 |
| BLE Library | Nordic BLE Library (no.nordicsemi.android:ble) |
| GATT 模式 | 雙角色 (Client + Peripheral 同時運行) |
| MTU | 517 bytes |
| 連線管理 | 自動掃描、連線、斷線重連 |

**移植策略：**
1. 從 BitChat Android 原始碼抽取 BLE 通訊核心
2. 用 Flutter MethodChannel 橋接 Kotlin 層
3. 或者直接在 Dart 層用 `flutter_blue_plus` 重現其 GATT 配置
4. 實作為新的 `BitChatBleTransport implements MeshTransport`

---

### 方案 2：參考 BitChat/Zemzeme GATT 配置修復現有 NativeBLE
**可行性：★★★★★ | 工作量：小 | 風險：低**

不移植整個引擎，而是參考 BitChat/Zemzeme 的 GATT 設定修正現有 `flutter_blue_plus` 實作，解決跨廠牌問題。

**Zemzeme GATT 架構分析：**

```
BluetoothMeshService (協調層)
  ├── BluetoothConnectionManager (連線管理)
  │     ├── BluetoothGattServerManager (GATT Server)
  │     │     └── 廣告 Service UUID + 8-byte Peer ID
  │     └── BluetoothGattClientManager (GATT Client)
  │           └── MTU 517, 自動 Service Discovery
  ├── PacketRelayManager (中繼管理)
  │     └── TTL-based relay, 自適應機率轉發
  ├── FragmentManager (分片管理)
  └── PeerManager (節點管理)
```

**關鍵修正方向：**

1. **GATT Service 廣告方式**
   - 現有問題：小米等裝置掃描不到 Pixel 廣告的 Service
   - Zemzeme 做法：GATT Server 註冊標準 Service UUID，廣告封包包含 Service UUID + 8-byte Peer ID
   - 修正：確保 `ble_manager.dart` 的廣告封包格式與 Zemzeme 一致

2. **MTU 協商**
   - 現有問題：某些裝置 MTU 協商失敗導致 GATT 133
   - Zemzeme 做法：Client 連線後立即請求 MTU 517
   - 修正：在 `_connectToDevice()` 成功後立即呼叫 `requestMtu(517)`

3. **雙角色 GATT**
   - 現有問題：可能只有 Client 角色
   - Zemzeme 做法：同時運行 GATT Server（接收）+ GATT Client（發送）
   - 修正：確保 `flutter_blue_plus` 同時設置 Server 和 Client

4. **連線數量限制**
   - Zemzeme 的 `BluetoothConnectionManager` 有明確的最大連線數控制
   - 避免過多連線導致系統資源耗盡

**這是最快能落地的方案，建議優先執行。**

---

### 方案 3：等待 Bridgefy Maven Repo 恢復
**可行性：★★★☆☆ | 工作量：零 | 風險：高**

持續監控 Bridgefy GitHub Issue #28 和 maven repo 狀態。

**風險：**
- 不確定何時恢復（可能數天、數週甚至更久）
- Bridgefy 團隊回應速度未知
- 若公司倒閉或放棄維護，此方案將永久失效

**監控方式：**
```bash
# 定期檢查 maven repo 狀態
curl -s -o /dev/null -w "%{http_code}" http://34.82.5.94:8081/artifactory/libs-release-local

# 檢查 GitHub issue 更新
gh api repos/nicokimmel/bridgefy-flutter-plugin/issues/28
```

---

### 方案 4：Berty Wesh (libp2p)
**可行性：★★☆☆☆ | 工作量：大 | 風險：中**

使用 Berty 團隊開發的 Wesh 協議（基於 libp2p），提供 BLE + Wi-Fi Direct 的混合傳輸。

**優點：**
- 成熟的 P2P 協議棧
- 支援多種傳輸層（BLE、Wi-Fi Direct、TCP）
- 開源社群活躍

**缺點：**
- 學習曲線陡峭
- Go 語言實作，需 gomobile 橋接
- 二進位體積大（增加約 30-50MB）
- 與現有 Protobuf 協議整合複雜

---

## 3. Zemzeme 詳細架構參考

Zemzeme 是 BitChat v1.7.0 的 fork，新增了三層傳輸架構：

### 三層傳輸架構
```
Layer 1: BLE Mesh（近場通訊，0-100m）
  └── 原 BitChat BLE 引擎
Layer 2: P2P / libp2p（中距離，區域網路）
  └── 當裝置在同一 Wi-Fi 下時使用
Layer 3: Nostr（遠距離，需要網路）
  └── 透過 Nostr relay 進行跨區域通訊
```

### Mesh 目錄結構（17+ 原始檔案）
```
mesh/
├── BluetoothMeshService.kt      # 協調層：啟動/停止所有子管理器
├── BluetoothConnectionManager.kt # 連線管理：掃描、配對、連線池
├── BluetoothGattServerManager.kt  # GATT Server：廣告、接收資料
├── BluetoothGattClientManager.kt  # GATT Client：連線、發送資料
├── PacketRelayManager.kt          # 中繼管理：TTL、機率轉發
├── FragmentManager.kt             # 分片管理：大封包切割重組
├── PeerManager.kt                 # 節點管理：鄰居追蹤
├── models/
│   ├── MeshPacket.kt              # 封包資料結構
│   ├── MeshPeer.kt                # 節點資料結構
│   └── ...
└── utils/
    └── ...
```

### PacketRelayManager 關鍵邏輯
- **TTL (Time-To-Live)**：每轉發一次減 1，歸零即丟棄
- **自適應機率轉發**：根據網路密度動態調整轉發機率，避免廣播風暴
- **去重**：基於封包 ID 的已見集合，防止重複處理

### BluetoothGattServerManager 關鍵邏輯
- 註冊自定義 Service UUID
- 廣告封包包含 Service UUID + 8-byte Peer ID
- 收到 Client 寫入時觸發封包處理管線

### BluetoothGattClientManager 關鍵邏輯
- 連線後立即請求 MTU 517
- 自動 Service Discovery
- 寫入 Characteristic 發送資料

---

## 4. 建議執行順序

```
立即執行 ──► 方案 2：參考 Zemzeme GATT 配置修復 NativeBLE
                │
                ▼
短期目標 ──► 方案 1：抽取 BitChat 引擎核心（如需更完整的 Mesh）
                │
                ▼
持續監控 ──► 方案 3：Bridgefy 恢復後啟用（已有完整實作）
                │
                ▼
長期備案 ──► 方案 4：Berty Wesh（若需跨網路 P2P）
```

### 具體行動項目

#### 本週
1. [ ] 找到 BitChat/Zemzeme 的 `AppConstants.Mesh.Gatt` 中實際的 Service UUID 和 Characteristic UUID
2. [ ] 比對現有 `ble_manager.dart` 的 GATT 配置與 Zemzeme 的差異
3. [ ] 修正 MTU 協商（連線後請求 MTU 517）
4. [ ] 修正 GATT Server 廣告方式（加入 Service UUID）

#### 下週
5. [ ] 實作雙角色 GATT（Server + Client 同時運行）
6. [ ] 加入 TTL-based relay 邏輯（參考 PacketRelayManager）
7. [ ] 跨廠牌測試（Pixel ↔ 小米）

#### 持續
8. [ ] 監控 Bridgefy maven repo 狀態
9. [ ] 追蹤 GitHub Issue #28

---

## 5. 相關連結

| 資源 | URL |
|------|-----|
| BitChat Android | https://github.com/nicokimmel/bitchat-android |
| BitChat iOS | https://github.com/nicokimmel/bitchat-ios |
| Zemzeme | https://github.com/nicokimmel/zemzeme |
| Bridgefy Flutter Plugin | https://github.com/nicokimmel/bridgefy-flutter-plugin |
| Bridgefy Issue #28 | https://github.com/nicokimmel/bridgefy-flutter-plugin/issues/28 |
| Berty Wesh | https://github.com/berty/wesh |
