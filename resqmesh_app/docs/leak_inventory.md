# 集合洩漏盤點 — Refactoring 0.2.0 Stage 4b

本文件為 0.2.0 重構在 Stage 4b 產出的審查成果，列出 `lib/` 下長壽命單例/
static 物件持有的 `Set<>` / `Map<>` / `List<>` 可能無邊界成長的風險位置，
作為 Stage 4d ~ 6 修補方向的依據。Stage 4b 本身不動這些檔案。

判別原則：
- 只列「單例/全域 state」或「長壽命 Controller 欄位」上的集合。
- method-local 的集合或由 RAII/生命週期自動清除者不列入。
- 盤點來源為 Stage 4b 起點 commit，若後續 Stage 發現新成員再追補。

## 已確認 leak（需處置）

| ID | 位置 | 描述 | 建議處置 | 預計階段 |
|----|------|------|----------|----------|
| L1 | `lib/platform/ble_manager.dart:63` `uniquePeersEverSeen` | 保存所有時間看過的 peer id，重啟前不會清。 | 改為有界 LRU（上限 500）或 N 小時 TTL。 | Stage 6 |
| L2 | `lib/platform/ble_manager.dart:46` `_cancelledSyncs` | 記錄已取消的同步 session id，只寫不讀移除。 | 改 LRU(200) 或同步完成/過期時清。 | Stage 6 |
| L3 | `lib/app/services/chat_service.dart:26` `_lastSendTime` | 記錄每個 roomId 上次送出時間，roomId 離開未清。 | markAsRead / leaveRoom 時同步 remove；否則 LRU(64)。 | Stage 4b+ / Stage 5 |

## 已確認非 leak（保留於此，避免再被誤列）

| 位置 | 原因 |
|------|------|
| `lib/app/repositories/match_repository.dart:286` `seenIds` | method-local，單次掃描結束即 GC。 |
| `lib/app/mesh/mesh_event_handler.dart:67` `_seenEvents` | 已有 `_maxSeenEvents = 10000` LRU 保護，不會無界成長。 |
| `lib/app/mesh/mesh_event_handler.dart:80` `debugLogs` | 已有 `_maxDebugLogs = 80` cap。 |

## 後續動作

- Stage 4b：本文件落地，不改碼。
- Stage 4d/5：排入 chat_service `_lastSendTime` 清理。
- Stage 6：在 transport TTL/清理 PR 內一併處理 L1/L2。
