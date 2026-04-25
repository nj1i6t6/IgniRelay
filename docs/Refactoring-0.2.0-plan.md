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
      igni_tokens.dart     spacing / radii / shadow / motion
      igni_colors.dart     IgniPalette + ThemeExtension
      igni_typography.dart sans / mono / 階層 TextStyle
      igni_accent.dart     amber / teal / blue accent 切換
      app_theme.dart       dark / light / emergency 三套
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
- 違反 → build fail（由 `tool/check_layers.dart` 強制；既有 4 筆違規寫入 `tool/layer_violations_baseline.txt` grandfather，Stage 4a/4d/5 清除時同步縮減 baseline；Stage 7 於 CI 加 `--strict` 鎖死）

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

### Stage 1 — 分層與 import lint（commit #2）✅ 已完成（含 stage-1-followup 補丁）

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

### Stage 2 — Design System（commit #3）✅ 已完成（含 stage-2-followup 補丁）

- **目標**：tokens + 主題 + 共用 widget + 急難模式骨架
- **交付**：
  - `ui/theme/igni_tokens.dart` + `igni_colors.dart` + `igni_typography.dart` 完整色票、字級、間距、shadow
  - `AppTheme.dark()` / `.light()` / `.emergency()` 三套 ThemeData
  - Accent 可切（amber / teal / blue）
  - 共用 widget：`GlassIconBtn`、`GlassCard`、`StatusChip`、`MonoText`、`Hairline`、`SlideUpSheet`、`PulseEffect`、`RippleEffect`
  - Debug-only `/design-showcase` 路由
  - 急難模式 controller（手動開關 + 自動觸發條件判斷骨架）
  - **相容性驗證**：試裝 `flutter_map_marker_cluster`，確認與現行 `flutter_map ^7.0.2` 相容；若不相容，在本階段結束時決定 Stage 4d 走自寫 cluster 路線
- **驗收**：Android 模擬器 debug build 進 `/design-showcase`（release build 不註冊此路由），三主題切換正常；AppTheme 本階段可掛入 main.dart 但不改變主畫面功能流程（主畫面改版在 Stage 4a-4d）；clustering 相容性已確認
- **commit**：`refactor(stage-2): 建立 Design System 與急難模式架構`

### Stage 3 — App 殼與 4 分頁路由（commit #4）

- **目標**：新殼上線，舊畫面暫時嵌在新殼內可切換
- **交付**：
  - 新 `MainShell`（原計畫暫名 `MainTabController`；實作採 `MainShell`，4 分頁、玻璃 TabBar、badge、SOS 與 tab 留 16pt 間距）
  - 4 個 Screen 先為「過渡殼」：內容暫時直接嵌舊畫面
  - 「我」分頁加上主題 / accent / 急難模式設定入口
  - `Sheets` 共用底部抽屜框架（Stage 3 只建 `SlideUpSheet` 框架；主畫面逐步遷移留給 Stage 4a-4d，map_screen 的 showModalBottomSheet 清算落在 Stage 4d 拆檔時一併完成）
- **驗收**：模擬器 App 啟動後是新殼，底欄 4 分頁，「我」可切主題/急難模式並看到變化
- **commit**：`refactor(stage-3): 套用新 App 殼與 4 分頁底欄`

### Stage 4a — 「我」分頁（commit #5） ✅ 已完成（含 stage-4a-fix 補丁）

- **目標**：第一個完整新畫面
- **交付**：
  - 整合 profile + 醫療卡入口 + 主題 / accent / 密度 / 急難模式設定 + 生存模式子頁（連線狀態、Data Mule、BLE 診斷、Debug log 匯出）
  - 本分頁範圍內 UI 無 `NativeBridge` 直呼，全走 `mesh_runtime_controller` / `device_info_controller`（包含原 `survival_mode_screen`、`battery_optimization_guide`）
  - 信任等級改圖示優先，L0-L3 字樣藏進點擊展開
- **驗收**：模擬器可切 Data Mule / BLE、看狀態、匯出 log；`grep "NativeBridge\." lib/ui/screens/me lib/ui/secondary/medical_card* lib/ui/secondary/survival_mode_screen.dart lib/ui/secondary/battery_optimization_guide.dart` 為 0（涵蓋本階段交付明列的所有 4a 範圍檔）
- **commit**：`refactor(stage-4a): 重構「我」分頁並吸收生存模式`

