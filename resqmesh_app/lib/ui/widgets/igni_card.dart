import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';

/// 烽傳 Ignirelay 基礎卡片容器。
///
/// - 預設背景 bg-1、邊框 border-0、圓角 lg (14)。
/// - [elevated] = true 使用 bg-1 → bg-2 的對角漸層模擬身分卡質感，並加上微妙的右上 brand-soft 漸暈。
/// - [onTap] 有值時，整張卡會有 Ripple 效果。
class IgniCard extends StatelessWidget {
  const IgniCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(IgniSpacing.lg),
    this.margin,
    this.elevated = false,
    this.radius = IgniRadii.lg,
    this.borderColor,
    this.background,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool elevated;
  final Radius radius;
  final Color? borderColor;
  final Color? background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final br = BorderRadius.all(radius);

    final decoration = BoxDecoration(
      borderRadius: br,
      border: Border.all(color: borderColor ?? p.border0),
      gradient: elevated
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.bg1, p.bg2],
            )
          : null,
      color: elevated ? null : (background ?? p.bg1),
    );

    Widget content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (elevated) {
      content = Stack(
        children: [
          content,
          Positioned(
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 0.9,
                    colors: [p.brandSoft, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      content = ClipRRect(borderRadius: br, child: content);
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: content,
    );
  }
}
