import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/widgets/igni_card.dart';

/// 「我」分頁的信任等級區段。
/// Stage 2B：由 profile_screen god file 拆出。
///
/// Stage 4a 交付項：信任等級改為圖示優先，L0-L3 文字與描述預設收合，
/// 點擊展開才顯示；升級按鈕在收合狀態仍可見以保留既有升級流程。
class ProfileTierList extends StatefulWidget {
  const ProfileTierList({
    super.key,
    required this.currentLevel,
    required this.onVerifyPhone,
  });

  final int currentLevel;
  final VoidCallback onVerifyPhone;

  @override
  State<ProfileTierList> createState() => _ProfileTierListState();
}

class _ProfileTierListState extends State<ProfileTierList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final s = context.l10n;
    final tiers = [
      (0, 'L0', s.onboardingBadgeL0, s.profileBadgeDescL0, false),
      (1, 'L1', s.onboardingBadgeL1, s.profileBadgeDescL1, false),
      (2, 'L2', s.onboardingBadgeL2, s.profileBadgeDescL2, false),
      (3, 'L3', s.onboardingBadgeL3, s.profileBadgeDescL3, true),
    ];
    final canUpgradeNow =
        widget.currentLevel == 0 && !tiers[1].$5; // L0→L1 仍可升級

    return IgniCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── 收合列：四個圖示排一橫列 + 展開箭頭 ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: IgniSpacing.md, vertical: 13),
              child: Row(
                children: [
                  for (int i = 0; i < tiers.length; i++) ...[
                    if (i > 0) const SizedBox(width: IgniSpacing.sm),
                    Opacity(
                      opacity: tiers[i].$5 ? 0.5 : 1.0,
                      child: _TierDot(
                        done: widget.currentLevel > tiers[i].$1,
                        active: widget.currentLevel == tiers[i].$1,
                        color: p,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (canUpgradeNow && !_expanded)
                    TextButton(
                      onPressed: widget.onVerifyPhone,
                      child: Text(s.profileTrustPhoneVerify,
                          style: IgniTypography.labelSmall(p.brand)),
                    ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: p.text2,
                  ),
                ],
              ),
            ),
          ),
          // ── 展開內容：原本的逐列詳述 ──
          if (_expanded) ...[
            Divider(height: 1, color: p.border0),
            for (int i = 0; i < tiers.length; i++)
              _TierDetailRow(
                lvl: tiers[i].$1,
                id: tiers[i].$2,
                name: tiers[i].$3,
                desc: tiers[i].$4,
                locked: tiers[i].$5,
                currentLevel: widget.currentLevel,
                showBottomBorder: i < tiers.length - 1,
                onVerifyPhone: widget.onVerifyPhone,
              ),
          ],
        ],
      ),
    );
  }
}

class _TierDetailRow extends StatelessWidget {
  const _TierDetailRow({
    required this.lvl,
    required this.id,
    required this.name,
    required this.desc,
    required this.locked,
    required this.currentLevel,
    required this.showBottomBorder,
    required this.onVerifyPhone,
  });

  final int lvl;
  final String id;
  final String name;
  final String desc;
  final bool locked;
  final int currentLevel;
  final bool showBottomBorder;
  final VoidCallback onVerifyPhone;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final s = context.l10n;
    final done = currentLevel > lvl;
    final active = currentLevel == lvl;
    final canUpgrade = currentLevel == lvl - 1 && !locked && lvl == 1;
    return Opacity(
      opacity: locked ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: IgniSpacing.md, vertical: 13),
        decoration: BoxDecoration(
          border: showBottomBorder
              ? Border(bottom: BorderSide(color: p.border0))
              : null,
        ),
        child: Row(
          children: [
            _TierDot(done: done, active: active, color: p),
            const SizedBox(width: IgniSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$id · $name',
                    style: IgniTypography.bodyMedium(
                      active ? p.brand : p.text0,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(desc, style: IgniTypography.bodySmall(p.text2)),
                ],
              ),
            ),
            if (locked)
              Text(s.profileTrustNotOpen,
                  style: IgniTypography.monoSmall(p.text3)),
            if (canUpgrade)
              TextButton(
                onPressed: onVerifyPhone,
                child: Text(s.profileTrustPhoneVerify,
                    style: IgniTypography.labelSmall(p.brand)),
              ),
          ],
        ),
      ),
    );
  }
}

class _TierDot extends StatelessWidget {
  const _TierDot({
    required this.done,
    required this.active,
    required this.color,
  });

  final bool done;
  final bool active;
  final IgniPalette color;

  @override
  Widget build(BuildContext context) {
    final border = active ? color.brand : (done ? color.ok : color.border2);
    final fill =
        active ? color.brand : (done ? color.ok : Colors.transparent);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 2),
      ),
      child: (done || active)
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}
