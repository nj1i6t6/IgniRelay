import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/widgets/igni_card.dart';
import 'package:ignirelay_app/ui/widgets/igni_chip.dart';

/// 「我」分頁的身分卡 + 醫療卡 quick action。
/// Stage 2B：由 profile_screen god file 拆出。

/// 身分卡：頭像 + 暱稱（可編輯）+ 信任等級 badge + 公鑰（可複製）。
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.level,
    required this.nickname,
    required this.pubKeyHex,
    required this.onEditNickname,
    required this.onCopyPubKey,
    required this.badgeLabel,
  });

  final int level;
  final String nickname;
  final String pubKeyHex;
  final VoidCallback onEditNickname;
  final VoidCallback onCopyPubKey;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final s = context.l10n;
    final display = nickname.isNotEmpty ? nickname : s.profileAnonymous;
    final shortKey = pubKeyHex.length >= 24
        ? '${pubKeyHex.substring(0, 16)}...${pubKeyHex.substring(pubKeyHex.length - 8)}'
        : (pubKeyHex.isEmpty ? s.profilePubKeyLoading : pubKeyHex);

    return IgniCard(
      elevated: true,
      padding: const EdgeInsets.all(IgniSpacing.xl),
      radius: IgniRadii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: p.brand,
                  borderRadius: const BorderRadius.all(IgniRadii.xl),
                  boxShadow: [
                    BoxShadow(
                      color: p.brand.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 28),
              ),
              const SizedBox(width: IgniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            display,
                            style: IgniTypography.titleMedium(p.text0),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: onEditNickname,
                          icon: Icon(Icons.edit, size: 14, color: p.text2),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 24, minHeight: 24),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    IgniChip(
                      label: badgeLabel,
                      tone: IgniChipTone.brand,
                      mono: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: IgniSpacing.md),
          Material(
            color: p.bg0,
            borderRadius: const BorderRadius.all(IgniRadii.sm),
            child: InkWell(
              onTap: onCopyPubKey,
              borderRadius: const BorderRadius.all(IgniRadii.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IgniSpacing.md, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: p.border0),
                  borderRadius: const BorderRadius.all(IgniRadii.sm),
                ),
                child: Row(
                  children: [
                    Text('ED25519',
                        style: IgniTypography.monoSmall(p.text3)
                            .copyWith(fontSize: 9.5, letterSpacing: 1.2)),
                    const SizedBox(width: IgniSpacing.sm),
                    Expanded(
                      child: Text(
                        shortKey,
                        style: IgniTypography.monoSmall(p.text1),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.copy, size: 14, color: p.text2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 單列 quick action 卡片（icon + label + chevron）。
class ProfileQuickAction extends StatelessWidget {
  const ProfileQuickAction({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return IgniCard(
      onTap: onTap,
      padding: const EdgeInsets.all(IgniSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.all(IgniRadii.sm),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: IgniSpacing.md),
          Expanded(
            child: Text(label, style: IgniTypography.labelLarge(p.text0)),
          ),
          Icon(Icons.chevron_right, size: 16, color: p.text3),
        ],
      ),
    );
  }
}
