# 烽傳 (IgniRelay) — Bridgefy SDK 整合技術參考文件

## 一、為什麼選擇 Bridgefy SDK

### 核心問題
烽傳的自研 BLE 層（基於 flutter_blue_plus）在同廠牌設備間運作正常（OPPO×4 + 小米×1，Bloom Filter 同步、事件交換、去重均正確），但跨廠牌時（小米 + Pixel）出現嚴重相容性問題：
- 兩台設備互相無法發現（peer 列表完全無交集）
- Pixel 連線後讀取 characteristic 失敗（`PlatformException(readCharacteristic)`）
- GATT Server peripheral 端疑似未正確廣播（兩端均顯示 `0 events`）
- 多次出現 Android GATT Error 133（`ANDROID_SPECIFIC_ERROR`）

### 根本原因
Android BLE 碎片化：不同廠牌的 BLE stack 行為不一致（GATT server advertising 方式、scan response 格式、service UUID 廣播位置、MAC 地址隨機化策略均不同）。這是業界公認最困難的 mobile 開發領域之一。

### 為什麼是 Bridgefy
- 1200 萬+ 下載，在真實災難場景（墨西哥地震、烏克蘭戰爭、緬甸政變）驗證
- 已處理數百種 Android 設備的 BLE 差異
- iOS/Android 跨平台互通已解決
- BLE + Wi-Fi Direct 雙傳輸層自動切換
- Signal Protocol 端對端加密
- 有 Flutter plugin，可直接整合

### 限制與風險
- **首次啟動需要網路**：license 驗證需要一次聯網，災難時全新安裝無法直接使用 mesh 功能
- **License 有到期日**：SDK 提供 `licenseExpirationDate()` API，到期後可能需要再次聯網更新
- **閉源專有授權**：不可 reverse engineer、不可轉賣 SDK
- **長期成本**：超過 sandbox 100 人後，每人啟動 $0.02 + 每次互動 $0.02
- **策略**：Bridgefy 作為 MVP/demo 階段方案，同時持續打磨自研 BLE 層，待穩定後替換

---

## 二、Bridgefy SDK 功能範圍

### SDK 負責（你不用管）
| 功能 | 說明 |
|------|------|
| BLE 設備發現 | scan + advertise，跨廠牌相容性已處理 |
| 連線管理 | GATT 133 retry、MTU 協商、斷線重連 |
| Mesh Routing | 訊息多跳轉發，路徑選擇 |
| 傳輸層切換 | BLE ↔ Wi-Fi Direct 自動判斷（Android 對 Android） |
| iOS 背景通訊 | CoreBluetooth 背景模式限制的處理 |
| 加密 | Signal Protocol 端對端加密（需主動呼叫 `establishSecureConnection`） |
| 跨平台互通 | iOS ↔ Android BLE 互通 |

### SDK 不負責（你完全自己決定）
| 功能 | 說明 |
|------|------|
| 資料格式 | 送什麼、怎麼編碼，全部由你決定 |
| Business Logic | SOS、物資媒合、信任系統等上層功能 |
| 資料同步策略 | CRDT、Bloom Filter、HLC 時鐘 |
| 序列化 | Protobuf、JSON 或任何格式 |
| 離線地圖 | MBTiles 向量地圖渲染 |
| 身分與信任 | Ed25519 金鑰對、信任分級 |

---

## 三、傳輸模式

SDK 提供三種傳輸模式，對應你的不同使用場景：

### P2P（點對點直連）
```dart
await bridgefy.send(data, TransmissionMode.p2p(userId: recipientUUID));
```
- 接收者必須在 BLE 直接範圍內
- 如果不在範圍內會回報錯誤
- **適用場景**：物資交換的 PIN 碼握手、Bloom Filter 一對一交換

### Mesh（多跳轉發）
```dart
await bridgefy.send(data, TransmissionMode.mesh(userId: recipientUUID));
```
- 指定接收者 UUID，訊息透過中間節點 hop 到目標
- 不保證送達（DTN 特性），`onSendMessage` 只代表成功進入 mesh，不代表送達
- **適用場景**：定向物資需求回覆、Data Mule 資料傳遞

### Broadcast（廣播）
```dart
await bridgefy.send(data, TransmissionMode.broadcast(senderId: myUUID));
```
- 所有附近的節點都會收到
- 透過 mesh 向外擴散
- **適用場景**：SOS 緊急廣播、Bloom Filter 定期廣播、危險區域標記

---

## 四、資料格式

### 關鍵發現：原生層接收 ByteArray/Data，非 String
從 Kotlin plugin 原始碼（第 205 行）確認：
```kotlin
val data = args["data"] as ByteArray
```
從 Swift plugin 原始碼（第 177 行）確認：
```swift
let data = args["data"] as! FlutterStandardTypedData
```

**結論：你的 Protobuf 序列化後的 raw bytes 可以直接傳送，不需要 base64 encode/decode。**

