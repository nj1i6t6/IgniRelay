import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

enum IgniChipTone { neutral, brand, sos, warn, ok, info }

/// 小圓角狀態標籤（對應原型 .chip / 信任徽章 / tier pill）。
///
/// - [tone] 決定背景/邊框/文字顏色。
/// - [mono] = true 使用 mono 字體（適合 L0/L1/BUILD-28 這類標籤）。
class IgniChip extends StatelessWidget {
  const IgniChip({
    super.key,
    required this.label,
    this.tone = IgniChipTone.neutral,
    this.icon,
    this.mono = false,
    this.onTap,
  });

  final String label;
  final IgniChipTone tone;
  final IconData? icon;
  final bool mono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;

    final (bg, fg, border) = switch (tone) {
      IgniChipTone.neutral => (p.bg2, p.text1, p.border1),
      IgniChipTone.brand => (p.brandSoft, p.brand, p.brandBorder),
      IgniChipTone.sos => (p.sosSoft, p.sos, p.sos.withValues(alpha: 0.35)),
      IgniChipTone.warn => (p.warnSoft, p.warn, p.warn.withValues(alpha: 0.35)),
      IgniChipTone.ok => (p.okSoft, p.ok, p.ok.withValues(alpha: 0.35)),
      IgniChipTone.info => (p.infoSoft, p.info, p.info.withValues(alpha: 0.35)),
    };

    final textStyle = (mono
            ? IgniTypography.monoSmall(fg)
            : IgniTypography.labelSmall(fg))
        .copyWith(letterSpacing: mono ? 0.8 : 0.4);

    final inner = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IgniSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: const BorderRadius.all(IgniRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 6),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );

    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(IgniRadii.pill),
        child: inner,
      ),
    );
  }
}
