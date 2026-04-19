import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';

/// 毛玻璃卡片容器（對應 React 原型 `GlassCard`）。
///
/// 半透明底 + blur + hairline 邊 + 卡片陰影。給浮貼於地圖/背景上的面板使用。
/// 非玻璃情境請用 `IgniCard`（實色，預設 bg1）。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(IgniSpacing.lg),
    this.margin,
    this.radius = IgniRadii.lg,
    this.accent = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Radius radius;

  /// 啟用後以 brandSoft / brandBorder 強調（選中或重要態）。
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final radiusAll = BorderRadius.all(radius);
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radiusAll,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: accent ? p.brandSoft : p.bgGlass,
              border: Border.all(
                color: accent ? p.brandBorder : p.border1,
              ),
              borderRadius: radiusAll,
              boxShadow: IgniShadows.card(p.shadow1),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
