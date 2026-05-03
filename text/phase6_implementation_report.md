# Phase 6 Implementation Report: Chat Room Name i18n

Date: 2026-05-03 (revised)

Implementer: Kilo Agent

Plan reference: `text/map_performance_i18n_refactor_plan_2026-04-30.md` §10

---

## Summary

Phase 6 implemented across **4 git commits**. All chat room screens now display localized names based on UI locale. `Chat_Rooms.room_name` is used only as fallback for custom rooms.

---

## Commit 1: `17138d1` — Admin Names JSON Asset + Build Tool

### Files

| File | Action |
| --- | --- |
| `tool/build_admin_names_json.dart` | Created |
| `tool/data/admin_names_en.csv` | Created |
| `assets/geodata/taiwan_admin_names.json` | Created |

### Design

The build tool reads English names from `tool/data/admin_names_en.csv` (external data file, not hardcoded in Dart) and cross-references with `village_boundary.db` for Chinese names and code validation. A `manualOverrides` map exists for gaps but is currently empty — all 22 counties and 368 towns are covered by the CSV.

**Data sources** (documented in tool header):
- 內政部戶政司「行政區域代碼」 (https://www.ris.gov.tw/app/portal/346), data date 2025-01
- 交通部觀光署「臺灣地區地名資料_行政區域類」 for cross-check

`pubspec.yaml` already includes `assets/geodata/` — no change needed.

---

## Commit 2: `f85cb12` — VillageGeofence.queryByCode() + Test

### Files

| File | Action |
| --- | --- |
| `lib/app/geo/village_geofence.dart` | Modified — added `queryByCode()` |
| `test/village_geofence_query_by_code_test.dart` | Created |

### Design

- `villcode` is PRIMARY KEY → already indexed, no additional index needed
- DB remains `readOnly` — no runtime `CREATE INDEX`
- Returns `VillageInfo` or `null`

### Tests (3)

- Existing villcode returns correct data
- Nonexistent villcode returns null
- Second village data correct

---

## Commit 3: `5cb91f8` — AdminNameResolver + RoomDisplayNameResolver

### Files

| File | Action |
| --- | --- |
| `lib/app/geo/admin_name_resolver.dart` | Created |
| `lib/app/services/room_display_name_resolver.dart` | Created |
| `test/admin_name_resolver_test.dart` | Created |
| `test/room_display_name_resolver_test.dart` | Created |

### AdminNameResolver

- `ensureLoaded()` — async, loads JSON once, subsequent calls no-op
- `county(code)` / `town(code)` — sync Map lookup after cache loaded
- `debugSetData()` — test injection

### RoomDisplayNameResolver

**Fallback behavior** (revised per review): When admin lookup misses, returns **locale-aware generic strings**, not DB `room_name`. This prevents English UI from displaying stale Chinese DB data.

| roomType | zh (data available) | zh (missing data) | en (data available) | en (missing data) |
| --- | --- | --- | --- | --- |
| nation | 全國公告 | — | National Announcements | — |
| county | {countyZh} 公告 | 縣市公告 | {countyEn} Announcements | County Announcements |
| township | {countyZh}{townZh} 公告 | 鄉鎮區公告 | {countyEn} {townEn} Announcements | Township Announcements |
| village | {countyZh}{townZh}{villZh} 聊天室 | 村里聊天室 | {countyEn} {townEn} {vill} Chat | Village Chat |
| custom | fallbackRoomName | — | fallbackRoomName | — |

**villeng suffix**: DB audit shows 7,768 of 7,974 rows have non-empty `villeng`; all 7,768 end with `Vil.` (uniform). 206 rows have empty/null `villeng`. Stripping is safe and produces cleaner display (`Xisheng` vs `Xisheng Vil.`).

### Tests (21 total)

- AdminNameResolver: 5 tests
- RoomDisplayNameResolver: 16 tests (all 5 room types × zh/en + unknown code generic fallback)

---

## Commit 4: `44b6231` — Chat Screens + l10n

### Files

| File | Action |
| --- | --- |
| `lib/ui/screens/chat/chat_list_screen.dart` | Modified |
| `lib/ui/screens/chat/chat_room_screen.dart` | Modified |
| `lib/ui/screens/chat/chat_join_screen.dart` | Modified |

### ChatListScreen

1. **No flicker**: `_loadRooms()` does `await AdminNameResolver().ensureLoaded()` → `await Future.wait(resolves)` → single `setState`.
2. **Locale change**: `didChangeDependencies()` detects locale changes, re-runs `_loadRooms()`.
3. **Parallel queries**: unread + lastMessage fetched via `Future.wait` (not sequential).

### ChatRoomScreen

1. AppBar shows `_displayRoomName ?? widget.roomName`.
2. `didChangeDependencies()` detects locale change, calls `_resolveDisplayName()`.

### ChatJoinScreen

1. SQL search includes `OR villeng LIKE ?`.
2. Uses shared `RoomDisplayNameResolver` (not separate `_villageDisplayEnglish()`).
3. `AdminNameResolver().ensureLoaded()` called before search.
4. `_formatVillageNameEnglish()` for search result display uses same logic as resolver.

### L10n keys

ARB keys were **not added** — the resolver constructs strings directly. Adding unused ARB keys would create maintenance confusion. If l10n template interpolation is needed in the future, keys can be added at that time.

---

## Verification

### flutter analyze

- 0 errors, 0 warnings

### flutter test

- **413 passed**, 3 skipped, 1 failed
- The 1 failure is pre-existing: `EventType enum Bug 1 regression values list contains all 19 entries` in `test/proto/event_type_enum_test.dart` — unrelated to Phase 6.

### Git log

```
44b6231 i18n(chat): Phase 6 Commit 4 — 聊天室名稱多語 (chat screens + l10n)
5cb91f8 feat(chat): Phase 6 Commit 3 — AdminNameResolver + RoomDisplayNameResolver
f85cb12 feat(geo): Phase 6 Commit 2 — VillageGeofence.queryByCode() + test
17138d1 feat(geo): Phase 6 Commit 1 — 行政區名 JSON asset + build tool
```

---

## Changes from Initial Implementation (Review Feedback)

| Item | Before | After |
| --- | --- | --- |
| Resolver fallback | Returns DB `fallbackRoomName` (may be Chinese) | Returns locale-aware generic strings |
| Build tool data | Hardcoded 368-entry Dart map | Reads from `tool/data/admin_names_en.csv` |
| Build tool safety | WARNING + continue on missing data | Fail-fast: exit(2) if not 22 counties / 368 towns |
| ChatJoinScreen | Separate `_villageDisplayEnglish()` | Delegates to `RoomDisplayNameResolver.formatVillageEnglish()` (shared static) |
| ChatJoinScreen | No `ensureLoaded()` guarantee | `await AdminNameResolver().ensureLoaded()` before search |
| ARB keys | 7 unused keys added | Removed (resolver hardcodes strings) |
| ChatListScreen | Sequential unread/lastMessage | `Future.wait` parallel |
| Git commits | None (working tree only) | 4 actual commits per plan §10.1 |
| Report | Untracked | Committed as docs commit |

---

## Known Limitations

1. **CSV provenance**: `admin_names_en.csv` is a curated seed dataset. Initial version was derived from 內政部戶政司 administrative area code tables cross-referenced with `village_boundary.db` Chinese names. It covers all 22 counties and 368 townships/districts as of 2025-01. The build tool now fail-exits if county count ≠ 22 or town count < 368, preventing partial JSON output. To update from official sources: download latest 行政區域代碼 CSV from 內政部戶政司, cross-reference with `village_boundary.db`, update `tool/data/admin_names_en.csv`, re-run build tool.
2. **villeng strip**: Only strips `Vil.` suffix (7,768/7,768 non-empty entries match this pattern). If future DB updates introduce different suffixes, the regex in `RoomDisplayNameResolver.formatVillageEnglish()` should be updated.
3. **Custom room names**: Not localized (by design — plan §1.4.5).
