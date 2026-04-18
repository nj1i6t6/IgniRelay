# 烽傳 Ignirelay — Refactoring-0.2.0 作業計畫

本文件為 `Refactoring-0.2.0` 分支的作業契約。所有 commit 必須對應本計畫中的階段，不得擅自新增或縮減範圍。

分析範圍：`resqmesh_app/` 全專案（Flutter/Dart + Android + iOS）。不動 `edge-node/`、`ignirelay-lib/` 等其他子專案。

---

## 零、作業公約（不可違反）

| 項目 | 定義 |
|---|---|
| 分支 | `Refactoring-0.2.0`，從 `Damo` 切出 |
| commit 粒度 | 每階段 1 個，訊息格式 `refactor(stage-N): <中文主題>` |
| 測試 | 每階段結束跑 `flutter analyze` + `flutter test`，並在 Android 模擬器手動驗收 golden path |
| 決策模式 | 中途遇非結構性決策 → 用預設選擇推進，在該 commit 訊息列 `決策:...` 條目；遇結構性決策（影響邊界/協議/DB） → 停下問使用者 |
| 禁用 | emoji（含 UI/程式碼/commit 訊息/註解）、誇張修辭、AI 腔、無必要動效 |
| 文字語氣 | 繁中為主，技術資訊（座標/時間戳/版本/ID）才用 mono 英數 |
| 範圍限定 | 只動 `resqmesh_app/` |
| 不加新功能 | 除非重構自然帶入（marker clustering、急難模式、信任圖示化算既有需求重寫），否則不加 |
| 不改 | DB schema、mesh protocol、i18n 架構、後端/通訊協議、套件名 `network.ignirelay`、bundle id、applicationId |

## 一、產品與設計定案（鎖定）

| 項目 | 值 |
|---|---|
| 產品名 | 烽傳 / Ignirelay（維持現有套件名 `network.ignirelay`） |
| 分頁結構 | 地圖 / 聊天 / 媒合 / 我（4 分頁） |
| 生存模式 | 併入「我」→ 連線診斷子頁 |
| 次要畫面 | 自行設計對齊版（據點供給、醫療卡、導航、實體交接、分級通報、onboarding） |
| 語言 | 沿用既有 `l10n/` 架構，繁中為主 |
| emoji | 完全不用。信任等級改線條 SVG icon |
| iOS 進度 | 必須與 Android 同步推進（使用者之後自行在 macOS 打包與實測） |

## 二、設計系統（鎖定）

### 色票（5 組語意）

```
brand.primary     #E8803B           品牌、主要 CTA、tab active
state.selected    accent-border     外框 + accent-soft 淺底（非純色填充）
                  + accent-soft
semantic.sos      #E5484D           致命求救（紅，長按 1.5s 啟動）
semantic.warn     #F5A524           一般警告 / SOS_YELLOW
semantic.ok       #30A46C 降飽和    廣播中、成功
semantic.info     #5B8DEF           提示
trust.verified    #4FA882           社群背書 / 官方
hazard.*          類別固定不重疊     紅=危險、藍=醫療、綠=物資、橘=生活機能、紫=工具
```

**原則**：看到橘=品牌或可按，看到紅=危險，看到黃=警告。禁止語意共用色。

### 字體

- 內文：Noto Sans TC
- 等寬：JetBrains Mono（座標、時間戳、版本、ID）

### 質感

玻璃面板（blur + 半透明）、hairline border、有節制的 slideUp / fadeIn / pulse / ripple 動畫。

### 急難模式

- 預設關閉
- 手動：「我」→ 設定 → 急難模式切換
- 自動觸發（可關）：自發 SOS / 方圓 500m 內有 red event / 系統字級 >= L / 電量 <10%
- 效果：高對比主題 + 字級 +1 階 + 粗體

## 三、目標程式碼結構（Stage 1 完成後）

```
resqmesh_app/lib/
  platform/                只此層可 import flutter/services
    native_bridge.dart
    native_ble_transport.dart
    mesh_transport.dart
    transport_factory.dart
  app/                     跨 UI 共用邏輯，不依賴 UI
    mesh/                  event_manager / mesh_router / hazard_manager / ...
    services/              chat / match / negotiation / location / ...
    controllers/           給 UI 用的 facade（新增）
      handoff_controller.dart
      ble_scan_controller.dart
      device_info_controller.dart
      mesh_runtime_controller.dart
    models/  crypto/  crdt/  geo/  proto/  db/  config/
    data/                  純資料字典（例：supply_category_data）
  ui/                      純 UI
    theme/
      tokens.dart
      app_theme.dart       dark / light / emergency 三套
      accents.dart
    widgets/               共用：GlassIconBtn / GlassCard / StatusChip / MonoText / ...
    screens/
      map/  chat/  match/  me/   主分頁（拆成子元件檔）
    sheets/                SosSheet / LayersSheet / LegendSheet / ...
    secondary/             據點 / 醫療卡 / 導航 / 實體交接 / 分級通報 / onboarding
  l10n/                    不動
  main.dart
```

