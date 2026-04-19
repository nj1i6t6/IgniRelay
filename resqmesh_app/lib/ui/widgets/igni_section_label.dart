import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

/// 分段標題（如「信任等級」「設定」），對應原型 11px uppercase letter-spaced 小字。
class IgniSectionLabel extends StatelessWidget {
  const IgniSectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(
      left: IgniSpacing.xs,
      bottom: IgniSpacing.sm,
    ),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: IgniTypography.sectionHeader(p.text2),
      ),
    );
  }
}
