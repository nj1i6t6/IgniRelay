import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

enum IgniButtonVariant { primary, ghost, sos, warn }

enum IgniButtonSize { small, medium, large }

/// 烽傳 Ignirelay 標準按鈕。
///
/// 四種 variant 對應原型 .btn-primary / .btn-ghost / .btn-sos / .btn-warn。
/// 支援 leading icon、loading 態、full-width、size 三級。
class IgniButton extends StatelessWidget {
  const IgniButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = IgniButtonVariant.primary,
    this.size = IgniButtonSize.medium,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IgniButtonVariant variant;
  final IgniButtonSize size;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final enabled = onPressed != null && !loading;

    final (bg, fg, border) = switch (variant) {
      IgniButtonVariant.primary => (p.brand, Colors.white, Colors.transparent),
      IgniButtonVariant.sos => (p.sos, Colors.white, Colors.transparent),
      IgniButtonVariant.warn => (p.warn, Colors.black, Colors.transparent),
      IgniButtonVariant.ghost => (Colors.transparent, p.text0, p.border1),
    };

    final (h, padH, fontSize, iconSize) = switch (size) {
      IgniButtonSize.small => (36.0, IgniSpacing.md, 13.0, 16.0),
      IgniButtonSize.medium => (44.0, IgniSpacing.lg, 14.0, 18.0),
      IgniButtonSize.large => (52.0, IgniSpacing.xl, 15.0, 20.0),
    };

    Widget content;
    if (loading) {
      content = SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(fg),
        ),
      );
    } else {
      final textStyle = IgniTypography.bodyLarge(fg).copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      );
      content = Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: IgniSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: bg,
        borderRadius: const BorderRadius.all(IgniRadii.md),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: const BorderRadius.all(IgniRadii.md),
          child: Container(
            height: h,
            width: fullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: padH),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(IgniRadii.md),
              border: Border.all(color: border),
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
