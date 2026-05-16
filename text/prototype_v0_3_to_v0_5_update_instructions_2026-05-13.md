# 烽傳 Prototype 更新指令：v0.3 → v0.5 完整 UI/UX 規劃

Date: 2026-05-13
Target: 原型 agent（負責 `C:\Users\radio\Downloads\烽傳\` 下的 JSX 原型）
Source briefs:
- `text/resqmesh_v0.2.5_tech_debt_architecture_hardening_brief_2026-05-13.md`（後端技債，不影響原型）
- `text/resqmesh_v0.3_v0.5_protocol_roadmap_spec_brief_2026-05-13.md`（v0.3-v0.5 功能 roadmap，本指令的根據）

---

## 0. 任務概述

你目前的原型停留在 v0.1.27（4 tabs：地圖/聊天/媒合/我），需要做兩件事：

1. **同步主 App 已偏離原型的變動**（onboarding、physical_handoff FSM、survival_mode 等等，見 §2）。
2. **把原型推進到 v0.5 願景**：新增 v0.3 → v0.5 規劃的所有畫面與互動（合計 35 + 25 + 14 = 74 個畫面 / 元件 / section）。

完成後，原型即為 v0.5 完成時的 UI/UX 完整 mock。

> **Scope note (added 2026-05-15):** 本文件僅描述原型（JSX mock）工作，不含主 App 實作指示。主 App 的 v0.3 UI/UX feature 實作必須等 v0.3 Stage 0d 真機驗收 gate 通過後才開始（見 `text/resqmesh_v0.3_v0.5_protocol_roadmap_spec_brief_2026-05-13.md` §3.5）。本文件**不應**加入 BLE / protocol / wire-format / envelope / signature / chunking / MTU / IBLT 等通訊層細節——那些屬於 `docs/specs/envelope_v2_spec_2026-05-13.md` 與 `docs/specs/native_transport_v1_2026-05-13.md`，不在原型範圍。原型 agent 收到通訊層概念時請拒絕、回報，不要把細節塞進原型文件。

**重要原則：**
- 沿用既有設計系統（glass 模糊 / mono 字體 / accent token / dark+light theme）。不要重新發明 token。
- 沿用既有 SheetShell / SheetHeader / GlassIconBtn / QuickAction / SectionLabel / SubPageHeader 元件。
- 不要實作真實邏輯。原型 = 視覺與互動 mock，所有資料用 hard-coded 假資料。
- 新檔案要 `Object.assign(window, { ... })` 暴露元件給 App.jsx 使用，遵循現有 pattern。

---

## 1. 鎖定的目標架構

### 1.1 底部 5 tabs（從 4 tab 改 5 tab）

```
Tab 1  現在 Now    ← 新首頁，預設啟動 tab
Tab 2  地圖 Map
Tab 3  聊天 Chat
Tab 4  媒合 Match
Tab 5  指南 Guide  ← 新 tab
```

「我 Me」不再是 tab，改由 **Now 右上角 avatar** tap 後 push 全頁進入。

### 1.2 App.jsx 必要變動

- `TAB_KEY` 預設值 `'now'`（不是 `'map'`）
- `TabBar` 的 `tabs` 陣列改成 5 項：`now / map / chat / match / guide`
- router 加 `tab === 'now'` 與 `tab === 'guide'`
- 加一個全域 `meOpen` state；Now 右上 avatar 點下 `setMeOpen(true)`；`meOpen` 顯示時整層蓋 MeScreen（既有 MeScreen 沿用，當 push page）

### 1.3 圖示對應（核對 Icon.jsx 現況）

實測 `components/Icon.jsx` 內：
- 已存在：`home` / `map` / `chat`（alias of `message-circle`）/ `handshake` / `life-buoy`（**注意連字符**）
- **不存在**：`compass` / `book` / `lifebuoy`（無連字符）

最終 tab icon 取用：

| Tab | icon name | 來源 |
|---|---|---|
| now | `home` | 既有 |
| map | `map` | 既有 |
| chat | `chat` | 既有 alias |
| match | `handshake` | 既有 |
| guide | `life-buoy` | 既有（**`life-buoy` 有連字符**） |

若需 active/inactive 不同 icon，沿用同名（原型尚未做 filled/outlined 分版）。

---

## 2. 原型與主 App 偏離 — 必須補回的部分

主 App（`resqmesh_app/lib/ui/`）在原型製作後做了大量改動。下表列出原型缺少的部分，要在這次更新一併補上：

| # | 主題 | 主 App 現況 | 原型應補 |
|---|---|---|---|
| D1 | Onboarding | `secondary/onboarding_screen.dart` 全頁多步驟 | 補一個 `Onboarding.jsx`（但 v0.3 會被 disaster install flow 取代，見 §3） |
| D2 | 媒合 sub-tabs 命名 | requests / supplies / negotiations / community | 改原型 MatchScreen 的 tab id 與順序 |
| D3 | 物資發布 | 拆 `supply_registration.dart` 全頁 + `station_supply_screen.dart` + `resource_request_sheet.dart` | **保留**既有 PublishSheet（媒合內快速發布），**另補**三個獨立全頁版（SupplyRegistration / StationSupply / ResourceRequest）對齊主 App |
| D4 | 實體交接 | `physical_handoff.dart` 是 FSM（PENDING→CONFIRMING→COMPLETING→DONE/FAILED）+ `navigation_screen.dart` 真實導航 | **保留**既有 HandoffScreen 的 pin/ble/dropoff mode tab 作為「選擇交接方式」；**另補** PhysicalHandoffFSM 處理選定後的階段流程；NavigationScreen 為新增獨立全頁 |
| D5 | 地圖 | flutter_map + MBTiles 真實 tile + `hazard_report_flow.dart` 多步驟 marking + `map_screen_controller.dart` | 原型 SVG 可保留作 mock 視覺；補 hazard_report_flow 多步互動 |
| D6 | Hazard sheets | hazard_info / delete / nearby / dialog 四個分開 | 原型只有 DetailSheet，要拆成 4 個 |
| D7 | Survival mode | `survival_mode_screen.dart` 完整 dev 控制台 | 補一個 SurvivalMode.jsx（將整合進 v0.3 Me 的 dev section） |
| D8 | Triage input | `triage_input.dart` 全頁 | 補 TriageInput.jsx |
| D9 | 電池最佳化 | `battery_optimization_guide.dart` 全頁多步驟 | 補 BatteryOptimizationGuide.jsx |
| D10 | 聊天加入 | `chat_join_screen.dart` 全頁 | 把原型 JoinRoomSheet 升級成全頁 ChatJoinScreen |
| D11 | POI info | `poi_info_sheet.dart` 獨立 | 從 DetailSheet 拆出 PoiInfoSheet |
| D12 | Event info | `event_info_sheet.dart` 獨立 | 從 DetailSheet 拆出 EventInfoSheet |
| D13 | SOS 取消 | `sos_cancel_dialog.dart` 獨立 | 補 SosCancelDialog |

**做法：** 這些補回的畫面要寫成原型 JSX 元件，**先補 D1-D13 再做 §3-§5**，因為很多 v0.3+ 畫面會 reuse 或擴充這些既有畫面。

---

## 3. v0.3 完整頁面清單（35 個）

按 brief §3-§4 規劃。`flows/disaster_install/` 與 `flows/status_broadcast/` 是新概念資料夾；其餘掛在 `components/` 下。

### 3.1 啟動流程（4 個）

#### 3-01 災難安裝流程容器
- 路徑：`components/DisasterInstallFlow.jsx`
- 結構：三步驟頁面 router（safe → permissions → done）
- 取代既有 onboarding；首次啟動才走，完成後 setTab('now')
- 進入時機：localStorage 沒有 `fengchuan:first_launch_done` 旗標時自動覆蓋整個 App

#### 3-02 你安全嗎？
- 路徑：`components/AreYouSafeScreen.jsx`
- 結構：
  - 頂部 logo + 大標題「現在是緊急狀況嗎？」
  - 三個超大按鈕（全寬，高 88px）：
    - **我安全**（綠色 `var(--ok)`）
    - **需要協助**（紅色 `var(--sos)`，pulse 效果）
    - **稍後再說**（灰色 `var(--text-2)` 輪廓）
  - 底部說明：「您的回答只儲存在本機，**不會自動廣播**到 mesh 網路」
- 互動：點任一按鈕 → 寫 localStorage `fengchuan:initial_status` → 進入 3-03 權限頁
- 樣式：全螢幕 var(--bg-0)，按鈕間距 16px

#### 3-03 權限授權頁
- 路徑：`components/PermissionsScreen.jsx`
- 結構：
  - 標題「需要 3 個權限」
  - 3 張權限卡：BLE / 位置 / 通知
    - 每張：icon 大 + 標題 + 一行說明 + 「授權」按鈕（按下變「已授權 ✓」）
  - 底部「全部跳過 →」次要連結
- 互動：點任一「授權」→ 假裝授權成功（mock 用 useState）；底部「下一步」按鈕（3 個都授權後變主色）
- 跳過後仍可進主畫面；3 個都授權 → 「完成」按鈕；都按完 → setTab('now') + 寫 `fengchuan:first_launch_done`

#### 3-04 延後設定清單入口（不獨立頁，是 Now 的 section + Me 的 section）
- 邏輯：未完成項目（暱稱、醫療卡、battery_optimization）做成 checklist
- 顯示位置：Now 主畫面底部 + Me 主畫面中段
- 用 prop `deferredItems = [{ id, title, done, onTap }]`

### 3.2 Tab 1 現在 Now（8 個）

#### 3-05 NowScreen 容器
- 路徑：`components/NowScreen.jsx`
- 結構：可滾 ScrollView，下列 7 個 section 由上而下排列
- Header：右上 avatar (32px) tap → setMeOpen(true)；左上「現在」標題 + mono 副標「2026-05-13 14:32 · 24 度」

#### 3-06 SOS 大按鈕 section
- 路徑：`components/now/SosSection.jsx`（或內嵌在 NowScreen）
- 結構：
  - 全寬卡片，高 160px
  - 大紅按鈕（120px 高）「緊急求救 SOS」+ pulse 動畫（沿用既有 ripple keyframe）
  - 按下 → 開啟 SOSSheet（既有，沿用）
  - 卡片底部「長按取消廣播」灰字小提示

#### 3-07 我的狀態 section
- 路徑：`components/now/MyStatusSection.jsx`
- 結構：
  - 卡片頂部「我的狀態」label + 「修改」按鈕
  - 當前狀態 chip（大）：圖示 + 文字（例：✓ 安全 / ⚠ 需要協助 / 💧 需要水）
  - 副標：「3 分鐘前更新 · 已分享給 mesh」或「僅本機」
- 互動：tap 整張卡 → 開啟 status_broadcast_sheet（3-34）

#### 3-08 鄰近告警 section
- 路徑：`components/now/AlertsSummarySection.jsx`
- 結構：
  - section label「鄰近告警」+ 右側「查看全部」連結（→ alerts_list_sheet）
  - 最多 3 條 alert 卡（小型）：
    - 左 source icon（NCDR / CWA badge）
    - 標題 + 時間 mono
    - 右 chevron
  - 沒有告警時：「目前無告警」灰字佔位
- 互動：tap 條目 → 開啟 official_alert_detail（3-16）

#### 3-09 Mesh 狀態 section
- 路徑：`components/now/MeshStatusSection.jsx`
- 結構：
  - 三欄 mono 數字：附近 X 節點 / 最後同步 Y 秒前 / 佇列 Z 條
  - 整張 tap → push 進 survival_mode_screen（既有 D7 補的）
  - 副標：「BLE Mesh · OFFLINE · PRIVATE」

#### 3-10 快速進入 section
- 路徑：`components/now/QuickActionsSection.jsx`
- 結構：2x2 grid，4 大圖示按鈕（80x80）
  - 媒合（→ setTab('match')）
  - 聊天（→ setTab('chat')）
  - 指南（→ setTab('guide')）
  - 地圖（→ setTab('map')）

#### 3-11 最近事件 section
- 路徑：`components/now/RecentActivitySection.jsx`
- 結構：
  - section label「最近事件」
  - 最多 5 條（SupplyCard 縮小版 mix EventInfoSheet 摘要）
  - tap 條目 → 開啟對應 detail sheet（event_info / supply_detail）

#### 3-12 Now 頂部 AppBar
- 路徑：`components/now/NowAppBar.jsx`
- 結構：左標題 + 右 avatar (32px 圓，accent 底，初字)
- avatar tap → 在 App.jsx 維護 `meOpen` state，true 時 MeScreen 以 `position: absolute, inset: 0, zIndex: 30` 覆蓋整層；MeScreen 既有的 sub-router（medical / handoff）保留，新增「← 返回」icon button 設 `meOpen=false`

### 3.3 Tab 2 地圖（6 個變更）

#### 3-13 地圖狀態 chip
- 路徑：`components/map/StatusChip.jsx`
- 結構：放在 MapHeader 左側，現有「離線地圖」標題旁邊
  - 圓底 chip：圖示 + 狀態文字（例：✓ 安全）
- 互動：tap → 開啟 status_broadcast_sheet

#### 3-14 告警圖層 overlay
- 路徑：`components/map/AlertsLayer.jsx`
- 結構：在 MapBackground 上方絕對定位
  - CAP polygon：用 SVG `<polygon>` 半透明色塊（紅/橙/黃依 severity）
  - icon marker：放在 polygon 中心
- 互動：tap marker → 開啟 official_alert_detail
- 顯示控制：受 layers state 控制（map_layer_settings 加新開關）

#### 3-15 告警列表 sheet
- 路徑：`components/map/AlertsListSheet.jsx`
- 結構：SheetShell maxHeight="70%"
  - SheetHeader 「官方告警」+ 右側「刷新」icon
  - source filter chip 列：全部 / NCDR / CWA / 其他
  - 列表（time-sorted）：每條 = icon + title + source label + last_updated mono
  - tap 條目 → 切換到 official_alert_detail（push）
- 觸發：MapHeader 加一個告警 icon 按鈕（GlassIconBtn icon="alert"）→ 開啟此 sheet

#### 3-16 告警 detail 全頁
- 路徑：`components/alerts/OfficialAlertDetail.jsx`
- 結構：
  - SubPageHeader 「告警詳情」
  - 大標題 + severity badge
  - meta 區塊（mono）：source / 發佈時間 / 影響範圍 / 簽章狀態（valid/invalid/missing/not_checked，badge 顏色不同）
  - CAP 內文（純文字 markdown）
  - 「在地圖中心顯示」按鈕 → setTab('map') 並 fly to centroid
- 樣式：signature 狀態用 4 種顏色 chip

#### 3-17 layer 設定擴充
- 修改：`components/Sheets.jsx` 內既有 LayersSheet
- 加分組標題：
  - 「POI 圖層」（既有 hospital / pharmacy / police / shelter / supermarket / convenience / fast_food / restaurant）
  - 「事件圖層」（既有 hazards / confidence）
  - 「**官方告警**」（新增 toggle：CAP polygon / source filter sub-toggles）

#### 3-18 Stale-drop banner
- 路徑：`components/StaleDropBanner.jsx`
- 結構：App 層 banner（z-index 60），畫面頂部下滑進入
  - 文字：「N 條過期事件已從清單移除」+ 右側「查看歷史」連結（→ 3-35）
  - 5 秒後自動隱藏
- 觸發時機：mock；提供一個 dev button 觸發測試

### 3.4 Tab 3 聊天（0 個變更）

v0.3 不動。沿用既有 ChatScreen / ChatRoom / JoinRoomSheet（但 JoinRoomSheet 需要升級成全頁 ChatJoinScreen，見 D10）。

### 3.5 Tab 4 媒合（1 個變更）

#### 3-19 requests intent 接收
- 修改：MatchScreen 接受 props 或讀 window.__pendingSupplyIntent
- 邏輯：status_broadcast_sheet 送出 NEED_WATER 後若選「建立物資需求」→ 寫 `window.__pendingSupplyIntent = { cat: 'water' }` → setTab('match') → MatchScreen 偵測到 → 自動切 'request' tab + 開 PublishSheet kind='request' 預填 cat
- 同時通過 props 讓 MatchScreen 知道 active sub-tab 與是否預開 sheet

### 3.6 Tab 5 指南 Guide（4 個）

#### 3-20 Guide 主畫面
- 路徑：`components/GuideScreen.jsx`
- 結構：
  - Header 「指南」+ 副標「離線災難應變參考」
  - section A：5 張應變卡 grid（2 欄）
  - section B：關於本 App（一張卡片）

#### 3-21 應變卡列表
- 路徑：`components/guide/TaskCardList.jsx`
- 結構：grid 2 欄
  - 卡片：icon 大（48px）+ 標題 + 1 行摘要 + 「離線可讀」chip
  - 5 張：
    - 地震（earthquake）
    - 火災（fire）
    - 出血急救（bleeding）
    - 通訊中斷（comm_outage）
    - 撤離移動（evacuation）
- 互動：tap 卡 → push 進 TaskCardReader

#### 3-22 應變卡閱讀頁
- 路徑：`components/guide/TaskCardReader.jsx`
- 結構：
  - SubPageHeader（標題 = 卡片名）
  - meta row（mono）：來源 / 最後更新 / 「離線可用」chip
  - 內文（mock markdown：標題、列點、加粗）
  - 底部「分享給附近裝置」按鈕（v0.5 才實際發 mesh，原型只 mock）

#### 3-23 關於本 App section
- 路徑：`components/guide/AboutSection.jsx`
- 結構：
  - 免責聲明卡：「**本 App 不取代官方救災工具**。緊急請撥 119 / 110 / 112。」紅底
  - 版本資訊（mono）：App version / 通訊協議版本 / freeze 狀態（chip：已凍結 / 進行中）
  - 連結：「協議細節」（→ 假連結）/「測試者回報」/「開發者選項」（→ Me 內 dev section）

### 3.7 Me 頁面（v0.3 重整，10 個 section）

Me 不再是 tab，但畫面內容大幅擴充。沿用既有 MeScreen 結構，把下列 section 依序排：

#### 3-24 Me 容器（既有 MeScreen 改）
- 加上頂部「← 返回」按鈕（push page 模式，不是 tab）
- 從 NowAppBar 的 avatar tap 進入

#### 3-25 身分卡 section（既有，不動）

#### 3-26 醫療卡片 entry（既有 QuickAction，不動）

#### 3-27 延後設定清單 section
- 路徑：`components/me/DeferredSetupSection.jsx`
- 結構：checklist 卡，未完成項目顯示
  - 暱稱（→ 開 InputDialog）
  - 醫療卡（→ MedicalCardScreen）
  - BLE 權限（→ 開系統授權，mock 直接打勾）
  - 位置權限（同上）
  - battery_optimization（→ BatteryOptimizationGuide）
- 顯示條件：localStorage 至少有一項未完成才顯示

#### 3-28 告警二次入口
- 路徑：`components/me/AlertsEntrySection.jsx`
- 結構：單列 row（用既有 SettingsRow）「官方告警」icon=alert + 紅點 badge if 未讀
- tap → push AlertsListSheet（共用 3-15）

#### 3-29 無障礙設定
- 路徑：`components/me/AccessibilitySection.jsx`
- 結構：section label「無障礙」+ 卡片內 3 個 SettingsRow：
  - 字級（slider：S / M / L / XL）
  - 高對比模式（toggle）
  - 語意標籤（toggle）+ 副標「為螢幕閱讀器加強描述」
- 樣式：用既有 SettingsRow + 自訂 detail

#### 3-30 應變卡入口
- 路徑：`components/me/GuideEntrySection.jsx`
- 結構：QuickAction「離線應變指南」icon=book
- tap → setTab('guide') + 關閉 Me

#### 3-31 設定 section（既有，不動）

#### 3-32 開發者 Mesh trace log
- 路徑：`components/me/DevTraceSection.jsx`
- 結構：
  - section label「開發者」
  - 卡片：
    - 「Mesh Trace Log」row → push DevTraceLogScreen
    - 「Survival Mode」row → push SurvivalMode（D7 補的）
    - 「重置本機資料」row（紅字，危險動作）
- DevTraceLogScreen 結構：
  - mono table 顯示最近 50 條 trace
  - 欄位：時間 / envelope_id / event_type / priority / author（縮寫）/ last_relay / drop_reason / hop
  - 上方 filter chip：sent / received / dropped / dedupe_hit

#### 3-33 battery_optimization_guide（既有 D9 補的，從 deferred setup 或設定進入）

### 3.8 全域 / Modal（2 個）

#### 3-34 狀態廣播 sheet
- 路徑：`components/StatusBroadcastSheet.jsx`
- 結構：SheetShell maxHeight="85%"
  - SheetHeader「設定狀態」
  - 6 個大按鈕（grid 2 欄）：
    - ✓ 我安全（綠）
    - ⚠ 需要協助（紅）
    - 🩹 受傷（紅）
    - 💧 需要水（橙）
    - 🔋 需要電力（橙）
    - 💊 需要藥品（橙）
  - toggle「向附近 mesh 分享」（預設關閉）
  - 「分享」按鈕（accent，全寬）
  - 副標：「同樣狀態若已分享，新一筆會覆蓋舊的（LWW）」
- 互動：若選的是 NEED_WATER / NEED_POWER / NEED_MEDICINE 且按了「分享」→ 跳出小 confirm「要為這項需求建立物資需求嗎？」→ Yes 跳 match（見 3-19）

#### 3-35 歷史 / 已過期事件 viewer（dev mode）
- 路徑：`components/HistoryExpiredEventsScreen.jsx`
- 結構：
  - SubPageHeader「過期事件歷史」
  - filter：時間範圍（24h / 7d / 全部）
  - 列表：每條灰底（表示已過期）+ event 摘要 + 過期時間
- 進入點：StaleDropBanner 的「查看歷史」連結

---

## 4. v0.4 完整頁面清單（25 個）

依 brief §5。這些頁面在 v0.3 完成後加，但**現在原型 agent 一併做完**，這樣 prototype 就是 v0.5 願景的完整 mock。

### 4.1 電量分享（3 個）

#### 4-01 電量分享 opt-in
- 路徑：`components/me/BatteryShareSection.jsx`
- 加在 Me 設定區
- toggle + 說明 + 半徑 slider

#### 4-02 Peer marker tooltip 電量欄
- 修改：MapScreen 的 SelfMarker 旁加 nearby peer markers（mock 3 個 peer）
- tap peer marker → tooltip 顯示：暱稱 / Tier / 電量百分比 / RSSI

#### 4-03 Community tab peer 卡電量
- 修改：CommunityCard 加電量 row（圖示 + 百分比 + mono）
- 條件：item 有 `battery` 欄位才顯示

### 4.2 避難所狀態（3 個）

#### 4-04 避難所 detail sheet
- 路徑：`components/map/ShelterDetailSheet.jsx`
- 擴充既有 PoiInfoSheet
- 多顯示：開放狀態 chip（open/full/closed）+ 需求 chip 群（needs-water / needs-power / needs-medical）+ LWW 時間 + source trust
- 底部按鈕：「我管理這個避難所」→ ShelterAdmin

#### 4-05 我的避難所管理
- 路徑：`components/me/ShelterAdminScreen.jsx`
- 結構：列表「我管理的避難所」+ 「新增」FAB
- 列表項 tap → ShelterEdit

#### 4-06 避難所狀態編輯
- 路徑：`components/me/ShelterEditScreen.jsx`
- 結構：表單
  - 名稱 / 地址 / 容量
  - 狀態 radio（open/full/closed）
  - 需求 multi-toggle（needs-water / needs-power / needs-medical / needs-volunteer）
  - 「送出更新」→ mock 廣播

### 4.3 技能 / 資源登錄（3 個）

#### 4-07 技能登錄表單
- 路徑：`components/me/SkillRegistrationScreen.jsx`
- 結構：表單
  - 預設技能 chip 群：醫護 / 護理 / 急救 / 電工 / 水電 / 駕駛 / 翻譯（多選）
  - 自訂：textarea
  - 「local-first」說明：「不會自動廣播，只在你按 share 時才告知附近」

#### 4-08 我的技能 list
- 路徑：`components/me/MySkillsSection.jsx`
- 顯示已登錄技能 chip 群 + 「編輯」連結

#### 4-09 技能分享動作
- 路徑：`components/SkillShareSheet.jsx`
- SheetShell：選擇要 share 哪些技能 + 半徑 slider + 「分享」按鈕

### 4.4 災情照片（3 個）

#### 4-10 hazard_report_flow 加照片步驟
- 修改：hazard_report_flow（D5 補的）多一步「加照片（選用）」
  - 拍照 / 從相簿選 / 跳過
  - 顯示：「照片會剝離 EXIF，僅傳送縮圖+雜湊到 mesh」

#### 4-11 離線上傳佇列
- 路徑：`components/me/PhotoQueueScreen.jsx`
- 結構：列表，每張照片 + 狀態（等待 / 上傳中 / 已完成 / 失敗）
- 連網時自動重試

#### 4-12 事件 sheet 加照片摘要
- 修改：EventInfoSheet 加 thumbnail row
- tap thumbnail → 大圖預覽 modal

### 4.5 Relay-to-Contact（3 個）

#### 4-13 緊急聯絡人 list
- 路徑：`components/me/EmergencyContactsScreen.jsx`
- 結構：
  - 列表 + 「加入聯絡人」FAB
  - 每筆：名字 / 關係 / 電話（遮罩 09xx-xxx-***）
- 來源：App-owned 或 OS 權限 import

#### 4-14 聯絡人 relay 請求 form
- 路徑：`components/flows/RelayRequestScreen.jsx`
- 結構：
  - 選聯絡人（從 4-13 list）
  - 訊息 textarea
  - 「送出 relay 請求」→ 等 B 側確認 mock

#### 4-15 Relay 狀態追蹤
- 路徑：`components/me/RelayStatusScreen.jsx`
- 結構：列表所有 relay 請求 + 狀態（已送 / B 確認中 / 已轉接 / 失敗）

### 4.6 官方告警 mesh summary（2 個）

#### 4-16 告警 detail 加信任標籤
- 修改 3-16：加 3 種來源 badge
  - 「直連」綠
  - 「mesh 中繼」橙（顯示 hop 數）
  - 「未驗證」灰

#### 4-17 告警列表加來源 icon
- 修改 3-15：每條 row 左下加小 badge

### 4.7 Mesh 健康儀表板（2 個）

#### 4-18 Mesh 健康儀表板
- 路徑：`components/MeshHealthDashboard.jsx`
- 結構：full page
  - 大數字：附近節點 / 最後同步 / 佇列大小 / drop 統計
  - 圖：mock hop network（SVG node-link）
  - 列表：最近 dropped events + reason
- 進入點：Now 的 MeshStatusSection tap → 此頁

#### 4-19 Dev mode 深層 panel
- 路徑：`components/MeshHealthDevPanel.jsx`
- 進入點：MeshHealthDashboard 內「開發者模式」toggle
- 顯示：即時 trace log + bandwidth 圖 + 重連次數

### 4.8 SOS 高優通知（2 個）

#### 4-20 SOS 通知設定
- 路徑：`components/me/SosNotifySection.jsx`
- 結構：
  - opt-in toggle
  - 半徑 slider（100m – 5km）
  - 系統權限說明（Android 高優 / iOS critical 待 entitlement）

#### 4-21 SOS 高優通知接收
- 無獨立畫面（系統層通知）
- 但補一個 mock NotificationBanner 元件用於 demo

### 4.9 QR 家庭/隊伍配對 + TOFU（4 個）

#### 4-22 我的 QR
- 路徑：`components/me/pairing/MyQrScreen.jsx`
- 結構：
  - 大 QR 區塊（mock 用 css grid 模擬 QR pattern）
  - 下方：pubkey 短碼（mono）+ 「複製」
  - 「截圖分享」按鈕

#### 4-23 掃描 QR
- 路徑：`components/me/pairing/ScanQrScreen.jsx`
- 結構：
  - 全螢幕黑底 + 中間方框（鏡頭預覽 mock）
  - 邊框 corner pulse 動畫
  - 「手動輸入」連結

#### 4-24 配對確認
- 路徑：`components/me/pairing/PairConfirmScreen.jsx`
- 結構：
  - 雙方資訊 row（我的 / 對方的）
  - TOFU 提示：「首次見到此身分。請確認對方的 pubkey 短碼與你看到的相符。」
  - 大「確認配對」按鈕（雙方都按才成功）

#### 4-25 信任清單
- 路徑：`components/me/pairing/TrustListScreen.jsx`
- 結構：
  - 列表已配對家人 / 隊員
  - 每筆：名字 / 關係 / 配對時間 / 「解除」按鈕

---

## 5. v0.5+ 候選頁面（14 個）

依 brief §6。這些**不需做到精緻**，每個頁面用一個基本 screen 殼 + 1-2 個假資料即可。標明「v0.5 candidate · TBD」字樣。

| # | 頁面 | 路徑 | 一行摘要 |
|---|---|---|---|
| 5-01 | 志工任務板 | `components/volunteer/TaskBoardScreen.jsx` | 列表+認領 |
| 5-02 | 志工任務 detail | `components/volunteer/TaskDetailScreen.jsx` | 描述/地點/狀態 |
| 5-03 | 任務發布 | `components/volunteer/TaskPublishScreen.jsx` | 發布表單 |
| 5-04 | 中繼模式 | `components/me/RelayModeSection.jsx` | toggle + 說明 |
| 5-05 | 中繼模式儀表板 | `components/RelayModeDashboard.jsx` | 已轉送 / uptime |
| 5-06 | 死亡開關設置 | `components/flows/DeadMansSwitchSetup.jsx` | 條件 + 受託人 |
| 5-07 | 死亡開關監控 | `components/me/DeadMansSwitchStatus.jsx` | 倒數 + 取消 |
| 5-08 | OLC 顯示與分享 | （多處小元件） | event sheet + 媒合卡 |
| 5-09 | OLC 輸入 | `components/flows/OlcInputSheet.jsx` | 手動輸入 → 跳到位置 |
| 5-10 | 避難所離線路徑 | `components/navigation/ShelterRouteScreen.jsx` | 離線路徑 mock |
| 5-11 | 語音 PTT | `components/flows/PttOverlay.jsx` | 按住說話 mock |
| 5-12 | 語音 PTT 歷史 | `components/chat/PttHistoryScreen.jsx` | 語音片段 list |
| 5-13 | 供需熱力圖 | `components/map/SupplyHeatmapLayer.jsx` | 密度色帶 SVG |
| 5-14 | 信任圖視覺化 | `components/me/TrustGraphScreen.jsx` | node-link mock |

---

## 6. 共用元件 / 設計系統規則

### 6.1 沿用既有元件（不要重做）

實測 export 狀態：

**A. 已 export 到 window，可直接跨檔使用：**

| 元件 | 來源 | 用途 |
|---|---|---|
| `SheetShell` | Sheets.jsx | bottom sheet 殼 |
| `SheetHeader` | Sheets.jsx | sheet 標題列 |
| `Toggle` | Sheets.jsx | iOS 風 toggle（**已存在，勿重做**）|
| `GlassIconBtn` | MapScreen.jsx | glass 風格圓 icon 鈕 |
| `POI_CATEGORIES` / `HAZARD_LEVELS` | MapScreen.jsx | 圖層分類常數 |
| `CAT_MAP` | MatchScreen.jsx | 媒合分類常數 |
| `Icon` / `LUCIDE` | Icon.jsx | 全部 icon |
| `DesignCanvas` / `DCSection` / `DCArtboard` / `DCPostIt` | design-canvas.jsx | canvas wrapper |
| `IOSDevice` / `IOSStatusBar` / `IOSNavBar` / `IOSGlassPill` / `IOSList` / `IOSListRow` / `IOSKeyboard` | ios-frame.jsx | iOS frame 元件 |

**B. 在原型檔案內存在，但未 export 到 window，跨檔使用前要先 export：**

| 元件 | 來源 | 用途 |
|---|---|---|
| `QuickAction` | MeScreen.jsx | 大型 row action |
| `SubPageHeader` | MeScreen.jsx | push page 頂部 |
| `SettingsRow` | MeScreen.jsx | 設定列 |
| `MedSection` / `MedField` | MeScreen.jsx | 醫療卡欄位 |
| `SectionLabel` | MatchScreen.jsx | uppercase label |
| `EmptyState` | MatchScreen.jsx | 空狀態 |
| `SupplyCard` / `ActiveCard` / `CommunityCard` / `PublishSheet` / `MatchDetailSheet` | MatchScreen.jsx | 媒合卡片群 |
| `ChatRoom` / `ChatMessage` / `JoinRoomSheet` | ChatScreen.jsx | 聊天元件 |
| `MapBackground` / `MapMarker` / `EventMarker` / `SelfMarker` / `POI_POINTS` / `MESH_EVENTS` / `HAZARD_TYPES` | MapScreen.jsx | 地圖元件 |

**做法：** 任何新檔要 import B 區元件時，先到對應原檔的 `Object.assign(window, {...})` 加上 export，再到新檔直接用全域名。

### 6.2 需要新增的共用元件

| 元件 | 路徑 | 用途 |
|---|---|---|
| `StatusBadge` | `components/widgets/StatusBadge.jsx` | 大型狀態 chip（safe / need-help / 等 6 種，搭配既有 `--status-*` token） |
| `SeverityBadge` | `components/widgets/SeverityBadge.jsx` | 告警嚴重度（搭配既有 `--sev-*` token：extreme / severe / moderate / minor / unknown） |
| `SignatureStatusChip` | `components/widgets/SignatureStatusChip.jsx` | 4 種：valid / invalid / missing / not_checked |
| `SourceTrustChip` | `components/widgets/SourceTrustChip.jsx` | 5 種，搭配既有 `--trust-*` token：self / paired / seen-before / unverified / official |
| `Slider` | `components/widgets/Slider.jsx` | 包裝 input[type=range] |
| `Checklist` | `components/widgets/Checklist.jsx` | 多項 checkbox + 完成 % |
| `Banner` | `components/widgets/Banner.jsx` | App 層 banner（stale-drop 等），用既有 `bannerSlideDown` keyframe |
| `NumberPad` | `components/widgets/NumberPad.jsx` | PIN 輸入用（physical_handoff）|

**注意：** `Toggle` 已存在於 Sheets.jsx 並已 export 到 window，**不要重做**，直接全域引用。

### 6.3 設計 token 規則

- 顏色全部用 `var(--xxx)`，不要寫死 hex
- **重要：v0.3 所需的 token 都已存在於 `styles/tokens.css`**（line 33-59）。不要重複定義。直接用以下既有 token：

**狀態 token（給 status broadcast / my status / Now 狀態 chip 用）：**
```
--status-safe       / --status-safe-bg
--status-help       / --status-help-bg
--status-injured    / --status-injured-bg
--status-water      / --status-water-bg
--status-power      / --status-power-bg
--status-medicine   / --status-medicine-bg
```

**來源信任 token（給告警 / 物資來源標籤用）：**
```
--trust-self        --trust-paired      --trust-seen
--trust-unverified  --trust-official
```

**告警嚴重度 token（給 Official Alerts CAP 顯示用）：**
```
--sev-extreme   --sev-severe    --sev-moderate
--sev-minor     --sev-unknown
```

**僅當 v0.4 / v0.5 出現新概念時才補新 token**，並寫入 tokens.css `:root` 區塊。

### 6.4 動畫規則

- 沿用既有 keyframes（**全部已存在於 `styles/tokens.css`**，line 62-67 與 186-204）：

| keyframe | 用途 |
|---|---|
| `fadeIn` | 通用淡入 |
| `slideUp` | 通用上滑 |
| `slideUpSheet` | bottom sheet 進場 |
| `pulse` | 一般脈動 |
| `ripple` | 圓擴散（SOS / BLE）|
| `scan` | 掃描帶 |
| `dot` | 點點 loading |
| `pulseSos` | **v0.3 新增**：SOS 紅色強烈脈動，1.2s |
| `bannerSlideDown` | **v0.3 新增**：banner 從頂部下滑，0.25s |
| `pingRing` | **v0.3 新增**：圈擴散 ping，可給 mesh status / locate FAB 用 |

- 不要新增 keyframe 除非真的不夠用
- 動畫不要超過 0.4s（pulseSos 與 ripple 例外，本就需要較長）

---

## 7. 檔案組織建議

建議把 `components/` 內分組（不強制，但會比較清楚）：

```
components/
├── App.jsx                       # 改 5 tabs + Me push 邏輯
├── Icon.jsx                      # 補新 icon
├── MapScreen.jsx                 # 加 status_chip + alerts_layer 整合
├── ChatScreen.jsx                # 不動
├── MatchScreen.jsx               # 改 sub-tab id + intent 接收
├── MeScreen.jsx                  # 大幅擴充 sections
├── NowScreen.jsx                 # 新
├── GuideScreen.jsx               # 新
├── Sheets.jsx                    # 改 LayersSheet + 拆既有 DetailSheet
├── Tweaks.jsx                    # 不動
│
├── DisasterInstallFlow.jsx       # 3-01
├── AreYouSafeScreen.jsx          # 3-02
├── PermissionsScreen.jsx         # 3-03
├── StatusBroadcastSheet.jsx      # 3-34
├── HistoryExpiredEventsScreen.jsx # 3-35
├── StaleDropBanner.jsx           # 3-18
├── SurvivalMode.jsx              # D7
├── TriageInput.jsx               # D8
├── BatteryOptimizationGuide.jsx  # D9
├── ChatJoinScreen.jsx            # D10
├── SupplyRegistration.jsx        # D3
├── StationSupply.jsx             # D3
├── ResourceRequest.jsx           # D3
├── NavigationScreen.jsx          # D4
│
├── now/
│   ├── NowAppBar.jsx
│   ├── SosSection.jsx
│   ├── MyStatusSection.jsx
│   ├── AlertsSummarySection.jsx
│   ├── MeshStatusSection.jsx
│   ├── QuickActionsSection.jsx
│   └── RecentActivitySection.jsx
│
├── map/
│   ├── StatusChip.jsx
│   ├── AlertsLayer.jsx
│   ├── AlertsListSheet.jsx
│   ├── PoiInfoSheet.jsx           # 從 Sheets.DetailSheet 拆
│   ├── EventInfoSheet.jsx         # 從 Sheets.DetailSheet 拆
│   ├── HazardInfoSheet.jsx        # D6
│   ├── HazardDeleteDialog.jsx     # D6
│   ├── HazardNearbyDialog.jsx     # D6
│   ├── HazardReportFlow.jsx       # D5
│   ├── SosCancelDialog.jsx        # D13
│   ├── ShelterDetailSheet.jsx     # 4-04
│   └── SupplyHeatmapLayer.jsx     # 5-13
│
├── alerts/
│   └── OfficialAlertDetail.jsx    # 3-16
│
├── guide/
│   ├── TaskCardList.jsx
│   ├── TaskCardReader.jsx
│   └── AboutSection.jsx
│
├── me/
│   ├── DeferredSetupSection.jsx
│   ├── AlertsEntrySection.jsx
│   ├── AccessibilitySection.jsx
│   ├── GuideEntrySection.jsx
│   ├── DevTraceSection.jsx
│   ├── BatteryShareSection.jsx
│   ├── ShelterAdminScreen.jsx
│   ├── ShelterEditScreen.jsx
│   ├── SkillRegistrationScreen.jsx
│   ├── MySkillsSection.jsx
│   ├── EmergencyContactsScreen.jsx
│   ├── RelayStatusScreen.jsx
│   ├── PhotoQueueScreen.jsx
│   ├── SosNotifySection.jsx
│   ├── RelayModeSection.jsx
│   ├── DeadMansSwitchStatus.jsx
│   ├── TrustGraphScreen.jsx
│   └── pairing/
│       ├── MyQrScreen.jsx
│       ├── ScanQrScreen.jsx
│       ├── PairConfirmScreen.jsx
│       └── TrustListScreen.jsx
│
├── flows/
│   ├── SkillShareSheet.jsx
│   ├── RelayRequestScreen.jsx
│   ├── DeadMansSwitchSetup.jsx
│   ├── OlcInputSheet.jsx
│   └── PttOverlay.jsx
│
├── volunteer/
│   ├── TaskBoardScreen.jsx
│   ├── TaskDetailScreen.jsx
│   └── TaskPublishScreen.jsx
│
├── navigation/
│   └── ShelterRouteScreen.jsx
│
├── chat/
│   └── PttHistoryScreen.jsx
│
└── widgets/
    ├── StatusBadge.jsx
    ├── SeverityBadge.jsx
    ├── SignatureStatusChip.jsx
    ├── SourceTrustChip.jsx
    ├── Toggle.jsx
    ├── Slider.jsx
    ├── Checklist.jsx
    ├── Banner.jsx
    └── NumberPad.jsx
