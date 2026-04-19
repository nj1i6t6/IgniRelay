import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

/// 玻璃風 bottom sheet 容器 + 顯示工具（對應 React 原型 `BottomSheet`）。
///
/// 用法：
/// ```dart
/// SlideUpSheet.show(context: context, builder: (_) => MyContent());
/// ```
///
/// 提供：drag handle、標題列（可選）、max 0.9 height、玻璃底、slide-up 動畫。
class SlideUpSheet extends StatelessWidget {
  const SlideUpSheet({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.trailing,
    this.showDragHandle = true,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final bool showDragHandle;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    Widget? leading,
    Widget? trailing,
    bool showDragHandle = true,
    bool isScrollControlled = true,
    bool useSafeArea = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => SlideUpSheet(
        title: title,
        leading: leading,
        trailing: trailing,
        showDragHandle: showDragHandle,
        child: builder(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: IgniRadii.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: p.bgGlass,
            border: Border(top: BorderSide(color: p.border1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDragHandle)
                Padding(
                  padding: const EdgeInsets.only(top: IgniSpacing.sm),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (title != null || leading != null || trailing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    IgniSpacing.lg,
                    IgniSpacing.md,
                    IgniSpacing.lg,
                    IgniSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: IgniSpacing.md),
                      ],
                      Expanded(
                        child: Text(
                          title ?? '',
                          style: IgniTypography.titleMedium(p.text0),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              Flexible(child: child),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
