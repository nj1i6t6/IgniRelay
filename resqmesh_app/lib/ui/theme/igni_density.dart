import 'package:flutter/material.dart';

/// UI 密度（計畫 Stage 4a 交付項：舒適 / 標準 / 緊湊）。
///
/// 對映 Flutter [VisualDensity]：
/// - [comfortable] → `VisualDensity.comfortable`（+2 橫、+2 縱；Material 上限）
/// - [standard]    → `VisualDensity.standard`（0, 0；Material 預設）
/// - [compact]     → `VisualDensity.compact`（-2 橫、-2 縱；Material 下限）
///
/// 序列化至 `SharedPreferences('app_density')`。
enum IgniDensity {
  comfortable,
  standard,
  compact;

  String get storageKey => name;

  String get label {
    switch (this) {
      case IgniDensity.comfortable:
        return '舒適';
      case IgniDensity.standard:
        return '標準';
      case IgniDensity.compact:
        return '緊湊';
    }
  }

  VisualDensity get visualDensity {
    switch (this) {
      case IgniDensity.comfortable:
        return VisualDensity.comfortable;
      case IgniDensity.standard:
        return VisualDensity.standard;
      case IgniDensity.compact:
        return VisualDensity.compact;
    }
  }

  static IgniDensity parse(String? s) {
    switch (s) {
      case 'comfortable':
        return IgniDensity.comfortable;
      case 'compact':
        return IgniDensity.compact;
      case 'standard':
      default:
        return IgniDensity.standard;
    }
  }
}