### 傳送流程
```
你的事件資料 → Protobuf 序列化 → bytes → bridgefy.send(bytes, mode)
```

### 接收流程
```
bridgefy.onReceiveData(bytes) → Protobuf 反序列化 → 你的事件資料
```

### 封包大小限制
- BLE 環境下建議單次封包控制在合理範圍內
- SDK 提供 `onSendDataProgress` 回調追蹤大封包傳送進度
- 超過大小限制會拋出 `SizeLimitExceededException`（Android）/ `dataLengthExceeded`（iOS）

---

## 五、架構整合方案

### 替換前（現有架構）
```
上層功能（SOS、物資媒合、地圖標記）
        ↓
CRDT 事件同步 / Bloom Filter 比對
        ↓
事件序列化（Protobuf）
        ↓
自研 BLE 層（flutter_blue_plus）  ← 只換這裡
  - startScan / stopScan
  - connectToDevice
  - discoverServices
  - writeCharacteristic / readCharacteristic
  - setNotification
```

### 替換後（Bridgefy 整合）
```
上層功能（SOS、物資媒合、地圖標記）
        ↓
CRDT 事件同步 / Bloom Filter 比對
        ↓
事件序列化（Protobuf）
        ↓
Transport Interface（抽象層）  ← 新增這層
        ↓                ↓
Bridgefy Transport     自研 BLE Transport
   （現在用）              （持續開發，未來替換）
```

### Transport Interface 設計
```dart
abstract class MeshTransport {
  Future<void> initialize();
  Future<void> start();
  Future<void> stop();
  Future<String> broadcast(Uint8List data);
  Future<String> sendToNode(String nodeId, Uint8List data);
  Stream<MeshDataReceived> get onDataReceived;
  Stream<String> get onPeerConnected;
  Stream<String> get onPeerDisconnected;
}
```

這層抽象確保未來替換 Bridgefy 時，上層程式碼零修改。

### Bloom Filter 交換策略調整
| | 自研 BLE 層（現有） | Bridgefy SDK |
|---|---|---|
| 觸發方式 | 連線驅動（GATT 連線成功 → 交換） | 廣播驅動（定期 broadcast） |
| 流程 | 連線 → 交換 Bloom → 比對 → 傳增量 | broadcast Bloom → 收到後比對 → sendMesh 回傳缺少的事件 |
| 控制粒度 | 完全控制連線時機 | SDK 抽象化連線，無法直接控制 |

---

## 六、SDK 生命週期與事件

### 初始化與啟動
```dart
// 1. 初始化（需要 API Key，首次需要網路）
await Bridgefy.initialize(
  apiKey: 'YOUR_SANDBOX_API_KEY',
  delegate: this,
  verboseLogging: true,  // debug 階段開啟
);

// 2. 啟動 mesh（選擇適合的 propagation profile）
await Bridgefy.start(
  userId: customUUID,  // 可選，不傳則自動生成
  propagationProfile: PropagationProfile.LongReach,  // 災難場景建議
);
```

### Propagation Profiles
| Profile | 適用場景 | 備註 |
|---------|---------|------|
| Standard | 一般情境 | 預設值 |
| HighDensityNetwork | 避難所、集結點 | 人群密集處 |
| SparseNetwork | 郊區、山區 | 節點稀疏 |
| LongReach | 災難通訊 | 最大傳輸距離，**推薦用這個** |
| ShortReach | 近距離交換 | 物資交換 PIN 握手 |
| Realtime | 即時通知 | SOS_RED 搶佔場景 |

### Operation Modes（背景執行）
| Mode | 行為 | 電量影響 | 適用 |
|------|------|---------|------|
| FOREGROUND | 只在前台運作 | 最低 | 測試/開發 |
| BACKGROUND | 持續前台服務 | 最高 | 24/7 mesh |
| **HYBRID** | 前台時正常，背景時自動切換服務 | 中等 | **生產環境推薦** |

### 核心事件回調
```dart
// 生命週期
Bridgefy.onStart((userId) => print('Started: $userId'));
Bridgefy.onFailToStart((error) => handleError(error));

// 連線
Bridgefy.onConnect((userId) => addPeer(userId));
Bridgefy.onDisconnect((userId) => removePeer(userId));
Bridgefy.onConnectedPeers((peers) => updatePeerList(peers));

// 訊息
Bridgefy.onReceiveData((data, messageId, mode) => processEvent(data));
Bridgefy.onSendMessage((messageId) => confirmSent(messageId));
Bridgefy.onFailSendingMessage((messageId, error) => handleFail(messageId));
Bridgefy.onSendDataProgress((messageId, position, of) => updateProgress(position/of));

// 加密連線
Bridgefy.onEstablishSecureConnection((userId) => markSecure(userId));
Bridgefy.onFailToEstablishSecureConnection((userId, error) => fallback(userId));
```

---

## 七、Android 設定

### AndroidManifest.xml
```xml
<!-- 權限 -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<!-- HYBRID/BACKGROUND 模式需要 -->
<service
    android:name="me.bridgefy.plugin.flutter.service.BridgefyService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="dataSync" />
```

