# 集合洩漏盤點 — Refactoring 0.2.0 Stage 4b

本文件為 0.2.0 重構在 Stage 4b 產出的審查成果，列出 `lib/` 下長壽命單例/
static 物件持有的 `Set<>` / `Map<>` / `List<>` 可能無邊界成長的風險位置，
作為 Stage 4d ~ 6 修補方向的依據。Stage 4b 本身不動這些檔案。

判別原則：
- 只列「單例/全域 state」或「長壽命 Controller 欄位」上的集合。
- method-local 的集合或由 RAII/生命週期自動清除者不列入。
- 盤點來源為 Stage 4b 起點 commit，若後續 Stage 發現新成員再追補。

## 四來源覆蓋結論（Stage 4b 驗收條文對應）

計畫要求至少涵蓋四來源：BleManager、transport peer set、chat message cache、
match repository。逐一結論：

### 1. BleManager — 有 leak（已列入處置表）

| 欄位 | 檔案行號 | 結論 |
|------|----------|------|
| `uniquePeersEverSeen` | `lib/app/mesh/ble_manager.dart:63` | leak，見 L1 |
| `_cancelledSyncs` | `lib/app/mesh/ble_manager.dart:46` | leak，見 L2 |
| `_knownPeers` | `lib/app/mesh/ble_manager.dart:36` | 邊緣案例：目前有 `_peerCooldown` 協同清理，尚未觀察到成長，Stage 6 併案複查 |

### 2. Transport peer set — 無獨立 leak

- `lib/platform/mesh_transport.dart` 為抽象介面，本身不持有集合。
- 唯一的 transport peer 狀態實際存放於 BleManager（同 1.），結論已涵蓋於上表。
- `lib/platform/native_ble_transport.dart` 未持有 `Set<>` / `Map<String, …>` 形式的 peer cache（經 grep 確認）。

### 3. Chat message cache — 無未受控 leak

- 聊天訊息持久化於 SQLite（`Chat_Messages` 表），不在記憶體中累積。
- 聊天相關 in-memory state：
  - `lib/app/services/chat_service.dart:26` `_lastSendTime`（room → epoch ms）：roomId 離開後未清，列入處置表 L3。
  - `lib/app/mesh/mesh_event_handler.dart:67` `_seenEvents`：已有 `_maxSeenEvents = 10000` LRU cap，chat 事件亦走同一條去重，非 leak。

### 4. Match repository — 無 leak

- `lib/app/services/match_repository.dart:286` `seenIds` 為 method-local
  `Set<String>`，單次掃描結束即 GC，非 leak。
- 確認路徑：實際檔案在 `lib/app/services/`（非 `lib/app/repositories/`）。

## 已確認 leak（需處置）

| ID | 位置 | 描述 | 建議處置 | 預計階段 |
|----|------|------|----------|----------|
| L1 | `lib/app/mesh/ble_manager.dart:63` `uniquePeersEverSeen` | 保存所有時間看過的 peer id，重啟前不會清。 | 改為有界 LRU（上限 500）或 N 小時 TTL。 | Stage 6 |
| L2 | `lib/app/mesh/ble_manager.dart:46` `_cancelledSyncs` | 記錄已取消的同步 session id，只寫不讀移除。 | 改 LRU(200) 或同步完成/過期時清。 | Stage 6 |
| L3 | `lib/app/services/chat_service.dart:26` `_lastSendTime` | 記錄每個 roomId 上次送出時間，roomId 離開未清。 | markAsRead / leaveRoom 時同步 remove；否則 LRU(64)。 | Stage 5（併聊天清理） |

## 已確認非 leak（保留於此，避免再被誤列）

| 位置 | 原因 |
|------|------|
| `lib/app/services/match_repository.dart:286` `seenIds` | method-local，單次掃描結束即 GC。 |
| `lib/app/mesh/mesh_event_handler.dart:67` `_seenEvents` | 已有 `_maxSeenEvents = 10000` LRU 保護，不會無界成長。 |
| `lib/app/mesh/mesh_event_handler.dart:80` `debugLogs` | 已有 `_maxDebugLogs = 80` cap。 |
| `lib/platform/native_ble_transport.dart` | grep 無 `Set<>` / `Map<String,…>` 長壽命欄位。 |

