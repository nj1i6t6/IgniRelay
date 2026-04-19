import 'package:flutter/material.dart';

/// 烽傳 Ignirelay 字體系統。
///
/// - sans：UI 預設，採用系統繁中字體堆疊（PingFang TC / Microsoft JhengHei / Noto Sans TC）。
/// - mono：技術字串（pubkey、RSSI、build no.、PIN 碼）使用。
///
/// 字體檔案不打包進 app（避免體積膨脹），走 fallback 字體堆疊。
/// 若日後要確保跨裝置一致，可加入 Noto Sans TC ttf 並掛 asset fonts。
class IgniTypography {
  const IgniTypography._();

  static const String sansFamily = '.AppleSystemUIFont';
  static const List<String> sansFallback = [
    'PingFang TC',
    'Microsoft JhengHei',
    'Noto Sans TC',
    'Roboto',
    'sans-serif',
  ];

  static const String monoFamily = 'monospace';
  static const List<String> monoFallback = [
    'SF Mono',
    'JetBrains Mono',
    'Menlo',
    'Consolas',
    'monospace',
  ];

  static TextStyle display(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallback,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle titleLarge(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallback,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle titleMedium(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallback,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle bodyLarge(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallback,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: color,
      );

  static TextStyle bodyMedium(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallback,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: color,
      );

  static TextStyle bodySmall(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallback,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        height: 1.55,
        color: color,
      );

  static TextStyle labelLarge(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallback,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle labelSmall(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallback,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: color,
      );

  static TextStyle sectionHeader(Color color) => TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: sansFallback,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: color,
      );

  static TextStyle monoSmall(Color color) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: monoFallback,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle monoMedium(Color color) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: monoFallback,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: color,
      );
}
