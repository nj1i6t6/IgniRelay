import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

/// 狀態標籤色調：brand / sos / warn / ok / info / neutral。
///
/// 與 [IgniChip] 的差異：[StatusChip] 專注於語意狀態色 + 小尺寸，常配 icon；
/// [IgniChip] 是可點選/切換的較大尺寸元件。
enum StatusTone { brand, sos, warn, ok, info, neutral }

/// 小型狀態標籤（對應 React 原型 `StatusChip`）。
///
/// 用於「廣播中」、「已驗證」、「離線」等狀態提示；盡量用 icon 降低文字噪音。
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  /// 較緊湊的版本，僅 2pt 垂直 padding。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final (bg, fg) = _colors(p);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? IgniSpacing.sm : IgniSpacing.md,
        vertical: dense ? 2 : IgniSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(IgniRadii.pill),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: IgniSpacing.xs),
          ],
          Text(
            label,
            style: IgniTypography.labelSmall(fg).copyWith(
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _colors(IgniPalette p) {
    switch (tone) {
      case StatusTone.brand:
        return (p.brandSoft, p.brand);
      case StatusTone.sos:
        return (p.sosSoft, p.sos);
      case StatusTone.warn:
        return (p.warnSoft, p.warn);
      case StatusTone.ok:
        return (p.okSoft, p.ok);
      case StatusTone.info:
        return (p.infoSoft, p.info);
      case StatusTone.neutral:
        return (p.bg2, p.text2);
    }
  }
}
