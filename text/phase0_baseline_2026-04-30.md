# Phase 0 基線與測試規劃紀錄

日期：2026-04-30
專案位置：`C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app`
對應企畫書：`text/map_performance_i18n_refactor_plan_2026-04-30.md` §4

本文件作為地圖效能與多語系重構的 Phase 0 基線，記錄 `flutter analyze` / `flutter test` / `flutter build apk --debug` 執行結果，並把企畫書 §4.3 規劃中的測試檔安排到對應 Phase。Phase 0 不修改 runtime 行為，也不建立尚未有 source 的測試檔。

## 1. 環境

| 項目 | 值 |
| --- | --- |
| Flutter | 3.41.2 stable (revision 90673a4eef, 2026-02-18) |
| Dart | 3.11.0 |
| Engine | d96704abcce17ff165bbef9d77123407ef961017 (revision 6c0baaebf7) |
| DevTools | 2.54.1 |
| OS | Windows 11 Home 10.0.26200 |
| Git branch | `Refactoring-0.2.0` |
| Git HEAD | `8488a6c fix(stage-7-r4): 收斂 protobuf codegen 與無座標語意` |

## 2. `flutter analyze` 基線

執行：

```powershell
flutter analyze
```

結果：

```
Analyzing resqmesh_app...

   info - Use 'const' with the constructor to improve performance - test\ui\screens\map\map_screen_controller_marking_test.dart:66:22 - prefer_const_constructors

1 issue found. (ran in 33.6s)
```

| 等級 | 數量 | 說明 |
| --- | --- | --- |
| error | 0 | — |
| warning | 0 | — |
| info | 1 | `prefer_const_constructors`，位於 `test/ui/screens/map/map_screen_controller_marking_test.dart:66:22` |

判定：通過（無 error / warning）。`info` 屬既有測試風格提示，Phase 0 不修；後續 Phase 修改該測試檔時可順手處理。

## 3. `flutter test` 基線

執行：

```powershell
flutter test
```

統計：`+375 ~3 -1`。

| 結果 | 數量 |
| --- | --- |
| passed | 375 |
| skipped | 3 |
| failed | 1 |
| total | 379 |

### 3.1 失敗測試

| # | 測試檔 | 測試名稱 | 摘要 |
| --- | --- | --- | --- |
| F1 | `test/pipeline/up_pipeline_test.dart` | `Up Pipeline — Signature Verification tampered payload: rejected (sig-fail)` | 完整套件下 `Expected: <19>` / `Actual: <15>`；單獨執行 `flutter test test/pipeline/up_pipeline_test.dart` 14 個 case 全 pass。屬全套件互相干擾的計數型 expectation，疑似測試間共享 state 累積值落差。 |

### 3.2 跳過測試

3 筆 skip 來自 `test/routing_test.dart` 等，原因為需要 `VillageGeofence` geodata asset / 實機（已在 `test/TEST_INDEX.md` 標註為 integration test）。Phase 0 不解禁。

### 3.3 判定

非 Phase 1–7 範圍引入的失敗。F1 是既有 baseline failure，記錄在此作為基線；後續 Phase 重構過程中若 F1 仍然是「完整套件失敗、單檔 pass」這種模式，視為基線殘留，不需 Phase 1–6 額外處理。若 F1 行為改變（例如 Actual 數值不同、單檔也 fail），即為新引入問題，必須回退。

## 4. `flutter build apk --debug` 基線

執行：

```powershell
flutter build apk --debug
```

結果尾段：

