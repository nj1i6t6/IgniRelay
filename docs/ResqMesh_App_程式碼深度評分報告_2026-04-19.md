# ResqMesh App 程式碼深度評分報告

更新日期：2026-04-19
評估範圍：resqmesh_app 程式碼與可執行品質訊號（不以專案文件為評分依據）
評估方式：實際執行 flutter analyze、flutter test、dart analyze、分層檢查腳本，加上核心程式碼走讀

---

## 1. 執行摘要

整體評分：72 / 100（約 7.2 / 10）

一句話結論：
這個 app 在 Mesh 核心、資料層、協商狀態機與測試面已達中高成熟度，但跨平台交接路徑（尤其 iOS handoff）與分層收斂尚未完成，離「可長期穩定運營的跨平台版本」仍有明顯缺口。

目前最關鍵的阻礙不是功能數量，而是跨平台一致性與交接流程閉環。

---

## 2. 量化結果（直接執行）

- flutter test：+284，~3 skipped，0 failed
- flutter analyze：90 issues
- dart analyze（machine 解析）：INFO 66、WARNING 24
- 測試規模：25 個測試檔，約 286 個 test case
- 分層檢查：
  - dart run tool/check_layers.dart：無新增違規（4 筆既有 baseline）
  - dart run tool/check_layers.dart --strict：失敗（4 筆跨層違規）
- 代碼體量（非生成）：90 個 Dart 檔，約 27,213 行
- l10n 生成檔：3 個檔案，約 10,087 行（不納入可維護性評分）

---

## 3. 各面向評分

| 面向 | 權重 | 分數(10) | 加權分 | 評語 |
|---|---:|---:|---:|---|
| 功能完成度 | 20% | 8.4 | 16.8 | 核心功能完整，流程覆蓋面廣 |
| Mesh 核心與資料一致性 | 15% | 8.2 | 12.3 | 簽章驗證、去重、協商狀態機有實作深度 |
| 架構分層與可維護性 | 15% | 6.9 | 10.4 | 分層方向正確，但仍存在已知跨層依賴 |
| 程式碼品質（靜態分析） | 15% | 6.8 | 10.2 | 無編譯錯誤，但 warning/info 仍偏多 |
| 測試完整性與可靠性 | 15% | 8.0 | 12.0 | 測試數量夠、核心邏輯有覆蓋，但平台層不足 |
| 安全與隱私 | 10% | 7.1 | 7.1 | 簽章與金鑰管理不錯，但醫療資料落地保護不足 |
| 跨平台一致性（Android/iOS） | 10% | 4.8 | 4.8 | handoff 關鍵路徑 iOS 未閉環 |
| 發佈就緒度 | 5% | 6.0 | 3.0 | 可 demo/內測，離穩定商用還差收斂 |

總分：72 / 100

---

## 4. 強項（以程式碼證據）

### 4.1 啟動流程分階段，容錯設計比一般 prototype 完整