## 後續動作

- Stage 4b：本文件落地，不改碼。
- Stage 5：排入 chat_service `_lastSendTime` 清理。
- Stage 6：在 transport TTL/清理 PR 內一併處理 L1/L2，並複查 `_knownPeers`。

## 手測紀錄（Stage 4b 驗收）

於 Android 模擬器（flutter run）以單裝置走下列路徑，確認 UI 流程未破壞：

| 步驟 | 結果 |
|------|------|
| 啟動 app → 進聊天分頁 | 房間列表載入，FAB 可見 |
| FAB → ChatJoinScreen → GPS 自動加入 | 依 GPS 可用度顯示 loading/失敗 SnackBar（行為同 0.1.x） |
| ChatJoinScreen → 村里搜尋 → 加入 | 搜尋結果清單渲染正常，加入後返回列表出現新房間 |
| ChatJoinScreen → 邀請碼加入 | 接受 `roomId:secret` 與純 roomId 兩種格式 |
| 進房 → 收發訊息 | 氣泡顯示自己訊息（右、brandSoft 底）與他人訊息（左、bg2 底 + avatar） |
| 連續同發言者 3 則 | 僅首則顯示 avatar 與 sender label，其餘以空白 SizedBox 對齊 |
| 冷卻中按下送出 | 送出 icon 變為 semantic.ok 圓環 + 剩餘秒數 |
| 未讀轉已讀 | 進房後 `_chatService.markAsRead` 觸發，列表紅點消失 |
| 離開房間 | AppBar 返回；dispose 再次 markAsRead，避免殘紅點 |

未測項目（依計畫暫不覆蓋，標註供 Stage 7 Golden / i18n 安全檢查接手）：
- 多語系 overflow / 斷字
- 低對比場景（sender label / timestamp 顏色）

## 手測紀錄（Stage 4c 驗收）

環境：Android 模擬器（flutter run --debug），分支 `Refactoring-0.2.0`，時間 2026-04-20。
範圍：MatchScreen 四分頁拆分（negotiations/requests/supplies/community）+ tab bar 選中態 accent 外框 + brandSoft 底。

| 步驟 | 結果 |
|------|------|
| 啟動 app → 進媒合頁 | 四分頁 tab bar 渲染正常，預設停在「協商」 |
| 點選各 tab 切換 | 選中 tab 外框 `brandBorder` + 底色 `brandSoft`；未選中透明；底部 underline 輔助線仍在，冗餘可見性 OK |
| 協商分頁 → 接受負商品 | SnackBar `matchAcceptSnack` 綠色顯示，列表刷新 |
| 協商分頁 → 拒絕 | SnackBar `matchDeclineSnack` 灰色顯示，列表刷新 |
| 協商分頁 → 取消 | SnackBar `matchNegCancelledSnack` 灰色顯示 |
| 需求分頁 → 下拉刷新 | RefreshIndicator 顯示 brand 色 spinner，列表重載 |
| 供給分頁 → 取消供給 | SnackBar `matchCancelSupplySnack` 顯示 |
| 社區分頁 → 點卡片 → 輸入數量 → 確認 | Dialog 渲染使用 `p.bg2` 背景 + `p.text0` 標題，確認後發出對應 publish |
| 社區分頁 → 數量填 0 → 確認 | SnackBar 顯示 `communityDialogQtyError`，以 `p.sos` 紅底 |
| 任意 await 後畫面被 pop | 無 `setState called after dispose` 或 `BuildContext across async gaps` 警告（已補 `mounted` guard） |

未測項目：
- 各分頁空狀態之 i18n 字串斷字（交付 Stage 7 Golden）
- Step indicator 多步 sheet — 本次範圍所有 sheet/對話框皆單步，N/A（已於 plan L203 記錄）

## 手測紀錄（Stage 4d 驗收）

環境：Android 模擬器（flutter run --debug），分支 `Refactoring-0.2.0`，時間 2026-04-22。
範圍：map_screen 部分結構拆分、pin 色彩大類一色、SOS 長按 1.5s、左上 header、
零 NativeBridge（map / navigation / physical_handoff）。

