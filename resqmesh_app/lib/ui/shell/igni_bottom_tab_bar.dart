import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

/// 烽傳 Ignirelay 底部 4 分頁 tab bar。
///
/// 對應原型 App.jsx.TabBar：glass 模糊背景 + 圖示 + badge + active 高亮到 accent。
class IgniBottomTabBar extends StatelessWidget {
  const IgniBottomTabBar({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<IgniTabItem> items;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            IgniSpacing.sm,
            IgniSpacing.sm,
            IgniSpacing.sm,
            bottomInset + IgniSpacing.md,
          ),
          decoration: BoxDecoration(
            color: p.bgGlass,
            border: Border(top: BorderSide(color: p.border0)),
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == activeIndex;
              return Expanded(
                child: _TabButton(
                  item: items[i],
                  active: active,
                  onTap: () => onChanged(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class IgniTabItem {
  const IgniTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badge;
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final IgniTabItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final color = active ? p.brand : p.text2;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(IgniRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: IgniSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  active ? item.activeIcon : item.icon,
                  size: 24,
                  color: color,
                ),
                if (item.badge > 0)
                  Positioned(
                    top: -3,
                    right: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.sos,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(16)),
                        border: Border.all(color: p.bg0, width: 2),
                      ),
                      child: Text(
                        item.badge > 99 ? '99+' : '${item.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: IgniTypography.labelSmall(color).copyWith(
                fontSize: 10.5,
                letterSpacing: 0.4,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