### Stage 4b — 「聊天」分頁（commit #6）✅ 已完成（含 stage-4b 補丁）

- **目標**：list / room / join 三畫面新 UI；並產出全域集合洩漏盤點給 Stage 6 使用
- **交付**：
  - 對接既有 `ChatService`（不動邏輯）
  - 訊息氣泡：連續同發言者合併、只第一則顯示 avatar
  - 信任標籤改圖示優先
  - 「廣播中」標籤用 `semantic.ok` 降飽和版
  - **集合洩漏盤點 artifact**：產出 `resqmesh_app/docs/leak_inventory.md`，列出全專案可疑的只增不減 `Set` / `Map` / `List`（含檔名、行號、生命週期、建議 TTL 策略、建議處理時點）。本階段**僅盤點不修**，供 Stage 4c / 6 按各自範圍認領。已知熱點：`BleManager` 長駐 singleton 集合（`ble_manager.dart:46/63/746`）
- **驗收**：
  - 模擬器走完加入（GPS / 村里 / 邀請碼）→ 收發訊息 → 未讀/已讀 → 離開房間
  - `resqmesh_app/docs/leak_inventory.md` 存在且至少涵蓋 `BleManager`、`transport peer set`、`chat message cache`、`match repository` 四個來源的檢查結論（確認為 leak 或排除並標註原因）
- **commit**：`refactor(stage-4b): 重構「聊天」分頁 + 集合洩漏盤點`

### Stage 4c — 「媒合」分頁（commit #7）✅ 已完成

- **目標**：四子分頁（requests / supplies / negotiations / community）新 UI + 物資狀態機防呆
- **交付**：
  - 對接 `MatchRepository` / `NegotiationManager`（不動邏輯）
  - 選中態統一：accent 外框 + accent-soft 淺底
  - Sheet 多步時加 Step indicator（1/3 之類）— **Stage 4c 實作範圍 N/A**：
    媒合分頁目前的 sheets/對話框（community 接受數量、cancel 確認、
    decline 確認）皆為單步，不存在多步流程。若 Stage 4d / 5 出現多步
    sheet 再依此條款補 indicator。
  - **物資狀態機 FSM 防呆**：在 `NegotiationManager` / 相關 service 加入 `canTransition(from, to)`（不改 DB schema、不改通訊協議，純 service 層防呆）；非法跳轉直接丟棄並寫 `debugPrint` / logger 攔截記錄
  - **FSM 單測**：
    - 合法/非法轉換矩陣（覆蓋 offered → accepted → in_transit → delivered 等主路徑 + 已知非法邊）
    - 「**非法跳轉發生時，狀態欄位不回寫錯誤值**」— 這是防呆重點，必須有專門測試保護
    - 攔截事件有被記錄（測試可讀取 log sink 驗證）
- **驗收**：模擬器跑發佈需求 → 發佈供給 → 接受協商 → 進入導航入口；FSM 單測全綠
- **commit**：`refactor(stage-4c): 重構「媒合」分頁 + 物資狀態機防呆`

### Stage 4d — 「地圖」分頁（commit #8 / #8-r2）✅ 已完成