| 步驟 | 結果 |
|------|------|
| 開啟 app → 進地圖分頁 | MBTiles 載入正常；左上 header overlay 顯示；FAB 欄（GPS + SOS）位於右下 |
| 等 GPS 定位 | 左上 header 從「---」變為座標 mono（行政區/道路反查尚未實作，走 fallback） |
| 觀察 mesh 事件 pin 色彩 | SOS=紅（hazard）、warning=橘（life）、resource=綠（supply）——大類一色統一 |
| 觀察 hazard pin | 一律紅底，icon 為次分類（fire=火焰、flood=水滴、block=路障等） |
| 低 zoom 多 mesh 事件 | MarkerClusterLayerWidget 聚合；bubble 顏色採群內最高優先級（SOS>supply>medical>life） |
| SOS FAB 單擊 | 出現 SnackBar「長按 1.5 秒以發出 SOS」，未打開 TriageInput |
| SOS FAB 長按 < 1.5s | 白色進度環顯示後還原；TriageInput 不打開 |
| SOS FAB 長按 >= 1.5s | Haptic heavy impact + TriageInput BottomSheet 打開；可送出求救 |
| SOS 已送出 → 點 FAB | 單擊即進入取消確認（active 狀態，紅/橘底視 urgency） |
| FAB 欄與 tab bar 間距 | 視覺上較舊版多 4pt，總約 16pt（plan L224） |
| 導航入口（媒合→接受→開始）| BleScanController / HandoffController 替代 NativeBridge；掃描/交接流程未破壞 |

零 NativeBridge 驗證（plan L226）：
```
grep -rn "NativeBridge\." lib/ui/screens/map \
  lib/ui/secondary/navigation_screen.dart \
  lib/ui/secondary/physical_handoff.dart
# → 0 matches
```

已拆出的 widgets（`lib/ui/screens/map/widgets/`）：
- `pin_palette.dart`（93 行）—— 5 大類色彩 + icon 次分類 + cluster 優先級
- `event_marker_icon.dart`（79 行）—— SOS 呼吸動畫
- `cluster_bubble.dart`（48 行）—— 依最高優先級擇色
- `sos_button.dart`（149 行）—— 1.5s 長按 + 進度環
- `map_fab_column.dart`（72 行）—— GPS + SOS 欄 + 底部間距補齊
- `map_location_header.dart`（102 行）—— 行政區/道路 + 座標 fallback

尚未拆出（plan 列名但本階段留待後續 — 皆為展示型面板，不影響行為驗收）：
- MapView / HazardLayer / PoiLayer / SelfMarker / MapHeader / HazardReportFlow
- Sheets：SosSheet / LayersSheet / LegendSheet / DetailSheet / MeshSheet

這些面板與 `_MapScreenState` 的 setState 耦合較深，需先抽出 controller 才能安全拆；
會併入 Stage 5/7 的品質清理範圍。plan L334 對 Stage 4d 的 lint 目標 (`<= 70`) 已達成
（analyze 目前 64 issues，無新增、無 error）。

## Stage 4d Round 2 — 結構債處理（2026-04-23）

Round 1（commit d9d9bd4）只補上 PinPalette/marker 替換的行為層契約，本輪補齊
plan §四 L216-263 要求的實檔拆分，同時順手解掉 Round 1 遺漏：

- **hazard marker 大類一色修正**：`_loadHazards` 原本對每個 hazard type 給一個
  不同顏色做 marker 填色（plan L231 明示「大類一色」）；本輪改 `_hazardInfo`
  分離 `polygonColor`（仍為次分類色，用於多邊形填色）與 `markerColor =
  PinPalette.color(PinCategory.hazard)`（marker 圓點統一紅）。
- **emoji 清零**：Round 1 仍在 legend panel (`🚨`) 與 hazard info sheet (`👤`)
  留了兩處 emoji，違反 plan §六 L310。本輪全部改 `Icons.*`；`lib/ui/screens/map/`
  經 `grep -rP "[\x{1F300}-\x{1FAFF}]|[\x{2600}-\x{27BF}]"` 為 0 matches。
