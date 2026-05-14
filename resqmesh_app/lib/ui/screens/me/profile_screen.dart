import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/services/profile_repo.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/main.dart';
import 'package:ignirelay_app/ui/screens/me/profile_identity_section.dart';
import 'package:ignirelay_app/ui/screens/me/profile_mesh_status_card.dart';
import 'package:ignirelay_app/ui/screens/me/profile_settings_section.dart';
import 'package:ignirelay_app/ui/screens/me/profile_tier_section.dart';
import 'package:ignirelay_app/ui/secondary/battery_optimization_guide.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_screen.dart';
import 'package:ignirelay_app/ui/secondary/survival_mode_screen.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/widgets/igni_section_label.dart';

/// 烽傳 Ignirelay「我」分頁。
///
/// Stage 2B：本檔由 god file 拆出後改為 thin shell。身分卡 / quick action 在
/// [profile_identity_section]；信任等級在 [profile_tier_section]；設定面板在
/// [profile_settings_section]。本檔保留少量畫面 state（暱稱 / 等級 / 公鑰 /
/// 是否有醫療卡）+ ListView 編排。
class IgniProfileScreen extends StatefulWidget {
  const IgniProfileScreen({super.key});

  @override
  State<IgniProfileScreen> createState() => _IgniProfileScreenState();
}

class _IgniProfileScreenState extends State<IgniProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final IdentityManager _identity = context.read<IdentityManager>();
  int _level = 0;
  String _pubKeyHex = '';
  String _nickname = '';
  bool _hasMedicalCard = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final pubKey = await _identity.getPublicKeyBytes();
    final hex = pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final mcJson = await context.read<ProfileRepo>().getMedicalCard(pubKey);
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

  void _pushSurvivalMode() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SurvivalModeScreen()));
  }

  Future<void> _verifyPhone() async {
    await _identity.upgradeIdentityLevel(1);
    if (!mounted) return;
    setState(() => _level = 1);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.profileUpgradeSnack),
    ));
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
              child: ProfileIdentityCard(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: IgniSpacing.lg),
              child: ProfileQuickAction(
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
                  ProfileTierList(
                    currentLevel: _level,
                    onVerifyPhone: _verifyPhone,
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
                  ProfileSettingsCard(
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