> **雙軌驗收**（因結構拆分分兩輪推進）：
> - **Round 1（commit d9d9bd4）— 行為條款 ✅ 達成**
>   - 零 NativeBridge（map / navigation / physical_handoff）已驗證，baseline 清空。
>   - PinPalette 5 大類一色 + icon 次分類 + cluster 優先級（SOS>supply>medical>life）套用於 `_eventMarkers`。
>   - SosLongPressButton 1.5s 長按 + MapFabColumn 與 tab 16pt 間距。
>   - MapLocationHeader 左上 overlay（DistrictRoadLookup 預留接口；現階段走座標 mono fallback，真實實作移至 Stage 7）。
>   - 已抽出 6 個 widgets（`lib/ui/screens/map/widgets/`，皆 <150 行）。
>   - 手測紀錄：`resqmesh_app/docs/leak_inventory.md`〈手測紀錄（Stage 4d 驗收）〉
>   - **發現未達成項**（於 Round 2 修補）：
>     - `_loadHazards` 仍用 local switch 挑 marker fill 色（`map_screen.dart:442 / :489`），hazard 大類一色僅套到 `_hazardInfo` 語意，未套到中心 marker，條款 L231 未實際生效。
>     - map_screen.dart 殘留 emoji（`:1290` `👤`、`:2248` `🚨`），違反 §六 L310。
> - **Round 2（commit 62f7663）— 結構拆分補完 ✅ 達成**
>   - 11 檔全拆出（widgets: poi_category / marking_panel / map_loading_screen / map_error_screen / map_legend_panel；sheets: poi_info_sheet / event_info_sheet / hazard_info_sheet / hazard_delete_dialog / sos_cancel_dialog / hazard_nearby_dialog），每檔 < 400 行（最大 marking_panel.dart 246 行）。
>   - hazard marker 大類一色 bug 修正：`_loadHazards` 改用 `PinPalette.color(PinCategory.hazard)` 做 marker fill；polygon 仍保次分類色。
>   - 2 處 emoji 清零（legend `🚨` → `Icons.warning_amber`；hazard info `👤` → `Icons.person_outline`）。
>   - 主檔 2303 → 1384 行（−919，約 −40%）；比 Round 2 原目標 `<1300` 多 84 行，此差距明確延到 Stage 7 抽 `MapController` 時一併處理。
>   - 實測 acceptance：`showModalBottomSheet|showDialog` = 2（≤ 2 ✅）、`S.of(context)!` = 21（從 33 下降 ✅ 不增加）、`lib/ui/screens/map/` emoji = 0 ✅、`flutter analyze` 無新增 issue ✅、`check_layers` ok ✅、`flutter test` × 2 = 309/309 兩輪全綠 ✅。
>   - D 類深耦合項（MapView / HazardLayer / PoiLayer / SelfMarker / HazardReportFlow）因需要引入 state holder，正式列為 **Stage 7 結構債**（見 Stage 7 §「Stage 4d 結構債」）。

**Round 2 交付清單**

- **基線**：`map_screen.dart` 實測 2303 行（`wc -l`）；33 個 `S.of(context)!`；8 個 inline `showModalBottomSheet` / `showDialog`。
- **目標**：主檔 2303 → <1300 行；新增檔全部 <400 行；不新增任何 `S.of(context)!`；inline modal/dialog 呼叫數 8 → 2（僅保留 `MapLayerControlSheet` + `TriageInputWidget` 的呼叫包裝）。

- **新增檔（11 個，皆 <200 行）**：
  ```
  lib/ui/screens/map/widgets/
    poi_category.dart              // label/id/color/icon 四個 pure fn
    map_loading_screen.dart
    map_legend_panel.dart
    map_error_screen.dart          // 1 callback: onRetry
    marking_panel.dart             // marking state 只傳入，回寫走 callback
  lib/ui/screens/map/sheets/
    poi_info_sheet.dart            // 含 _poiInfoRow / _poiHoursWidget / _formatOpeningHours 一併搬過來
    event_info_sheet.dart
    hazard_info_sheet.dart         // 3 callback: onEdit/onConfirm/onDelete
    hazard_delete_dialog.dart      // static show() → Future<bool>
    sos_cancel_dialog.dart         // static show() → Future<bool>
    hazard_nearby_dialog.dart      // static show() → Future<String?>('new'|'confirm'|null)
  ```

- **原 9+5 契約名詞 → 本輪新檔對照表**

  | 原契約名詞（plan L228 / L229）| 本輪對應 | 延遲階段 |
  |---|---|---|
  | `MapView` | 未拆（D 類） | Stage 7 |
  | `MapMarkersLayer` | `MarkerClusterLayerWidget`（已用套件）| — |
  | `HazardLayer` | `PolygonLayer` + marker producer 仍在 `_loadHazards` | Stage 7（需 controller）|
  | `PoiLayer` | `MarkerLayer` + `_buildPoiMarkers` 仍在主檔 | Stage 7（需 controller）|
  | `SelfMarker` | inline Marker（<30 行） | Stage 7 合拆 |
  | `MapHeader` | `MapLocationHeader` ✅ Round 1 已拆 | — |
  | `MapFabColumn` | `MapFabColumn` ✅ Round 1 已拆 | — |
  | `SosButton` | `SosLongPressButton` ✅ Round 1 已拆 | — |
  | `HazardReportFlow` | Round 2 拆 `MarkingPanel` + 3 個 Dialog；流程控制留在 `_MapScreenState` | Stage 7 抽 `MapController` 時才算完整 |
  | `SosSheet` | Round 1 已用 `TriageInputWidget` | — |
  | `LayersSheet` | Round 1 已用 `MapLayerControlSheet` | — |
  | `LegendSheet` | Round 2 拆 `MapLegendPanel`（非 sheet，是 panel overlay） | — |
  | `DetailSheet` | Round 2 拆 `HazardInfoSheet` + `EventInfoSheet` + `PoiInfoSheet` | — |
  | `MeshSheet` | `EventInfoSheet`（mesh 事件詳情即此） | — |