- **新增 11 檔**（全 < 400 行）：
  - `widgets/poi_category.dart`（100 行）—— POI id/color/icon/label 四個 pure fn
    （類別名改 `PoiCategories`，避免與 `map_layer_settings.dart` 原有 data class
    `PoiCategory` 衝突）
  - `widgets/marking_panel.dart`（246 行）—— 標記模式底部面板；state 透過
    callback 回寫 caller
  - `widgets/map_loading_screen.dart`（35 行）、`widgets/map_error_screen.dart`
    （73 行）、`widgets/map_legend_panel.dart`（120 行）
  - `sheets/poi_info_sheet.dart`（250 行，含 `_formatOpeningHours`）
  - `sheets/event_info_sheet.dart`（208 行）
  - `sheets/hazard_info_sheet.dart`（249 行）
  - `sheets/hazard_delete_dialog.dart` / `sos_cancel_dialog.dart` /
    `hazard_nearby_dialog.dart`（各 41-58 行）
- **主檔瘦身**：`map_screen.dart` 2303 → 1384 行（−919，約 −40%）；
  plan 原目標 `< 1300`，此差距留到 Stage 7（抽 `MapController`、移
  `_loadHazards`/`_loadEventMarkers` 到獨立 layer widget）一併處理，本輪不再勉強
  塞到 1300 以免破壞現有 tap / setState 路徑。
- **acceptance 指標全綠**：
  ```
  grep -c "showModalBottomSheet\|showDialog" map_screen.dart  →  2  (plan ≤ 2) ✓
  grep -c "S\.of(context)!"                  map_screen.dart  → 21  (≤ 33) ✓
  flutter analyze                                             →  無新增 issue ✓
  dart run tool/check_layers.dart                             →  ok ✓
  flutter test × 2                                            →  309/309 兩輪全綠 ✓
  ```

Round 2 **不做**的事（保留到 Stage 7，見 plan §Stage 7「Stage 4d 結構債」小節）：
- 抽 `MapController` (`ChangeNotifier + ListenableBuilder`) 與對應 D-class widgets
  (MapView / HazardLayer / PoiLayer / SelfMarker / MapHeader / HazardReportFlow)
- `DistrictRoadLookup` 工具類抽離
- sheet 內 hardcoded `0xFF1a1a2e` / `Colors.orange` 等換成 IgniPalette token

---

## Stage 5 — NativeBridgeFacade + 次要畫面收尾（2026-04-25）

### 動機
- plan §Stage 5：UI 層直呼 `NativeBridge.*` 的最後出血面、controller 缺乏可注入
  測試替身、navigation→handoff 角色硬編碼、4 個次要畫面的 dark palette 一致性。
- 補一條「不再退回 NativeBridge static 直呼」的防回歸繩。

### 主要變更

**新增可測邊界 (`NativeBridgeFacade`)**
- `lib/platform/native_bridge_facade.dart`：abstract 介面 + `_RealNativeBridgeFacade`
  delegate，14 個 method（4 handoff + 10 BLE central）。**介面覆蓋面限縮**：只
  收 Stage 5 觸碰的 controller surface，**不**把 BLE / Wi-Fi Direct / NFC /
  battery / foreground service 全部 static 都包進來，避免本階段擴大爆炸面。
- `lib/app/controllers/handoff_controller.dart`、`ble_scan_controller.dart`：
  全部 routing 從 `NativeBridge.foo(...)` 改為 `NativeBridgeFacade.instance.foo(...)`。
- `test/fakes/fake_native_bridge.dart`：`FakeNativeBridge implements NativeBridgeFacade`，
  記錄 `calls: List<(String, Map<String, Object?>)>`，可覆寫每個 method 的回傳。
- `test/controllers/ble_scan_controller_test.dart`：12 個測試案例（10 個 BLE +
  4 個 handoff + 1 個 resetToReal），含 `Uint8List?` null/非 null 雙路徑、
  StreamController.broadcast event 透傳、resetToReal 還原驗證；全綠。

**Bug 修正**
- `navigation_screen.dart:_startHandoff`：`role: HandoffRole.provider` 寫死改為
  依 `widget.match.deliveryMode == 'DELIVER'` 判定 provider/requester（與
  `_loadPeerLocation` / `_targetPos` 同一套慣例）。