```

**index.html / loader 變動：** 若有 entry html，需要把新檔的 `<script>` 標籤都加入。建議改為動態 list 載入。

---

## 8. 交付順序與完成定義

### 8.1 建議的 6 階段交付

**Phase 0a — 啟動前確認（半小時）**
- 確認原型在 host 環境（不論是 in-browser sandbox 或本地 server）能跑起來，4 tabs 都進得去
- 確認 `Icon.jsx` 內所有將用到的 icon 都存在（清單見 §1.3）
- 確認 `tokens.css` 內 `--status-*` / `--trust-*` / `--sev-*` 都在
- 若 host 環境是用 `<script>` 逐檔載入（不是單一 babel-standalone），補載入順序時，把新檔依照「widgets → screens → now/me/guide sections → flows → App」順序加入

**Phase 0 — 偏移補回（D1-D13）約 2 天**
- 不變動 tab 結構，只把主 App 偏離原型的 13 項補上
- 完成後原型 = 主 App v0.2 的完整 mock

**Phase 1 — 5 tab 架構搭建 約 0.5 天**
- 改 App.jsx：4 tab → 5 tab + Me push 邏輯
- 建 NowScreen 與 GuideScreen 殼（先空殼）
- 確認 tab 切換正常

**Phase 2 — v0.3 啟動流程 + Now + Guide 主畫面 約 1.5 天**
- 3-01~3-04 + 3-05~3-12 + 3-20~3-23

**Phase 3 — v0.3 地圖告警與狀態 約 1.5 天**
- 3-13~3-18 + 3-34 + 3-19（match intent）

**Phase 4 — v0.3 Me 重整 + dev tools 約 1 天**
- 3-24~3-33 + 3-35

**Phase 5 — v0.4 全部畫面 約 3 天**
- 4-01~4-25

**Phase 6 — v0.5 候選 mock 約 1.5 天**
- 5-01~5-14（簡化 mock）

合計約 11 天，可分批交付。每階段結束跑一次視覺驗收。

### 8.2 完成定義

每個畫面要滿足：

- [ ] JSX 檔案存在且 `Object.assign(window, {...})` 暴露
- [ ] 在 dark / light theme 下都看得清楚
- [ ] 至少有 1 種互動（tap / toggle / form input）有 mock 反應
- [ ] 使用既有 token，沒寫死 hex
- [ ] iframe 內可從 Now 起點導覽到該畫面，無斷頭路
- [ ] 在 `IOSDevice` 預設 viewport (**402x874**，見 frames/ios-frame.jsx line 191) 下排版正確

全部完成定義：

- [ ] 從 Now 起點可以走到全部 74 個畫面
- [ ] design-canvas.jsx 上每個畫面有獨立框架（thumbnail）
- [ ] tokens.css 補新 token 完整
- [ ] App.jsx 的 router 涵蓋所有頁面
- [ ] 5 tab + Me push 結構完全運作

---

## 9. 共用注意事項

- **不要實作真實 BLE / GPS / Mesh 邏輯。** 全部用 mock 資料。
- **使用 mono 字體**（既有 `var(--font-mono)`）顯示：時間 / 座標 / hash / hops / pubkey / 數值 mono 區塊。
- **glass blur 風格**用於 floating button / tab bar / map header（既有 `backdropFilter: blur(20px) saturate(180%)`）。
- **動畫節制**：SOS pulse 與 BLE ripple 是重點，其餘地方少用。
- **狀態管理**用 React.useState + window 屬性掛接（既有 pattern），不引入 Redux 或 router 套件。
- **localStorage key 命名**沿用 `fengchuan:xxx`。新 key：
  - `fengchuan:first_launch_done`
  - `fengchuan:initial_status`
  - `fengchuan:status_lww`
  - `fengchuan:deferred_setup_done`
  - `fengchuan:accessibility`
  - `fengchuan:battery_share`
  - `fengchuan:trust_list`

---

## 10. 待釐清項目（在 Phase 0 前需確認）

開始前若以下不清楚，先回報而不要自行決定：

1. design-canvas.jsx 是否要為每個新畫面建獨立框架，還是用 router 從一個入口走完？
2. v0.5 候選頁面（§5）是否真的要全部做 mock，還是只列檔名？
3. 既有 PublishSheet（MatchScreen.jsx 內）要不要拆成 SupplyRegistration（D3）+ ResourceRequest（D3）兩個獨立檔，還是保留 PublishSheet 但加入這些畫面作為 fallback?
4. Onboarding（D1）vs DisasterInstallFlow（3-01）的取捨：完全取代還是兩條路徑並存？根據 v0.3 brief §4.2 是完全取代，但 D1 是補回主 App 既有。建議：保留 OnboardingScreen.jsx 作為「延後完成個人檔案」的內容載體，但首啟走 DisasterInstallFlow。
5. Trust tier system（既有 L0/L1/L2/L3）與 v0.4 QR pairing 的 source_trust（self/paired/seen-before/unverified/official）如何映射？建議：兩套並存，pairing 產生「paired」狀態自動升 L2。

---

## 11. 給原型 agent 的最終提示

- 你**不需要**讀 brief 原文。本指令已自含所有資訊。
- 你**不需要**修改主 App（resqmesh_app/）。只動原型（C:\Users\radio\Downloads\烽傳\）。
- 不確定的視覺細節，**先做 minimum viable**，產生 PR / commit 後再迭代。
- 遇到 token 不夠用，**先加到 tokens.css**，不要寫死。
- 每完成一個 Phase 報告：完成清單 + 截圖 + 已知問題。
- 如果 §8.1 的某 phase 工作量爆掉（超過估計 1.5 倍），停下來回報，不要硬幹。
