import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/main.dart';
import 'package:ignirelay_app/ui/secondary/battery_optimization_guide.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_text_scale.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_screen.dart';
import 'package:ignirelay_app/ui/screens/me/profile_mesh_status_card.dart';
import 'package:ignirelay_app/ui/secondary/survival_mode_screen.dart';
import 'package:ignirelay_app/ui/widgets/igni_card.dart';
import 'package:ignirelay_app/ui/widgets/igni_chip.dart';
import 'package:ignirelay_app/ui/widgets/igni_section_label.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';

/// 烽傳 Ignirelay「我」分頁。
///
/// 對應原型 MeScreen.jsx：身分卡 + Quick actions + Mesh 狀態 + 信任等級 + 設定。
/// 吸收舊 SurvivalModeScreen 的核心狀態（電量 / peer count / transport mode），
/// 完整控制面板仍以 SubPage 形式保留至 Stage 5 清理。
class IgniProfileScreen extends StatefulWidget {
  const IgniProfileScreen({super.key});

  @override
  State<IgniProfileScreen> createState() => _IgniProfileScreenState();
}

class _IgniProfileScreenState extends State<IgniProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _identity = IdentityManager();
  final _db = DatabaseHelper();
  int _level = 0;
  String _pubKeyHex = '';
  String _nickname = '';
  bool _hasMedicalCard = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pubKey = await _identity.getPublicKeyBytes();
    final hex =
        pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final prefs = await SharedPreferences.getInstance();
    final mcJson = await _db.getMedicalCard(pubKey);
    if (!mounted) return;
    setState(() {
      _level = _identity.getIdentityLevel();
      _pubKeyHex = hex;
      _nickname = prefs.getString('nickname') ?? '';
      _hasMedicalCard = mcJson != null && mcJson.isNotEmpty;
    });
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final s = ctx.l10n;
        return AlertDialog(
          title: Text(s.profileNicknameDialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            decoration: InputDecoration(hintText: s.profileNicknameDialogHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.profileNicknameDialogCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(s.profileNicknameDialogSave),
            ),
          ],
        );
      },
    );
    if (result == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', result);
    if (!mounted) return;
    setState(() => _nickname = result);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.isNotEmpty
          ? context.l10n.profileNicknameUpdated(result)
          : context.l10n.profileNicknameCleared),
    ));
  }

  Future<void> _copyPubKey() async {
    if (_pubKeyHex.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _pubKeyHex));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.profilePubKeyCopied),
      duration: const Duration(seconds: 2),
    ));
  }

  void _pushMedicalCard() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MedicalCardScreen()))
        .then((saved) {
      if (saved == true) _load();
    });
  }

  // Stage 7-r3：移除「實體交接」假入口。實體交接流程必須在媒合協商上下文內
  // 才有意義（需要 role / resourceId / negotiationId / method 等參數），而
  // Profile 沒有這個上下文 — 之前只是點了跳 snackbar 告訴使用者「請去媒合分頁」，
  // 實際上沒有任何功能。產品決策：直接拿掉這個 quick action。

  void _pushSurvivalMode() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SurvivalModeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = context.l10n;
    final p = context.igni;

    return Container(
      color: p.bg0,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(
            top: IgniSpacing.xl,
            bottom: IgniSpacing.bottomTabBarHeight + IgniSpacing.xl2,
          ),
          children: [
            // ── 頁首 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IgniSpacing.xl,
                IgniSpacing.xl2,
                IgniSpacing.xl,
                IgniSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.tabProfile, style: IgniTypography.display(p.text0)),
                  const SizedBox(height: 4),
                  Text(
                    s.profileSubtitle,
                    style: IgniTypography.monoSmall(p.text2),
                  ),
                ],
              ),
            ),

            // ── 身分卡 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.lg),
              child: _IdentityCard(
                level: _level,
                nickname: _nickname,
                pubKeyHex: _pubKeyHex,
                onEditNickname: _editNickname,
                onCopyPubKey: _copyPubKey,
                badgeLabel: _badgeName(s, _level),
              ),
            ),

            const SizedBox(height: IgniSpacing.md),

            // ── Quick action（醫療卡）──
            //
            // Stage 7-r3：拿掉「實體交接」入口（沒有 negotiation 上下文，原本只
            // 會跳 snackbar）；醫療卡單獨一張，不做 Row，避免單一卡硬撐成兩欄。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.lg),
              child: _QuickAction(
                icon: Icons.medical_services_outlined,
                accent: p.sos,
                label: _hasMedicalCard
                    ? s.profileQuickActionMedicalCard
                    : s.profileQuickActionMedicalCardCreate,
                onTap: _pushMedicalCard,
              ),
            ),

            const SizedBox(height: IgniSpacing.xl),

            // ── Mesh 狀態（精簡）──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgniSectionLabel(s.profileSectionMesh),
                  ProfileMeshStatusCard(onOpenDetail: _pushSurvivalMode),
                ],
              ),
            ),

            const SizedBox(height: IgniSpacing.xl),

            // ── 信任等級 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgniSectionLabel(s.profileSectionTrust),
                  _TierList(
                    currentLevel: _level,
                    onVerifyPhone: () async {
                      await _identity.upgradeIdentityLevel(1);
                      if (!context.mounted) return;
                      setState(() => _level = 1);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.l10n.profileUpgradeSnack),
                      ));
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: IgniSpacing.xl),

            // ── 設定 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgniSectionLabel(s.profileSectionSettings),
                  _SettingsCard(
                    onOpenBatteryGuide: Platform.isAndroid
                        ? () => BatteryOptimizationGuide.showGuideManually(
                            context)
                        : null,
                  ),
                ],
              ),
            ),

            // ── Footer ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: IgniSpacing.xl2),
              child: Column(
                children: [
                  Text(
                    s.profileFooterVersion(kAppVersionName, kAppBuildNumber),
                    style: IgniTypography.monoSmall(p.text3),
                  ),
                  const SizedBox(height: 4),
                  Text(s.profileFooterTagline,
                      style: IgniTypography.monoSmall(p.text3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _badgeName(S s, int lvl) {
    switch (lvl.clamp(0, 3)) {
      case 0:
        return 'L0 · ${s.onboardingBadgeL0}';
      case 1:
        return 'L1 · ${s.onboardingBadgeL1}';
      case 2:
        return 'L2 · ${s.onboardingBadgeL2}';
      default:
        return 'L3 · ${s.onboardingBadgeL3}';
    }
  }
}

/// ───────────────────────── Identity card ─────────────────────────
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
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
                          constraints:
                              const BoxConstraints(minWidth: 24, minHeight: 24),
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

/// ───────────────────────── Quick action ─────────────────────────
class _QuickAction extends StatelessWidget {
  const _QuickAction({
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

/// ───────────────────────── Tier list ─────────────────────────
///
/// Stage 4a 交付項：信任等級改為圖示優先，L0-L3 文字與描述預設收合，
/// 點擊展開才顯示；升級按鈕在收合狀態仍可見以保留既有升級流程。
class _TierList extends StatefulWidget {
  const _TierList({required this.currentLevel, required this.onVerifyPhone});
  final int currentLevel;
  final VoidCallback onVerifyPhone;

  @override
  State<_TierList> createState() => _TierListState();
}

class _TierListState extends State<_TierList> {
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

/// ───────────────────────── Settings ─────────────────────────
///
/// Stage 7-r3 設定面板瘦身：
///   - 移除「主題色」選擇（產品決策：固定 amber，減少 QA 面積）。
///   - 「密度」改為「字體大小」(IgniTextScale)，對 a11y / 老人家更實際。
///   - 移除「急難模式（手動）」UI 入口（自動 trigger 尚未全接，先不暴露
///     一個半成品開關；底層 EmergencyModeController.manual 仍可保留供未來
///     再開回，這裡只是不在設定頁顯示）。
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({this.onOpenBatteryGuide});
  final VoidCallback? onOpenBatteryGuide;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final s = context.l10n;
    final currentLocale = Localizations.localeOf(context).languageCode;
    return IgniCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingsRow(
            icon: Icons.wb_sunny_outlined,
            label: s.profileSettingsAppearance,
            trailing: _ThemeToggle(),
          ),
          _SettingsRow(
            icon: Icons.format_size,
            label: s.profileSettingsTextScale,
            trailing: _TextScalePicker(),
          ),
          _SettingsRow(
            icon: Icons.translate,
            label: s.profileSettingsLanguage,
            trailing: DropdownButton<String>(
              value: currentLocale,
              underline: const SizedBox.shrink(),
              style: IgniTypography.bodyMedium(p.text0),
              dropdownColor: p.bg2,
              items: const [
                DropdownMenuItem(value: 'zh', child: Text('繁體中文')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (code) {
                if (code != null) {
                  IgniRelayApp.setLocale(context, Locale(code));
                }
              },
            ),
          ),
          if (onOpenBatteryGuide != null)
            _SettingsRow(
              icon: Icons.battery_saver,
              label: s.profileSettingsBattery,
              onTap: onOpenBatteryGuide,
            ),
          _SettingsRow(
            icon: Icons.shield_outlined,
            label: s.profileSettingsPrivacy,
            onTap: null,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final row = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: IgniSpacing.md, vertical: 13),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.border0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.text1),
          const SizedBox(width: IgniSpacing.md),
          Expanded(
            child: Text(label, style: IgniTypography.bodyMedium(p.text0)),
          ),
          if (trailing != null) trailing!,
          if (trailing == null && onTap != null)
            Icon(Icons.chevron_right, size: 14, color: p.text3),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final s = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget seg(String key, String label, bool active) {
      return GestureDetector(
        onTap: () => IgniRelayApp.setThemeMode(
          context,
          key == 'dark' ? ThemeMode.dark : ThemeMode.light,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? p.bg1 : Colors.transparent,
            borderRadius: const BorderRadius.all(IgniRadii.xs),
          ),
          child: Text(
            label,
            style: IgniTypography.monoSmall(active ? p.text0 : p.text2),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: p.bg2,
        borderRadius: const BorderRadius.all(IgniRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('dark', s.profileThemeDark, isDark),
          seg('light', s.profileThemeLight, !isDark),
        ],
      ),
    );
  }
}

/// 字體大小切換：標準 / 大字 / 特大字 / 超大字。
///
/// 存於 `SharedPreferences('app_text_scale')`，進入時由 main.dart 回讀，
/// 經 `MaterialApp.builder` 包一層 `MediaQuery` textScaler 套用。
class _TextScalePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final s = context.l10n;
    final current = IgniRelayApp.textScaleOf(context);

    String labelOf(IgniTextScale t) {
      switch (t) {
        case IgniTextScale.standard:
          return s.profileTextScaleStandard;
        case IgniTextScale.large:
          return s.profileTextScaleLarge;
        case IgniTextScale.xLarge:
          return s.profileTextScaleXLarge;
        case IgniTextScale.huge:
          return s.profileTextScaleHuge;
      }
    }

    Widget seg(IgniTextScale t) {
      final active = t == current;
      return GestureDetector(
        onTap: () => IgniRelayApp.setTextScale(context, t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? p.bg1 : Colors.transparent,
            borderRadius: const BorderRadius.all(IgniRadii.xs),
          ),
          child: Text(
            labelOf(t),
            style: IgniTypography.monoSmall(active ? p.text0 : p.text2),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: p.bg2,
        borderRadius: const BorderRadius.all(IgniRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: IgniTextScale.values.map(seg).toList(),
      ),
    );
  }
}