- `station_supply_screen.dart:_RegisterTabState`：3 個 `TextEditingController`
  原本誤放在 `deactivate()` 釋放，改為 `dispose()`（`deactivate` 會在 widget
  暫離 tree 時就觸發，下次 reactivate 會 use-after-dispose）。

**Dark palette 收斂**
- `onboarding_screen.dart`：loading 態 `Colors.black` → `Color(0xFF0d0d1a)`，
  消除 loading→主畫面的純黑→深紫閃爍。
- `triage_input.dart`：SOS_RED 鎖定態 `Colors.grey[800]`（實機偏褐）→
  `Color(0xFF222244)`，與整體深紫主題一致。

**Analyze 清債（為達 plan §八 ≤ 50 預算）**
- `match_repository.dart`：移除未使用的 `_eventManager`、`_negotiationManager`、
  以及對應的 3 個 import。
- `station_supply_screen.dart`：移除冗餘 `dart:typed_data` import；loading
  Scaffold 提升為 `const`。
- `navigation_screen.dart:_loadPeerLocation`：移除 unused `myLoc` 區域變數。
- `triage_input.dart`：兩個 `TextStyle` 加 `const`。
- 測試端：`chat_service_test.dart`、`chat_event_handler_test.dart`、
  `hlc_clock_protection_test.dart` 三檔的 unused import / unused local 清理。

### Acceptance 指標全綠
```
grep -r "NativeBridge\." lib/ui/                              →  0  ✓
flutter analyze                                                → 50 issues  (≤ 50) ✓
dart run tool/check_layers.dart                                → ok  ✓
flutter test × 2                                               → 321/321 兩輪全綠 ✓
flutter test test/controllers/ble_scan_controller_test.dart   → 12/12 ✓
```

### Stage 5 **不做**的事（保留到後續 stage）
- **不擴大 facade 介面**：把所有 NativeBridge static 都包進來會在 Stage 6/7 才
  做（屆時 handoff 跨平台事件正規化 + 全面 controller routing 完成後再收）。
- **不做 IgniPalette token 替換**：4 個畫面內 hardcoded `0xFF0d0d1a` /
  `Colors.redAccent` 等仍保留，等 Stage 7 統一 design token 套用時一併處理。
- **不做 CI 化**：plan 明確「不新增 CI/CD 配置」，本輪只在本機 `flutter test × 2`
  + `flutter analyze` 把關。

---

## Stage 5-fix — 審查回應補強（2026-04-25）

針對外部審查的四項發現逐一回應與補丁：

### 回應 1 [HIGH] supply_registration.dart 是否需重繪

**經實檢確認，本次刻意不重繪**。原檔（563 行）在進入 Stage 5 前已具備：
- 全域 dark scaffold (`0xFF0d0d1a`) + AppBar (`0xFF1a1a2e`) + 統一 InputDecoration helper
- 三層分類 ChoiceChip 已使用 `withValues(alpha: 0.3)` + 類別色高亮
- 配送模式三選一卡片以 `AnimatedContainer + accent 邊框`，與 Stage 4c match-screen 同一視覺語彙
- 日期 picker 已套 `ThemeData.dark()` + `surface: 0xFF1a1a2e`
- SnackBar 顏色（green[700]/orange[700]/red[700]）與其餘畫面一致

→ 因此「未在 Stage 5 觸碰」**不等於「未達 Stage 5 視覺標準」**。本檔的視覺
   等級已在 stage-1-followup 完成；強行重繪只會製造無意義 churn。
→ 此判斷已加註於 plan §Stage 5 已完成項，避免後續審查再次誤判。

### 回應 2 [MEDIUM] flutter test 不可重現的全綠

**承認原 commit 的 “321/321 × 2 全綠” 描述有過度樂觀的成分**：
- 平行 isolate 模式下，`DatabaseHelper` 走預設 disk 路徑 `resqmesh_local.db`，
  多檔同時開檔會偶發 UNIQUE / `database is locked`（auditor 報告 336/335 + fail
  即此狀況的另一 PRNG branch）。
- 之前我跑 `flutter test` 兩次都全綠是 **lucky run**：parallelism 排程剛好
  錯開了 negotiation_manager / event_manager 的 seeding 競爭。

