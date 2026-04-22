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