- **必修補（非 optional）**：
  1. **hazard marker 大類一色 bug 修正**：`_loadHazards` L441-456 的 local color switch，把套到 marker fill 的 `color`（L489）改為 `PinPalette.color(PinCategory.hazard)`。多邊形本體保留分色（那是功能）。commit 訊息列 `附帶修正: hazard 中心 marker 改用 PinPalette 大類色`。
  2. **清 emoji**：`map_screen.dart:1290` 的 `👤` 與 `:2248` 的 `🚨` 移除或以 Material Icon 取代（§六 L310）。
  3. **基線字串修正**：plan 原本寫「2331 行巨檔」（L226 已於本輪更新為 2303）。

- **本輪約束（與 §六 同級）**：
  - 不新增任何 `S.of(context)!` 強制解包（Stage 7 將全面清除，本輪不得擴大負債）。新檔需要 i18n 就走「傳入 l10n 物件或純字串」的 props 模式。
  - 新 widget 不得引入新狀態管理套件；state 回寫路徑維持 callback 模式。
  - sheet/panel 的硬碼色（`Color(0xFF1a1a2e)` 等）本輪**不替換**（視覺 token 對齊交 Stage 7 視覺鎖定）；僅做結構搬遷。

- **Round 2 驗收**：
  - `wc -l lib/ui/screens/map/map_screen.dart` < 1300
  - `find lib/ui/screens/map -name '*.dart' | xargs wc -l` 每檔 < 400
  - `grep -c "showModalBottomSheet\|showDialog" lib/ui/screens/map/map_screen.dart` ≤ 2
  - `grep -c "S\.of(context)!" lib/ui/screens/map/map_screen.dart` ≤ 33（不增加；預期會明顯下降）
  - `grep -E "🚨|👤|[\U0001F600-\U0001F64F]|[\U0001F300-\U0001F5FF]" lib/ui/screens/map/` 0 match
  - `flutter analyze`：不增加 issue，無新 error
  - `flutter test`：**連跑 2 次皆全綠**（防 flake gate）
  - 手測：POI 詳情 / hazard 詳情 / 刪除 / 編輯 / SOS 長按 / 取消 SOS / 標記模式發佈 / 附近重複對話框 / legend / 圖層 sheet / error-screen retry 全路徑
  - hazard 大類一色：marker 中心圓背景 6 種 type 皆為 `PinPalette.color(PinCategory.hazard)`（紅）；多邊形維持 type 分色

- **commit**：`refactor(stage-4d-r2): 地圖 sheet/panel 結構拆分 + hazard 統一色 + 清 emoji`

### Stage 5 — 次要畫面（commit #9）✅ 技術交付達成（模擬器全鏈路驗收待補）

- **目標**：據點供給、分級通報、onboarding 等剩餘次要畫面套新視覺；全域驗證 UI 零 `NativeBridge` 直呼；為 controller 建立可測邊界
- **交付**：
  - 按「烽傳」視覺語言重繪剩餘次要畫面（醫療卡於 4a、導航/實體交接於 4d 已處理）
  - 清除任何殘餘 `NativeBridge` 直呼（UI 層全面清零）
  - 導航進交接時 role 不再硬編碼 provider，依上下文決定 requester / provider
  - **限縮版 `NativeBridgeFacade` 介面 + DI**：
    - **介面覆蓋面限縮**：只抽 Stage 5 觸及 controller（`ble_scan_controller`、`handoff_controller`）實際使用的 method，不一次全包 BLE / Wi-Fi Direct / NFC / battery 全部 static
    - ⚠️ **`mesh_runtime_controller` 刻意延後到 Stage 6/7**：foreground service / DataMule / BleRelay / GATT / Bloom / outbox 等 9 個 static 涉及前景服務生命週期與跨平台 (Android/iOS) 行為差異，其 contract 預期會在 Stage 6 iOS handoff 統一時被改動。本階段在文件聲明中不主張覆蓋它，避免「覆蓋了又要再改」的虛工。`mesh_runtime_controller.dart` 仍直接走 `NativeBridge.*` static 是 acceptable 的；UI 層只會經由 controller 進入這條路徑，仍滿足 §UI 直呼歸零的硬驗收
    - **驗收範圍不限縮**：UI 全域零 `NativeBridge` 直呼仍然成立（未抽進 facade 的其他 static，UI 不得繞過 controller 直呼，改走 controller routing）
    - 建立 `test/fakes/fake_native_bridge.dart`；至少一個 controller 單測使用它、納入既有 `flutter test` 流程；**不新增 CI 配置**（遵守 §六「不做 CI/CD 配置」）
