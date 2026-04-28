import 'package:flutter/material.dart';

/// 字體大小（取代舊的 [IgniDensity]）。
///
/// 舊的 `IgniDensity` 只把 `VisualDensity` 從 comfortable 推到 compact，差異
/// 視覺上幾乎看不出來，老人家／低視力使用者也讀不清楚。改成「字體大小」
/// （Text scale）對 a11y 與實際可讀性更直接。
///
/// 透過在 `MaterialApp.builder` 包一層 [MediaQuery]，覆寫
/// [MediaQueryData.textScaler]，讓所有 `Text`／`TextSpan`／系統 widget 一起放大。
///
/// 規格：
///   - [standard] : 1.00（系統預設）
///   - [large]    : 1.15（建議：眼力略弱者）
///   - [xLarge]   : 1.30（建議：年長者）
///   - [huge]     : 1.45（最大；超出此值很多 layout 會擠爆）
///
/// 序列化至 `SharedPreferences('app_text_scale')`。
enum IgniTextScale {
  standard,
  large,
  xLarge,
  huge;

  String get storageKey => name;

  double get factor {
    switch (this) {
      case IgniTextScale.standard:
        return 1.00;
      case IgniTextScale.large:
        return 1.15;
      case IgniTextScale.xLarge:
        return 1.30;
      case IgniTextScale.huge:
        return 1.45;
    }
  }

  TextScaler get scaler => TextScaler.linear(factor);

  static IgniTextScale parse(String? s) {
    switch (s) {
      case 'large':
        return IgniTextScale.large;
      case 'xLarge':
        return IgniTextScale.xLarge;
      case 'huge':
        return IgniTextScale.huge;
      case 'standard':
      default:
        return IgniTextScale.standard;
    }
  }
}
