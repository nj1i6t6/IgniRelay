import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

/// 子頁標題列：圓形返回鈕 + 標題 + 次標題。
///
/// 對應原型 SubPageHeader，抽成共用避免每個子頁重寫一次。
class IgniSubPageHeader extends StatelessWidget {
  const IgniSubPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final effectiveOnBack =
        onBack ?? (Navigator.of(context).canPop() ? Navigator.of(context).pop : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IgniSpacing.lg,
        IgniSpacing.screenTitleTop,
        IgniSpacing.lg,
        IgniSpacing.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (effectiveOnBack != null)
            Material(
              color: p.bg2,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(IgniRadii.pill),
                side: BorderSide(color: p.border0),
              ),
              child: InkWell(
                onTap: effectiveOnBack,
                borderRadius: const BorderRadius.all(IgniRadii.pill),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(Icons.arrow_back, size: 18, color: p.text0),
                ),
              ),
            ),
          if (effectiveOnBack != null) const SizedBox(width: IgniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: IgniTypography.titleLarge(p.text0)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: IgniTypography.bodySmall(p.text2)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