### 強制邊界

優先採用 `import_lint` 套件（專為路徑前綴規則設計、更輕）；若 Windows 相容性或規則表達力不足，fallback 至 `custom_lint` 或 `analysis_options.yaml` 自訂 preset。

規則：
- `lib/ui/**` 禁止 import `lib/platform/**`
- `lib/app/**` 禁止 import `lib/ui/**`
- `package:flutter/*` 等 pub 依賴不受影響（規則以 `lib/**` 路徑前綴匹配，不會誤擋 SDK）
- 違反 → build fail

## 四、階段執行表（11 commits）

每階段格式：**目標 → 交付 → 驗收 → commit 訊息**。

---

### Stage 0 — 分支與計畫鎖定（commit #1）

- **目標**：建立分支，落地本計畫檔，記錄 baseline
- **交付**：
  - 切 `Refactoring-0.2.0`（from `Damo`）
  - 建 `docs/Refactoring-0.2.0-plan.md`
- **Baseline（於 Damo tip 量測）**：
  - `flutter analyze`：**95 issues**（以 info / warning / lint 為主）
  - `flutter test`：**+284 ~3 -0**（全綠，原分析提到的 `writeDebugLog` 1 fail 已於 commit `2980268` 修掉）
  - 最大檔案：`map_screen.dart` 2331 行、`station_supply_screen.dart` 1343 行、`supply_category_data.dart` 1181 行（純資料字典，不算邏輯巨檔）
- **驗收**：`git branch --show-current` 為新分支；計畫檔可讀
- **commit**：`refactor(stage-0): 建立 Refactoring-0.2.0 分支與作業計畫`

### Stage 1 — 分層與 import lint（commit #2）

- **目標**：建立 platform / app / ui 三層邊界，行為零變化
- **交付**：
  - 建目標目錄結構，搬檔並修 import 路徑
  - `supply_category_data.dart` 從 `lib/ui/` 搬到 `lib/app/data/`（不拆內容）
  - 新增 4 個 controller facade（包裝現有原生呼叫；此階段只建殼，不強制 UI 改用）
  - 加 `import_lint` 規則阻擋跨層 import（fallback 至 `custom_lint`）
  - 舊測試全部通過，不新增失敗
- **驗收**：
  - `flutter analyze` issue 數不超過 baseline 95
  - `flutter test` 結果不差於 baseline `+284 ~3 -0`
  - 模擬器跑 App，4 個分頁、SOS、聊天、媒合、據點、導航 golden path 不 regression
- **commit**：`refactor(stage-1): 分 platform/app/ui 三層並加 import lint`

### Stage 2 — Design System（commit #3）

- **目標**：tokens + 主題 + 共用 widget + 急難模式骨架
- **交付**：
  - `ui/theme/tokens.dart` 完整色票、字級、間距、shadow
  - `AppTheme.dark()` / `.light()` / `.emergency()` 三套 ThemeData
  - Accent 可切（amber / teal / blue）
  - 共用 widget：`GlassIconBtn`、`GlassCard`、`StatusChip`、`MonoText`、`Hairline`、`SlideUpSheet`、`PulseEffect`、`RippleEffect`
  - Debug-only `/design-showcase` 路由
  - 急難模式 controller（手動開關 + 自動觸發條件判斷骨架）
  - **相容性驗證**：試裝 `flutter_map_marker_cluster`，確認與現行 `flutter_map ^7.0.2` 相容；若不相容，在本階段結束時決定 Stage 4d 走自寫 cluster 路線
- **驗收**：Android 模擬器跑 `/design-showcase`，三主題切換正常；尚未影響主畫面；clustering 相容性已確認
- **commit**：`refactor(stage-2): 建立 Design System 與急難模式架構`

### Stage 3 — App 殼與 4 分頁路由（commit #4）

- **目標**：新殼上線，舊畫面暫時嵌在新殼內可切換
- **交付**：
  - 新 `MainTabController`（4 分頁、玻璃 TabBar、badge、SOS 與 tab 留 16pt 間距）
  - 4 個 Screen 先為「過渡殼」：內容暫時直接嵌舊畫面
  - 「我」分頁加上主題 / accent / 急難模式設定入口
  - `Sheets` 共用底部抽屜框架
- **驗收**：模擬器 App 啟動後是新殼，底欄 4 分頁，「我」可切主題/急難模式並看到變化
- **commit**：`refactor(stage-3): 套用新 App 殼與 4 分頁底欄`

### Stage 4a — 「我」分頁（commit #5）