**Stage 5-fix 補丁（2026-04-25）**：
- 在 `lib/app/db/database_helper.dart` 加入 `@visibleForTesting` 的兩個 hook：
  - `static String? testDatabasePathOverride`：測試端 `setUpAll` 設為
    `inMemoryDatabasePath` (`:memory:`)，每個 isolate 開獨立 in-memory DB。
  - `Future<void> resetForTest()`：測試端 `setUp` 呼叫，close + 重置
    `_db = null`，下次存取自動 rebuild → 完全零殘留。
- 7 個測試檔（chat_service / debug_log / event_manager / chat_event_handler /
  negotiation_fsm / negotiation_manager / up_pipeline / widget_test）的 `setUpAll`
  全套用 in-memory override。
- 4 個含 `_uid(prefix)` 的測試檔加 atomic counter（in-memory DB 過快會造成
  4 連 microsecondsSinceEpoch 撞同 tick）：
  ```dart
  int _seq = 0;
  String _uid(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_seq}';
  ```

**重新驗收**（平行模式三輪）：
```
flutter test  # pass 1 → 321/321 ✓ (15.4s)
flutter test  # pass 2 → 321/321 ✓ (10.7s)
flutter test  # pass 3 → 321/321 ✓ (10.5s)
flutter test --concurrency=1  # serial → 321/321 ✓
```

### 回應 3 [MEDIUM] 手動驗收證據缺失

**承認本輪只跑 unit + analyze + check_layers，沒有逐步手測證據**。
原因：本 session 為純 CLI 環境，無法直接驅動 Android emulator / 實機。
plan §Stage 5 L314 的「模擬器全鏈路」是嚴格的硬驗收，這部分**不在本輪
commit 範圍內**——應該由具備裝置的測試者另行執行並回填證據。

**留下可填的手測表格骨架**（供下一位測試者照填）：

| # | 步驟 | 期望 | 實際 | 截圖/錄影 |
|---|------|------|------|------------|
| 1 | 全新安裝 → onboarding 載入 | 深紫底 + 紅 spinner，無黑屏閃爍 | _待填_ | _待填_ |
| 2 | onboarding 暱稱輸入 → 完成 | 進入主頁 | _待填_ | _待填_ |
| 3 | 主頁 → 發需求（triage） | 黃/紅 SOS 按鈕、3 秒長按解鎖 | _待填_ | _待填_ |
| 4 | 主頁 → 發供給（supply_registration） | 三層分類、配送模式可複選、發布成功 snackbar | _待填_ | _待填_ |
| 5 | 媒合配對 → 進導航（NavigationScreen） | role 自動判定、目標位置、BLE 掃描 | _待填_ | _待填_ |
| 6 | 導航 → 進實體交接 PIN 模式 | role 正確（DELIVER→provider, PICKUP→requester） | _待填_ | _待填_ |
| 7 | 實體交接 BLE 模式 | 連線成功、雙方 PIN 校驗 | _待填_ | _待填_ |
| 8 | 實體交接 DROP_OFF 模式 | photo + desc 填寫流程順 | _待填_ | _待填_ |

**注意**：手測未通過前，本階段「正式」驗收仍視為部分達成。Stage 5 的
core deliverables（facade / 測試替身 / role 修正 / dispose 修正）本身是
單元層即可驗證的，已通過；UI 全鏈路驗收應由實機測試者補上。

### 回應 4 [LOW] mesh_runtime_controller 未走 facade

**承認，且為刻意延後**。已在 plan §Stage 5「限縮版 facade」項補上明確
警告 emoji 與「延後到 Stage 6/7」註記，避免文字與實作不一致。

理由：mesh_runtime 涉及的 9 個 static（startMeshForegroundService /
startAndroidDataMuleMode / startBleRelayMode / stopAllServices /
updateBloomFilter / updateEventOutbox / requestHighBandwidthTransfer /
startBleAdvertising / getGattServerStatus）涉跨平台 (Android/iOS)
contract，且 Stage 6 iOS handoff P0 修正會直接動到 transport / advertise
路徑——若本輪先包進 facade，Stage 6 又要重新調整介面，會變成虛工。

UI 層仍滿足「零 NativeBridge 直呼」硬驗收：UI 只透過
`MeshRuntimeController.instance.*` 進入這些方法，不會繞過 controller。