- 啟動階段含 DB、Identity、Geofence、權限、BLE 啟動順序與錯誤隔離
  - [resqmesh_app/lib/main.dart](../resqmesh_app/lib/main.dart#L247)
  - [resqmesh_app/lib/main.dart](../resqmesh_app/lib/main.dart#L248)
  - [resqmesh_app/lib/main.dart](../resqmesh_app/lib/main.dart#L262)

### 4.2 Mesh 接收端安全性有真正落地（不是只定義）

- 記憶體去重 + DB 去重（重啟後仍防重播）
  - [resqmesh_app/lib/app/mesh/mesh_event_handler.dart](../resqmesh_app/lib/app/mesh/mesh_event_handler.dart#L128)
  - [resqmesh_app/lib/app/mesh/mesh_event_handler.dart](../resqmesh_app/lib/app/mesh/mesh_event_handler.dart#L134)
- 缺簽章拒收、簽章驗證失敗拒收
  - [resqmesh_app/lib/app/mesh/mesh_event_handler.dart](../resqmesh_app/lib/app/mesh/mesh_event_handler.dart#L149)
  - [resqmesh_app/lib/app/mesh/mesh_event_handler.dart](../resqmesh_app/lib/app/mesh/mesh_event_handler.dart#L152)
- canonical signing（eventId/type/ttl/payload 納入簽章）
  - [resqmesh_app/lib/app/crypto/signer.dart](../resqmesh_app/lib/app/crypto/signer.dart#L11)
  - [resqmesh_app/lib/app/crypto/signer.dart](../resqmesh_app/lib/app/crypto/signer.dart#L45)

### 4.3 協商狀態機設計成熟

- NegotiationManager 處理 CAS、角色授權、孤兒事件重試、過期清理
  - [resqmesh_app/lib/app/services/negotiation_manager.dart](../resqmesh_app/lib/app/services/negotiation_manager.dart#L31)
- 測試覆蓋重點集中在 negotiation 與 event manager
  - [resqmesh_app/test/services/negotiation_manager_test.dart](../resqmesh_app/test/services/negotiation_manager_test.dart#L1)
  - [resqmesh_app/test/event/event_manager_test.dart](../resqmesh_app/test/event/event_manager_test.dart#L252)

### 4.4 身分金鑰管理方向正確

- Ed25519 金鑰放在 secure storage
  - [resqmesh_app/lib/app/crypto/identity_manager.dart](../resqmesh_app/lib/app/crypto/identity_manager.dart#L3)
  - [resqmesh_app/lib/app/crypto/identity_manager.dart](../resqmesh_app/lib/app/crypto/identity_manager.dart#L17)

---

## 5. 主要風險（依嚴重度）

### P0-1 跨平台 handoff 事件不一致，Provider 流程存在卡死風險

- NativeBridge 只接 type == handoff_result
  - [resqmesh_app/lib/platform/native_bridge.dart](../resqmesh_app/lib/platform/native_bridge.dart#L389)
- iOS 實際送的是 handshake_data
  - [resqmesh_app/ios/Runner/BlePlugin.swift](../resqmesh_app/ios/Runner/BlePlugin.swift#L585)
- HandoffController 註解明確寫「Stage 6 才會歸一化」，代表目前尚未完成
  - [resqmesh_app/lib/app/controllers/handoff_controller.dart](../resqmesh_app/lib/app/controllers/handoff_controller.dart#L6)
  - [resqmesh_app/lib/app/controllers/handoff_controller.dart](../resqmesh_app/lib/app/controllers/handoff_controller.dart#L37)

影響：交接成功事件回拋不一致，流程完成訊號可能丟失。

### P0-2 iOS sendHandoffPin 未實作

- iOS sendHandoffPin 明確 TODO
  - [resqmesh_app/ios/Runner/BlePlugin.swift](../resqmesh_app/ios/Runner/BlePlugin.swift#L231)
  - [resqmesh_app/ios/Runner/BlePlugin.swift](../resqmesh_app/ios/Runner/BlePlugin.swift#L232)
- Android 已有 verifyHandoffPin
  - [resqmesh_app/android/app/src/main/kotlin/network/ignirelay/ignirelay_app/MainActivity.kt](../resqmesh_app/android/app/src/main/kotlin/network/ignirelay/ignirelay_app/MainActivity.kt#L323)

影響：Android/iOS handoff 能力不對等。

### P1-1 導航進交接角色目前固定 provider，Requester 路徑實際未接通

- 進入交接頁固定 role: provider
  - [resqmesh_app/lib/ui/secondary/navigation_screen.dart](../resqmesh_app/lib/ui/secondary/navigation_screen.dart#L290)
- 全專案僅此處建立 PhysicalHandoffScreen
  - [resqmesh_app/lib/ui/secondary/navigation_screen.dart](../resqmesh_app/lib/ui/secondary/navigation_screen.dart#L289)

影響：Requester 交接邏輯雖有 UI 分支，但缺少完整進入路徑。

### P1-2 交接完成事件仍帶 placeholder 關鍵欄位

- providerPubKey/requesterPubKey/actualDeliveredQty 多處固定空值或 0
  - [resqmesh_app/lib/ui/secondary/physical_handoff.dart](../resqmesh_app/lib/ui/secondary/physical_handoff.dart#L113)
  - [resqmesh_app/lib/ui/secondary/physical_handoff.dart](../resqmesh_app/lib/ui/secondary/physical_handoff.dart#L114)
  - [resqmesh_app/lib/ui/secondary/physical_handoff.dart](../resqmesh_app/lib/ui/secondary/physical_handoff.dart#L115)

影響：交接完成事件的可稽核性與後續統計可信度不足。

### P1-3 iOS 原生檔案有高風險編譯訊號

- switch case 重複 requestBluetoothEnable
  - [resqmesh_app/ios/Runner/BlePlugin.swift](../resqmesh_app/ios/Runner/BlePlugin.swift#L83)
  - [resqmesh_app/ios/Runner/BlePlugin.swift](../resqmesh_app/ios/Runner/BlePlugin.swift#L220)
- private 欄位由另一個 class 存取（PeripheralDelegate）
  - [resqmesh_app/ios/Runner/BlePlugin.swift](../resqmesh_app/ios/Runner/BlePlugin.swift#L37)
  - [resqmesh_app/ios/Runner/BlePlugin.swift](../resqmesh_app/ios/Runner/BlePlugin.swift#L632)

影響：iOS build 穩定性與維護風險高。

### P2-1 分層雖有工具，但 strict 仍失敗

- baseline 仍保留 4 筆 UI 直連 platform
  - [resqmesh_app/tool/layer_violations_baseline.txt](../resqmesh_app/tool/layer_violations_baseline.txt#L6)
  - [resqmesh_app/tool/layer_violations_baseline.txt](../resqmesh_app/tool/layer_violations_baseline.txt#L9)
- --strict 目前會直接失敗（本次實測）
- UI 仍直接 import NativeBridge
  - [resqmesh_app/lib/ui/secondary/navigation_screen.dart](../resqmesh_app/lib/ui/secondary/navigation_screen.dart#L5)
  - [resqmesh_app/lib/ui/secondary/physical_handoff.dart](../resqmesh_app/lib/ui/secondary/physical_handoff.dart#L8)

影響：邊界規範存在，但尚未真正「收斂完成」。

### P2-2 安全與隱私：醫療卡為明文 JSON 存放在 SQLite

- medical_card 直接存文字欄位
  - [resqmesh_app/lib/app/db/database_helper.dart](../resqmesh_app/lib/app/db/database_helper.dart#L239)
- repo 直接 insert/update medicalCardJson
  - [resqmesh_app/lib/app/db/medical_card_repo.dart](../resqmesh_app/lib/app/db/medical_card_repo.dart#L22)
  - [resqmesh_app/lib/app/db/medical_card_repo.dart](../resqmesh_app/lib/app/db/medical_card_repo.dart#L29)

影響：若裝置遭取證或資料庫外洩，敏感個資暴露風險高。

### P2-3 錯誤可觀測性仍偏弱

- writeDebugLog 為 fire-and-forget，錯誤被吞
  - [resqmesh_app/lib/app/db/database_helper.dart](../resqmesh_app/lib/app/db/database_helper.dart#L513)
  - [resqmesh_app/lib/app/db/database_helper.dart](../resqmesh_app/lib/app/db/database_helper.dart#L520)
- 程式內 catch 區塊數量高（約 148），其中 catch(_) 約 52

影響：故障可診斷性下降，真實錯誤易被靜默掩蓋。

### P3-1 生命週期實作有可維護風險

- controller dispose 放在 deactivate
  - [resqmesh_app/lib/ui/secondary/station_supply_screen.dart](../resqmesh_app/lib/ui/secondary/station_supply_screen.dart#L826)

影響：在 widget 反覆 attach/detach 情境下，狀態管理可能出現非預期行為。

---

## 6. 測試評價

優點：
- 核心 domain（negotiation、event、mesh、routing、medical）有系統化測試
- 上行管道測試已覆蓋簽章驗證、重播去重、hazard 寫入等關鍵路徑
  - [resqmesh_app/test/pipeline/up_pipeline_test.dart](../resqmesh_app/test/pipeline/up_pipeline_test.dart#L1)

缺口：
- UI 只有 smoke test，深度不足
  - [resqmesh_app/test/widget_test.dart](../resqmesh_app/test/widget_test.dart#L1)
- 原生橋接（MethodChannel/EventChannel）幾乎無測試
- iOS RunnerTests 是空殼
  - [resqmesh_app/ios/RunnerTests/RunnerTests.swift](../resqmesh_app/ios/RunnerTests/RunnerTests.swift#L1)
- 3 個 integration 情境被 skip（geofence 資料依賴）
  - [resqmesh_app/test/routing_test.dart](../resqmesh_app/test/routing_test.dart#L108)
  - [resqmesh_app/test/routing/routing_extended_test.dart](../resqmesh_app/test/routing/routing_extended_test.dart#L121)

測試面總評：8.0/10

---

## 7. 上線成熟度判斷

目前定位較適合：
- 受控場域試運行
- Android 為主的內測或 demo

尚不建議：
- 宣稱 Android/iOS 完整等效上線
- 在未補齊 handoff 跨平台閉環前做高信任交接流程承諾

---

## 8. 優先改善清單（只列最關鍵）

1. 統一 handoff 事件語義與路徑
- 讓 NativeBridge 與 iOS/Android 事件型別一致
- 在 HandoffController 做事件歸一化（既有註解已指向此方向）

2. 補齊 iOS handoff 實作
- 完成 sendHandoffPin
- 修正 BlePlugin 內重複 case 與權限存取問題

3. 打通 requester 交接入口
- 移除 navigation 固定 provider 的硬編碼
- 讓 requester/provider 皆可實際走完流程

4. 補齊交接完成事件真實欄位
- providerPubKey/requesterPubKey/actualDeliveredQty 應寫入真值

5. 分層收斂到 strict 可通過
- 清掉 baseline 4 筆跨層依賴
- 把 check_layers 檢查掛進固定 CI 或 pre-merge 流程

6. 敏感資料保護
- 醫療卡欄位加密或拆到更安全儲存策略
- 至少建立資料分類與風險級別規範

---

## 9. 最終評價

如果以「研究型 prototype」評分，這個專案是高分段。
如果以「跨平台可穩定營運產品」評分，當前瓶頸明確集中在 handoff 跨平台閉環與分層收斂。

所以我給的整體分數是 72/100：
- 不是低分，代表已有相當實作深度
- 也不是可直接封版的高分，因為關鍵交接閉環與 iOS一致性尚未完成

就工程投資回報來看，這個專案非常值得繼續推進，且只要把前述 P0/P1 風險收斂，分數有機會快速提升到 80+。