- **目標**：第一個完整新畫面
- **交付**：
  - 整合 profile + 醫療卡入口 + 主題 / accent / 密度 / 急難模式設定 + 生存模式子頁（連線狀態、Data Mule、BLE 診斷、Debug log 匯出）
  - 本分頁範圍內 UI 無 `NativeBridge` 直呼，全走 `mesh_runtime_controller` / `device_info_controller`（包含原 `survival_mode_screen`、`battery_optimization_guide`）
  - 信任等級改圖示優先，L0-L3 字樣藏進點擊展開
- **驗收**：模擬器可切 Data Mule / BLE、看狀態、匯出 log；`grep "NativeBridge\." lib/ui/screens/me lib/ui/secondary/medical_card*` 為 0
- **commit**：`refactor(stage-4a): 重構「我」分頁並吸收生存模式`

### Stage 4b — 「聊天」分頁（commit #6）

- **目標**：list / room / join 三畫面新 UI
- **交付**：
  - 對接既有 `ChatService`（不動邏輯）
  - 訊息氣泡：連續同發言者合併、只第一則顯示 avatar
  - 信任標籤改圖示優先
  - 「廣播中」標籤用 `semantic.ok` 降飽和版
- **驗收**：模擬器走完加入（GPS / 村里 / 邀請碼）→ 收發訊息 → 未讀/已讀 → 離開房間
- **commit**：`refactor(stage-4b): 重構「聊天」分頁`

### Stage 4c — 「媒合」分頁（commit #7）

- **目標**：四子分頁（requests / supplies / negotiations / community）新 UI
- **交付**：
  - 對接 `MatchRepository` / `NegotiationManager`（不動邏輯）
  - 選中態統一：accent 外框 + accent-soft 淺底
  - Sheet 多步時加 Step indicator（1/3 之類）
- **驗收**：模擬器跑發佈需求 → 發佈供給 → 接受協商 → 進入導航入口
- **commit**：`refactor(stage-4c): 重構「媒合」分頁`

### Stage 4d — 「地圖」分頁（commit #8）

- **目標**：拆 2331 行巨檔為 7-9 個 <400 行小檔
- **交付**：
  - 拆分：`MapView` / `MapMarkersLayer` / `HazardLayer` / `PoiLayer` / `SelfMarker` / `MapHeader` / `MapFabColumn` / `SosButton` / `HazardReportFlow`
  - Sheets：`SosSheet` / `LayersSheet` / `LegendSheet` / `DetailSheet` / `MeshSheet`
  - Marker clustering（`flutter_map_marker_cluster`），低 zoom 聚合，優先級 SOS > 避難 > 醫療 > 其他
  - Pin 色彩改大類一色：紅=危險、藍=醫療、綠=物資、橘=生活、紫=工具，icon 只做次分類
  - 左上改行政區+最近道路（離線反查；做不到 fallback 座標 mono 小字）
  - SOS 按鈕：長按 1.5 秒啟動，與 tab 留 16pt 間距
  - 本分頁範圍內 UI 無 `NativeBridge` 直呼，全走 `ble_scan_controller` / `handoff_controller`（含 `navigation_screen`、`physical_handoff`）
- **驗收**：模擬器跑地圖載入、POI 顯示、clustering 行為、標記災害、SOS 長按、圖層切換、導航入口；`grep "NativeBridge\." lib/ui/screens/map lib/ui/secondary/navigation* lib/ui/secondary/physical_handoff*` 為 0
- **commit**：`refactor(stage-4d): 重構「地圖」分頁並加入 clustering`

### Stage 5 — 次要畫面（commit #9）

- **目標**：據點供給、分級通報、onboarding 等剩餘次要畫面套新視覺；全域驗證 UI 零 `NativeBridge` 直呼
- **交付**：
  - 按「烽傳」視覺語言重繪剩餘次要畫面（醫療卡於 4a、導航/實體交接於 4d 已處理）
  - 清除任何殘餘 `NativeBridge` 直呼
  - 導航進交接時 role 不再硬編碼 provider，依上下文決定 requester / provider
- **驗收**：
  - `grep -r "NativeBridge\." lib/ui/` 結果為 0（全域驗證）
  - 模擬器跑：onboarding → 發需求 → 發供給 → 進導航 → 進實體交接（PIN / BLE / DROP_OFF 三種 UI 正常；實際 handoff 閉環在 Stage 6 修）
- **commit**：`refactor(stage-5): 重構剩餘次要畫面並驗證 UI 零 NativeBridge 直呼`

### Stage 6 — iOS Handoff P0 與通訊層補完（commit #10）