### build.gradle
```groovy
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 23
        targetSdkVersion 34
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
        coreLibraryDesugaringEnabled true
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'
}
```

---

## 八、錯誤處理

### Android 端錯誤類型（從 Kotlin plugin 原始碼）
| Error Code | 說明 | 處理建議 |
|------------|------|---------|
| `invalidAPIKey` | API Key 格式錯誤 | 檢查 key |
| `internetConnectionRequiredException` | 首次需要網路驗證 | 提示使用者聯網 |
| `expiredLicense` | License 過期 | 提示聯網更新 |
| `permissionException` | BLE/位置權限未授予 | 引導使用者開啟權限 |
| `alreadyStarted` | SDK 已在運作 | 忽略 |
| `sizeLimitExceeded` | 封包超過大小限制 | 分割資料 |
| `sessionError` | 會話錯誤 | 重新初始化 |
| `deviceCapabilities` | 設備不支援 BLE | 顯示提示 |
| `inconsistentDeviceTimeException` | 設備時間異常 | 對應你的 HLC 設計 |

### iOS 端額外錯誤（從 Swift plugin 原始碼）
| Error Code | 說明 |
|------------|------|
| `BLEUsageNotGranted` | 藍牙使用權限未授予 |
| `BLEUsageRestricted` | 藍牙被系統限制 |
| `BLEPoweredOff` | 藍牙已關閉 |
| `BLEUnsupported` | 設備不支援 BLE |
| `simulatorIsNotSupported` | 模擬器不支援 |
| `dataLengthExceeded` | 資料長度超限 |
| `peerIsNotConnected` | 目標 peer 不在線 |

---

## 九、License 與計費

### Sandbox（現在用）
- 免費
- 最多 100 個活躍用戶
- 不含 analytics
- 適合 MVP、demo、比賽展示

### Starter（未來擴展時）
- 每人啟動：$0.02 USD
- 每次互動：$0.02 USD
- 按用量計費，無預付

### License 管理
```dart
// 檢查 license 到期時間
final expirationTimestamp = await bridgefy.licenseExpirationDate();
final expirationDate = DateTime.fromMillisecondsSinceEpoch(expirationTimestamp);

// 如果即將到期且有網路，可以更新
// 注意：新版 SDK 中 updateLicense() 已自動處理，保留僅為向後相容
```

### 法律約束（SDK License Agreement 重點）
- ✅ 可以用 SDK 建構並發布 app
- ✅ 可以免費發布 app
- ❌ 不可 reverse engineer SDK
- ❌ 不可轉賣或重新分發 SDK
- ❌ 不可將 SDK 用於「建構和測試 app」以外的用途

---

## 十、整合步驟 Checklist

### Phase 1：準備
- [x] 註冊 Bridgefy 開發者帳號
- [x] 取得 Sandbox API Key
- [ ] 在 pubspec.yaml 加入 `bridgefy: ^1.1.8`（確認 pub.dev 最新版本）
- [ ] 設定 Android 權限與 build.gradle
- [ ] 設定 iOS 權限（Info.plist）

### Phase 2：實作 Transport Interface
- [ ] 建立 `MeshTransport` 抽象類別
- [ ] 實作 `BridgefyTransport`（包裝 Bridgefy API）
- [ ] 實作 `NativeBleTransport`（包裝現有 flutter_blue_plus 邏輯）
- [ ] 在 app 設定中支援切換 transport

### Phase 3：整合上層邏輯
- [ ] 修改 mesh_router.dart，改為呼叫 Transport Interface
- [ ] 調整 Bloom Filter 交換策略（連線驅動 → 廣播驅動）
- [ ] 測試 SOS broadcast
- [ ] 測試物資媒合的 mesh 傳輸
- [ ] 測試 Protobuf bytes 的 send/receive

### Phase 4：測試驗證
- [ ] 同廠牌 Android 設備互通
- [ ] 跨廠牌 Android 設備互通（小米 + Pixel）
- [ ] iOS 設備測試（需取得測試機）
- [ ] iOS ↔ Android 跨平台互通
- [ ] 背景模式（HYBRID）測試
- [ ] 斷網後 mesh 功能測試（確認首次驗證後可離線）

---

## 十一、未來替換路線

```
短期（現在 → demo）
  └─ 用 Bridgefy SDK 跑 demo，100 人 sandbox 免費
  └─ 同時持續修自研 BLE 層的跨廠牌相容性

中期（demo → 推廣）
  └─ 自研 BLE 層穩定跑在 3+ 廠牌 Android 設備
  └─ 透過 Transport Interface 切換回自研層
  └─ 完全移除 Bridgefy 依賴

長期（有團隊後）
  └─ 找 iOS 開發者處理 CoreBluetooth
  └─ 封裝 IgniMesh SDK 供外部整合
  └─ Wi-Fi Aware 支援（Android only）
```
