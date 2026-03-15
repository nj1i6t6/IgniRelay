# BitChat BLE Mesh 引擎技術規格

> 來源：https://github.com/nicokimmel/bitchat-android
> 授權：Public Domain
> 平台：Android (Kotlin), iOS (Swift)

---

## 核心技術參數

| 參數 | 數值 |
|------|------|
| 最大跳數 (TTL) | 7 |
| 加密協議 | Noise Protocol Framework (XX handshake pattern) |
| 壓縮 | LZ4 |
| BLE Library | Nordic BLE Library (`no.nordicsemi.android:ble`) |
| MTU | 517 bytes |
| 二進位協議 | 自定義 binary protocol |
| GATT 模式 | 雙角色 (Client + Peripheral 同時運行) |
| 節點發現 | BLE Scan + GATT Service UUID 廣告 |

---

## BLE 通訊架構

### 雙角色 GATT
```
┌─────────────────────────────┐
│        BitChat Node         │
│                             │
│  ┌──────────┐ ┌──────────┐  │
│  │  GATT    │ │  GATT    │  │
│  │  Server  │ │  Client  │  │
│  │(接收資料)│ │(發送資料)│  │
│  └──────────┘ └──────────┘  │
│                             │
│  ┌──────────────────────┐   │
│  │   PacketRelayManager │   │
│  │  (TTL-based 中繼)    │   │
│  └──────────────────────┘   │
│                             │
│  ┌──────────────────────┐   │
│  │   FragmentManager    │   │
│  │  (封包分片/重組)     │   │
│  └──────────────────────┘   │
└─────────────────────────────┘
```

### Nordic BLE Library 優勢
- 由 Nordic Semiconductor 維護的官方 Android BLE Library
- 解決大量 Android 廠牌 BLE 相容性問題
- 自動處理 GATT 連線佇列（避免並發操作導致 133 錯誤）
- 內建重試機制和連線參數優化
- Package: `no.nordicsemi.android:ble`

### Noise Protocol 加密
```
handshake pattern: XX
- 雙方互換公鑰
- 建立共享密鑰
- 後續通訊使用對稱加密

適用場景:
- 點對點安全通訊
- 無需 CA/PKI 基礎設施
- 適合離線環境
```

---

## 封包格式（Binary Protocol）

BitChat 使用自定義二進位協議而非 Protobuf：
- 更小的封包開銷
- 更快的序列化/反序列化
- LZ4 壓縮進一步減小體積

### 封包結構（推測）
```
┌─────────┬─────────┬─────────┬─────────┬──────────┐
│ Header  │ TTL     │ Packet  │ Payload │ Checksum │
│ (magic) │ (1byte) │ ID      │ Length  │          │
│         │         │ (UUID)  │ + Data  │          │
└─────────┴─────────┴─────────┴─────────┴──────────┘
```

---

## iOS 版本差異

BitChat iOS 使用 CoreBluetooth：
- `CBCentralManager` (Client 角色)
- `CBPeripheralManager` (Server/Peripheral 角色)
- 同樣實作雙角色 GATT
- Service UUID 和 Characteristic UUID 與 Android 版本共用

---

## 對 ResQMesh 的啟示

### 可直接借鏡的部分
1. **Nordic BLE Library** — 但 Flutter 層用的是 flutter_blue_plus，需確認是否底層已包含類似優化
2. **雙角色 GATT** — flutter_blue_plus 支援 Peripheral 模式需額外 plugin（如 `flutter_ble_peripheral`）
3. **MTU 517** — flutter_blue_plus 支援 `requestMtu(517)`
4. **TTL-based relay** — 可在 Dart 層實作，與 MeshEnvelope 結合

### 需注意的部分
1. Nordic BLE Library 是 Android 原生，Flutter 層需通過 MethodChannel 橋接
2. Noise Protocol 與現有 ECDSA 簽章機制不同，不需要完全採用
3. LZ4 壓縮需額外 Dart package
4. 二進位協議與現有 Protobuf 不相容，不建議替換