```
Running Gradle task 'assembleDebug'...                             74.3s
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

判定：通過。debug APK 產出於 `resqmesh_app/build/app/outputs/flutter-apk/app-debug.apk`。

## 5. Phase 0 必跑指令一覽（總結）

| 指令 | 結果 | 備註 |
| --- | --- | --- |
| `flutter analyze` | 0 error / 0 warning / 1 info | info 為既有 lint，無 runtime 影響 |
| `flutter test` | 375 pass / 3 skip / 1 fail | F1 為全套件互相干擾基線失敗，單檔 pass |
| `flutter build apk --debug` | OK | `app-debug.apk` 已產出 |

## 6. 測試規劃（由 Phase 0 安排到對應 Phase）

依企畫書 §4.3 與 §11 完成標準，下列測試檔尚未存在，**Phase 0 不建立**；於對應 Phase 內先寫測試再實作。

### 6.1 規劃中的測試檔

| 測試檔 | 目前狀態 | 用途 | 安排到 Phase |
| --- | --- | --- | --- |
| `test/map_label_language_test.dart` | 未建立 | 驗證 locale 到 map label 欄位的解析規則：`zh_*` → 繁中 fallback、`en_*` → `name_en` / `name:en` 系列、MBTiles 支援的非中文語言對應 `name:<lang>`、不支援語言 fallback 英文 | Phase 4（地圖 label 多語），對應 §8.1 修改檔列表 |
| `test/admin_name_resolver_test.dart` | 未建立 | 驗證 `AdminNameResolver` 的 county / town 名稱解析：cache load、code 對應到 zhHant / en、缺資料回 null、township 必經 county code | Phase 6（聊天室名稱多語），對應 §10.1、§10.3 |
| `test/room_display_name_resolver_test.dart` | 未建立 | 驗證聊天室名稱中英文規則：`nation` / `county` / `township` / `village` / `custom` × `zh` / 非 `zh`，含缺資料的 generic fallback、room_id 解析（`TW_NATION` / `TW_<5>` / `TW_<8>` / 11 碼 villcode） | Phase 6（聊天室名稱多語），對應 §10.1、§10.5 |
| `test/ignirelay_theme_test.dart` | 未建立 | 驗證 `buildIgniRelayTheme()` 在不同 locale × brightness 下能產生 theme，且：locale 改變會改變 layer text-field、brightness 改變會切換 light / dark palette、disabledPoi 仍能過濾 POI layer | Phase 4（label 多語）建立基本 case，Phase 5（深淺色 theme）擴充 brightness case |

### 6.2 既有測試與 baseline

下列既有測試檔在後續 Phase 重構中需保持綠燈（除 §3.1 的 F1 既有 baseline 殘留）：

| 既有測試領域 | 重構期間關注點 |
| --- | --- |
| `test/ui/screens/map/map_screen_controller_marking_test.dart` | Phase 1–2 改 `setViewport` / 拆 POI notifier 時不能破壞 marking transition 同步行為 |
| `test/ui/screens/map/map_view_models_test.dart` | Phase 2 若新增 / 改 VM（POI、self、hazard、event、base map）需擴充 |
| `test/widgets/design_system_goldens_test.dart` | Phase 5 切 dark palette 時注意是否影響 GlassCard / StatusChip / GlassIconBtn golden |
| `test/widget_test.dart` | Phase 7 整合驗收前確認仍綠燈 |
| `test/pipeline/up_pipeline_test.dart` | F1 baseline 殘留：完整套件 `Expected: <19>` / `Actual: <15>`，單檔執行 pass |

## 7. Phase 0 完成標準對照

| 完成標準（§4.4） | 狀態 |
| --- | --- |
| 已記錄 analyze / test / build 基線 | 完成（§2、§3、§4） |
| 必要測試檔已規劃清楚，並安排到對應 Phase 建立 | 完成（§6） |
| 未改變 app runtime 行為 | 完成：本階段未觸碰 `lib/` 任何檔案，僅新增此 baseline 文件 |

## 8. 備註

1. `flutter analyze` 的 info 提示位於測試檔，不影響 runtime；Phase 4 / Phase 5 改 theme 時若該測試需要更動再順手處理。
2. F1 基線失敗已存在於本次重構前的 main HEAD，不視為 Phase 1+ 引入。後續 Phase 必跑時，若 F1 仍維持「完整套件 fail、單檔 pass」此一模式則視為基線殘留；若型態改變（Actual 數值不同、或單檔也 fail），即為 Phase 改動引入，必須回退或修復。
3. Phase 0 不修 lint info、不修 F1、不建尚未有 source 的測試檔，符合「未改變 runtime 行為」要求。