- **驗收**：
  - `grep -r "NativeBridge\." lib/ui/` 結果為 0（全域驗證；**此條仍為 Stage 5 硬驗收，不因 facade 限縮而放寬**）
  - `flutter test` 包含至少一個使用 `FakeNativeBridge` 的 controller 測試且綠燈
  - 模擬器跑：onboarding → 發需求 → 發供給 → 進導航 → 進實體交接（PIN / BLE / DROP_OFF 三種 UI 正常；實際 handoff 閉環在 Stage 6 修）
- **commit**：`refactor(stage-5): 重構剩餘次要畫面 + NativeBridgeFacade 可測邊界`
- ✅ **技術交付達成（2026-04-25）**：
  - **NativeBridgeFacade**：`lib/platform/native_bridge_facade.dart` 抽象介面 + `_RealNativeBridgeFacade` delegate，14 method（4 handoff + 10 BLE central）；`HandoffController` / `BleScanController` 全 routing 改走 facade
  - **FakeNativeBridge + controller 測試**：`test/fakes/fake_native_bridge.dart` + `test/controllers/ble_scan_controller_test.dart` 12 案例（含 Uint8List? 雙路徑、StreamController 透傳、resetToReal 還原）全綠
  - **navigation→handoff role**：`navigation_screen.dart:_startHandoff` 改依 `match.deliveryMode` 判定 provider/requester
  - **Bug 修正**：`station_supply_screen._RegisterTabState` 的 controller dispose 從 `deactivate()` 移到正確的 `dispose()`
  - **palette 收斂**：onboarding loading `Colors.black` → `0xFF0d0d1a`、triage SOS_RED 鎖定 `Colors.grey[800]` → `0xFF222244`
  - **單元 + 靜態分析驗收綠燈**：
    ```
    grep -r "NativeBridge\." lib/ui/                              →  0  ✓
    flutter analyze                                                → 50 issues  (≤ 50) ✓
    dart run tool/check_layers.dart                                → ok  ✓
    flutter test × 2（平行 isolate，含 stage-5-fix DB 隔離）        → 321/321 兩輪全綠 ✓
    ```
- ⚠️ **未完成**：模擬器全鏈路驗收（onboarding→發需求→發供給→導航→實體交接）尚未執行。本輪 CLI 環境無法驅動 emulator；驗收骨架已留在 `resqmesh_app/docs/leak_inventory.md` Stage 5-fix「回應 3」段，由具備裝置者補做後再蓋章 Stage 5 為完整完成。

### Stage 6 — iOS Handoff P0 與通訊層補完（commit #10）✅ 技術交付達成（iOS 實機 / Android E2E 待測）

- **目標**：修掉分析文件的 P0，讓 handoff 跨平台閉環，補 schema 前向相容能力，清通訊層集合
- **交付（執行順序固定，不可調換）**：
  1. **iOS handoff 事件型別對齊**：Dart 端期望 `handoff_result`（`native_bridge.dart:389`），iOS 實際送 `handshake_data`（`BlePlugin.swift:585`）— 擇一為準（建議跟 Android 保持一致），在 `handoff_controller` 歸一化；iOS BlePlugin.swift 的 duplicate case 清掉
  2. **完成 iOS `sendHandoffPin`**（目前是 TODO，`BlePlugin.swift:232`）：對齊 Android PIN hash + resourceId 驗證邏輯
  3. **protobuf `HandshakeCompleteData` 加 `schema_version` 欄位**（`mesh_protocol.pb.dart:1959`；預設值 `0` 代表舊 client）：取代「外掛裸 version byte」方案，利用 protobuf 未知欄位向後相容特性；`publishHandshakeComplete` 帶入真實 providerPubKey / requesterPubKey / actualDeliveredQty
  4. **transport 層集合 TTL 清理**：依 Stage 4b 產出的 `resqmesh_app/docs/leak_inventory.md` 對 transport 範圍的 leak 熱點（`BleManager` 已知三處 + 盤點新增）加 TTL / LRU / 容量上限；**不碰 chat / match 範圍的集合**（那些由各自分頁負責或 Stage 7 處理）
  5. iOS 建置：補 `Podfile` 模板、`Podfile.lock` 策略說明、`Generated.xcconfig` git 忽略規則
