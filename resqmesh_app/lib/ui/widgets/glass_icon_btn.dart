import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';

/// 毛玻璃圓形 icon 按鈕（對應 React 原型 `GlassIconButton`）。
///
/// 用於地圖 FAB 群組、次級動作按鈕。按下時 scale 0.95。
/// 未 [selected] 時：bgGlass + border1；[selected] 時：brandSoft + brandBorder。
class GlassIconBtn extends StatelessWidget {
  const GlassIconBtn({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.tooltip,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final bg = selected
        ? p.brandSoft
        : danger
            ? p.sosSoft
            : p.bgGlass;
    final border = selected
        ? p.brandBorder
        : danger
            ? p.sos.withValues(alpha: 0.5)
            : p.border1;
    final fg = selected
        ? p.brand
        : danger
            ? p.sos
            : p.text1;

    final button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(IgniRadii.md),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: border),
              borderRadius: const BorderRadius.all(IgniRadii.md),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: const BorderRadius.all(IgniRadii.md),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: fg, size: size * 0.46),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