- **目標**：修掉分析文件的 P0，讓 handoff 跨平台閉環
- **交付**：
  - 統一 handoff 事件型別（`handshake_data` 或 `handoff_result` 擇一，在 `handoff_controller` 歸一化）
  - 完成 iOS `sendHandoffPin`（對齊 Android：PIN hash + resourceId 驗證；iOS BlePlugin.swift 的 duplicate case 清掉）
  - `publishHandshakeComplete` 帶入真實 providerPubKey / requesterPubKey / actualDeliveredQty
  - iOS 建置：補 `Podfile` 模板、`Podfile.lock` 策略說明、`Generated.xcconfig` git 忽略規則
- **驗收**：
  - Android ↔ Android 模擬器 handoff E2E 走通（我可測）
  - iOS 編譯與實機：使用者之後自行在 macOS 驗證；commit 訊息註明「iOS 實機測試待執行」
- **commit**：`refactor(stage-6): 修補 handoff 跨平台閉環與 iOS P0`

### Stage 7 — 收尾（commit #11）

- **目標**：品質清理、刪舊碼、文件同步
- **交付**：
  - 刪除所有過渡檔、`// TODO: removed in refactor` 殘留、無用 import
  - `flutter analyze` 清到 < 20 issues
  - `writeDebugLog` 改可 await + 測試通過（解掉原 1 fail）
  - 補 E2E 測試：match → navigation → handoff → complete
  - 版本號 bump 至 `0.2.0`
- **驗收**：`flutter test` 全綠、`flutter analyze` < 20、模擬器冷啟動到 SOS 完整路徑無 regression
- **commit**：`refactor(stage-7): 清理品質、刪舊碼、bump 0.2.0`

---

## 五、Mid-flight 決策規則

| 情境 | 處理 |
|---|---|
| 發現與重構直接相關的 bug | 順手修，commit 訊息註明 `附帶修正:...` |
| 發現無關的 bug | 不修，列進 Stage 7 清單給使用者決定 |
| 設計選項等價（色階微調、間距 4 或 8） | 選最簡，不問 |
| 結構性決策（新增層 / 改 controller 介面 / 改 DB） | 停下問使用者 |
| 行為會改變（原本錯但沒人發現） | 停下問使用者 |

## 六、明確不做的事

- 不寫任何 emoji（含 UI、程式碼、註解、commit 訊息）
- 不加新功能（clustering、急難模式、信任圖示化屬於既有需求重寫，不計新功能）
- 不改 mesh protocol、DB schema、i18n 架構
- 不改套件名、bundle id、applicationId
- 不做 CI/CD 配置
- 不動 `edge-node/`、`ignirelay-lib/` 等其他子專案
- 不做動效炫技
- 不自作主張砍測試換綠

## 七、風險與應對

| 風險 | 應對 |
|---|---|
| iOS 我無法實機測 | Stage 6 寫完後明確標「iOS 實機待你驗」；Android 我自測 |
| 地圖 2331 行拆分誤傷 | Stage 4d 前先做拆分對照（開發內部用，不進 repo） |
| `flutter_map_marker_cluster` 與現行 `flutter_map` 版本相容性 | Stage 4d 第一步確認；不相容則改自寫輕量 cluster，不升級 `flutter_map` |
| custom_lint 套件 Windows 相容性 | 若有問題 fallback 用 `analysis_options.yaml` 自訂 preset |
| 重構期間 `main` / `Damo` 有緊急合併 | 分支 rebase 而非 merge，推進前先 `git fetch` |
| 模擬器藍牙能力受限 | 藍牙相關流程用 mock controller 在模擬器走 UI；實際硬體測試由使用者實機做 |

## 八、驗收總表（每階段必須達標才推進）

Baseline：analyze **95 issues**、test **+284 ~3 -0**（全綠）。

| Stage | Analyze 上限 | Test 最低標準 | 模擬器驗收 |
|---|---|---|---|
| 0 | 不檢 | 不檢 | 分支存在、計畫檔可讀 |
| 1 | <= 95 | +284 ~3 -0 | Golden path 不 regression |
| 2 | <= 95 | 不退步 | /design-showcase 可跑、clustering 相容性已確認 |
| 3 | <= 95 | 不退步 | 新殼啟動、主題切換 |
| 4a | <= 90 | 不退步 | 我分頁完整功能；Me 範圍 NativeBridge 直呼清零 |
| 4b | <= 85 | 不退步 | 聊天完整流程 |
| 4c | <= 80 | 不退步 | 媒合完整流程 |
| 4d | <= 70 | 不退步 | 地圖完整流程 + clustering；Map/Navigation/Handoff 範圍 NativeBridge 直呼清零 |
| 5 | <= 50 | 不退步 | UI 全域零 NativeBridge 直呼 |
| 6 | <= 40 | 不退步 | Android handoff 閉環 |
| 7 | < 20 | 全綠 | 冷啟動 → SOS 全路徑 |