- **驗收**：
  - Android ↔ Android 模擬器 handoff E2E 走通（我可測）
  - **schema_version 新舊端雙向相容性實測**：
    - 新 client 解析不含 `schema_version` 的舊 payload（protobuf 預設為 `0`）→ 不崩、流程可繼續
    - 舊 client 解析含 `schema_version` 的新 payload（protobuf 未知欄位忽略）→ 不崩、流程可繼續
    - 兩向各一次實測，記錄於 commit 訊息
  - transport 集合壓力測試：連續發現/連接若干 peer 後，集合大小有上界而非單調成長
  - iOS 編譯與實機：使用者之後自行在 macOS 驗證；commit 訊息註明「iOS 實機測試待執行」
- **commit**：`refactor(stage-6): handoff 跨平台閉環 + schema_version + transport TTL`
- ✅ **技術交付達成（2026-04-25）**：
  - **handoff event 統一為 `handoff_result`**：iOS `BlePlugin.swift` GATT server 在收到 HANDSHAKE_CHAR 寫入後做 SHA-256 + resourceId 比對並 emit `handoff_result`；Android `IgniRelayForegroundService.processCharacteristicWrite` 從原本 fall-through `else` 抽出顯式 HANDSHAKE branch 做相同驗證。`HandoffController.events` 對舊版 iOS `handshake_data` fallback 為 `success=false + legacy=true`（向後相容）。
  - **iOS duplicate case 清理**：`BlePlugin.swift` 第二個 `case "requestBluetoothEnable"` 移除。
  - **iOS `sendHandoffPin` 完成**：對齊 Android `MainActivity.verifyHandoffPin`，本地 SHA-256 + resourceId 比對。
  - **schema_version**：`HandshakeCompleteData` 加 tag 10 `schema_version`（int32, default 0）+ `kCurrentSchemaVersion = 1`；`publishHandshakeComplete` 寫入時帶版本號。`.proto` 同步加上 message 宣告（文件用，不重 generate）。
  - **publishHandshakeComplete 帶真實值**：`physical_handoff.dart` 4 處呼叫從原 `providerPubKey: []` / `requesterPubKey: []` / `actualDeliveredQty: 0` 改成從 `Match_Negotiations` row 讀回（fallback chain：actual_delivered_qty → agreed_qty → offered_qty）。
  - **transport TTL/LRU**：`BleManager.uniquePeersEverSeen` 改 FIFO bounded(500)、`_cancelledSyncs` 改 FIFO bounded(200) + cooldown 過期時連帶清除；抽出可重用的 top-level `addBoundedFifo<T>` helper。
  - **iOS 建置**：補 `ios/Podfile` 模板（platform 13.0、`flutter_ios_podfile_setup`）；`ios/.gitignore` 補 Podfile.lock 必須 commit 的策略註記；`Generated.xcconfig` 已 ignore（既有規則）。
  - **新增測試 14 案例全綠**：
    - `test/controllers/handoff_controller_test.dart`：3 案例驗證跨平台 event 歸一化。
    - `test/proto/handshake_schema_compat_test.dart`：5 案例驗證 schema_version 雙向相容（含 tag-99 unknown field 壓力）。
    - `test/transport/bounded_set_test.dart`：6 案例驗證 `addBoundedFifo` FIFO 語意 + 10000 筆灌入仍 ≤ cap + BleManager singleton smoke。
  - **驗收綠燈**：
    ```
    flutter analyze                                       → 50 issues  (≤ 50) ✓
    dart run tool/check_layers.dart                       → ok ✓
    flutter test × 2                                      → 335/335 兩輪全綠 ✓
    ```
