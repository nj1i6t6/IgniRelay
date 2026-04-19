import 'package:flutter/material.dart';

/// 烽傳 Ignirelay 非顏色類設計 token：間距、圓角、陰影、動畫曲線。
/// 顏色請見 [IgniPalette]；字體請見 [IgniTypography]。
class IgniSpacing {
  const IgniSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xl2 = 24.0;
  static const double xl3 = 32.0;

  /// 頂部 safe-area 之外的畫面標題區上緣距離（模擬 React 原型的 100px 頂部）。
  static const double screenTitleTop = 60.0;

  /// 底部 tab bar 高度（含 safe area 預估 24pt）。
  static const double bottomTabBarHeight = 72.0;
}

class IgniRadii {
  const IgniRadii._();

  static const Radius xs = Radius.circular(6);
  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(14);
  static const Radius xl = Radius.circular(18);
  static const Radius pill = Radius.circular(100);
}

class IgniShadows {
  const IgniShadows._();

  /// 卡片輕量陰影（深色底）。
  static List<BoxShadow> card(Color shadow1) => [
        BoxShadow(color: shadow1, blurRadius: 8, offset: const Offset(0, 2)),
      ];

  /// 浮動元件/Sheet 陰影。
  static List<BoxShadow> floating(Color shadow2) => [
        BoxShadow(color: shadow2, blurRadius: 24, offset: const Offset(0, 8)),
      ];

  /// brand 色系按鈕陰影（primary cta）。
  static List<BoxShadow> brandGlow(Color brand) => [
        BoxShadow(
          color: brand.withValues(alpha: 0.35),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

class IgniMotion {
  const IgniMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 400);

  /// 對應原型 cubic-bezier(0.2, 0.7, 0.3, 1)。
  static const Curve standard = Cubic(0.2, 0.7, 0.3, 1.0);
}
