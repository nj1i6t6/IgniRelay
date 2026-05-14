import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

/// Stage 2A 拆分：MatchScreen 內的 tab strip + floating action buttons。
/// 純展示 widget；data 由 MatchScreen 計算後傳入。

class MatchTabMeta {
  const MatchTabMeta(this.label, this.icon, this.count, {this.highlight = false});
  final String label;
  final IconData icon;
  final int count;
  final bool highlight;
}

class MatchTabStrip extends StatefulWidget {
  const MatchTabStrip({super.key, required this.controller, required this.items});
  final TabController controller;
  final List<MatchTabMeta> items;

  @override
  State<MatchTabStrip> createState() => _MatchTabStripState();
}

class _MatchTabStripState extends State<MatchTabStrip> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final idx = widget.controller.index;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.lg, vertical: 4),
      child: Row(
        children: List.generate(widget.items.length, (i) {
          final t = widget.items[i];
          final active = idx == i;
          final pillBg = t.highlight ? p.sos : (active ? p.brandSoft : p.bg2);
          final pillFg = t.highlight ? Colors.white : (active ? p.brand : p.text2);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              child: InkWell(
                onTap: () => widget.controller.animateTo(i),
                borderRadius: const BorderRadius.all(IgniRadii.sm),
                child: Container(
                  decoration: BoxDecoration(
                    color: active ? p.brandSoft : Colors.transparent,
                    borderRadius: const BorderRadius.all(IgniRadii.sm),
                    border: Border.all(
                      color: active ? p.brandBorder : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                t.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                                  color: active ? p.text0 : p.text2,
                                ),
                              ),
                            ),
                            if (t.count > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: pillBg,
                                  borderRadius: const BorderRadius.all(IgniRadii.xs),
                                ),
                                child: Text(
                                  '${t.count}',
                                  style: IgniTypography.monoSmall(pillFg).copyWith(fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (active)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: -5,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: p.brand,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class MatchBrandFab extends StatelessWidget {
  const MatchBrandFab({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(IgniRadii.pill),
          boxShadow: IgniShadows.brandGlow(color),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(IgniRadii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MatchOutlineFab extends StatelessWidget {
  const MatchOutlineFab({
    super.key,
    required this.color,
    required this.bg,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Color color;
  final Color bg;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(IgniRadii.pill),
          border: Border.all(color: color, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(IgniRadii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