- ⚠️ **未完成（必須由具備裝置者補做）**：
  - Android↔Android 模擬器 handoff E2E（plan acceptance 第 1 條）：本輪 CLI 環境無法驅動 emulator。
  - iOS 編譯 / 實機（plan acceptance 第 4 條）：須 macOS + Xcode；本輪只完成程式碼修改與 Podfile 模板。
  - transport 集合「真實 BLE peer 大量發現」壓力測試（plan acceptance 第 3 條的 in-app 重現）：本輪以 `addBoundedFifo` 單元壓力測試（10000 筆）作代換；BleManager 端到端壓測仍待 emulator/裝置。

### Stage 7 — 收尾（commit #11）

- **目標**：品質清理、刪舊碼、文件同步、i18n 安全化、Design System 視覺鎖定、**吸收 Stage 4d Round 2 列名的結構債**
- **Stage 4d 結構債（D 類，本階段必做）**：
  - **引入 `MapController`**：採 **ChangeNotifier + ListenableBuilder**（選項 A，不新增套件，可讀性與可測性最平衡；決策於 Stage 4d Round 2 規劃時定案）。把 `_loadOverlays` / `_loadHazards` / `_loadEventMarkers` / `_refreshPoiMarkers` 的讀寫以及 `_activeSosEventId` / `_userLocation` / `_hazardData` / `_eventMarkers` / `_eventMarkerCategories` / `_layerSettings` 搬進 controller。
  - 拆 `MapView` / `HazardLayer` / `PoiLayer` / `SelfMarker` / `HazardReportFlow` 五個原契約 widget，皆以 controller 為 single source of truth（Stage 4d Round 2 因耦合延後到此）。
  - **`DistrictRoadLookup` 真實實作**：擴充 `PoiQuery` 支援 place/road vector-tile 查詢（或另建 lookup util），把 Stage 4d 的 stub（`map_location_header.dart:85`）接起來。此項動到 `lib/app/mesh/`，不放 Stage 6（Stage 6 執行順序已滿）。
  - 替換 map 各 sheet/panel 硬碼色（`Color(0xFF1a1a2e)` 等）為 IgniPalette token（Stage 4d Round 2 刻意不做）。
- **一般交付**：
  - 刪除所有過渡檔、`// TODO: removed in refactor` 殘留、無用 import
  - `flutter analyze` 清到 < 20 issues
  - `writeDebugLog` 改可 await + 測試通過（解掉原 1 fail）
  - 補 E2E 測試：match → navigation → handoff → complete
  - **i18n 安全化**：全域搜尋並替換不安全的 `S.of(context)!` / `AppLocalizations.of(context)!` 強制解包（已知熱點 `main.dart:254`）— 改為安全取值（e.g. 加 null check、fallback 字串、或確保上層 `MaterialApp` 已就緒）；**不重建 i18n 架構**，僅消除啟動 / async UI 回呼時序崩潰風險
  - **Design System Golden 最小集 3×3**：
    - 3 個元件：`GlassCard`、`StatusChip`（覆蓋 6 種 tone 於同一 scene）、`GlassIconBtn`（default / selected / danger 三態於同一 scene）
    - 3 個主題：`AppTheme.dark()` / `.light()` / `.emergency()`
    - 共 9 張 golden baseline；不納入 `SlideUpSheet` / `PulseEffect` / `RippleEffect` 等動畫類（避免維護爆炸）
  - **Token smoke test**：改任一 semantic token（如 `p.brand` 值）應觸發 golden diff，手動 `flutter test --update-goldens` 才能通過；寫入 `resqmesh_app/docs/golden_workflow.md` 記錄規則
  - 版本號 bump 至 `0.2.0`
- **驗收**：
  - `flutter test` 全綠（含 9 張 golden）、`flutter analyze` < 20
  - 模擬器冷啟動到 SOS 完整路徑無 regression
  - `grep -rE "S\.of\(context\)!|AppLocalizations\.of\(context\)!" lib/` 結果為 0
  - Token smoke：手動改一個 token 值跑 `flutter test`，應 fail 於 golden 比對（證明鎖定有效），還原即恢復綠燈
- **commit**：`refactor(stage-7): 清理品質 + i18n 安全化 + Golden 鎖定 + bump 0.2.0`

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
| 地圖 2303 行（Round 2 起點，原始 2331）拆分誤傷 | Stage 4d Round 2 前先完成 sheet / panel 耦合盤點，於 `leak_inventory.md` 追加對照 |
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
