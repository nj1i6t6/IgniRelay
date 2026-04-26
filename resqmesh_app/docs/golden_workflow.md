# Golden Workflow（Stage 7 鎖定）

## 範圍

`test/widgets/design_system_goldens_test.dart` 提供 **3 元件 × 3 主題 = 9
張 baseline**，固定於 `test/widgets/goldens/`：

| 元件          | scene 內含                                            |
| ------------- | ----------------------------------------------------- |
| `GlassCard`   | 單一卡片 + 標題                                       |
| `StatusChip`  | brand / sos / warn / ok / info / neutral 6 種 tone    |
| `GlassIconBtn`| default / selected / danger 3 態                      |

| 主題         | 取用                  |
| ------------ | --------------------- |
| dark         | `AppTheme.dark()`     |
| light        | `AppTheme.light()`    |
| emergency    | `AppTheme.emergency()`|

不納入動效類元件（`SlideUpSheet` / `PulseEffect` / `RippleEffect` 等），
避免不同機台 frame timing 漂移造成 maintenance burden。

## 一般驗證

```
flutter test test/widgets/design_system_goldens_test.dart
```

正常情況應 9 張全綠。

## Token 變動 → 預期 fail

任一 semantic token（如 `IgniPalette.dark.brand` 或 `bg2`）值改動 ≥ 1 LSB
應觸發 golden 比對失敗（image diff > tolerance）。例：

```
Color brand: const Color(0xFFE8803B), → const Color(0xFFE8803C),
```

跑 `flutter test test/widgets/design_system_goldens_test.dart` 將看到
類似：

```
Pixel test failed, ... image differed by ...
goldens/status_chip_dark.png
```

這是預期行為 — 證明視覺鎖定有效。

## 重新基準（接受視覺改動）

確認改動是有意的（理由通常是「換 brand 色」「Material 升版」「typography
調整」之類），執行：

```
flutter test --update-goldens test/widgets/design_system_goldens_test.dart
```

PR 描述中**必須**列出觸發更新的 token / 設計變更，方便 reviewer 對照。

## 不踩的坑

- **不要單純為了綠 CI 跑 `--update-goldens`**：這會掩蓋意外漂移。
- **不要在動效中或 `pump` 多 frame 後抓圖**：Timer / AnimationController 會
  造成不可重現的 baseline。本檔測試只 `pumpAndSettle()` 一次。
- **不要把 widget 測試放進此檔**：goldens 測試的成本高（產 png + diff），
  純邏輯測試請放回對應 module 測試。

## 平台兼容

GitHub Actions 上跑 golden 容易因 font rasterizer 差異炸掉。Stage 7 baseline
固定於開發機（Windows + Flutter SDK 對應 `pubspec.lock`）；CI 暫不啟動
golden gate。實機 release 前由維護者手動跑一次 `flutter test` 確認。
