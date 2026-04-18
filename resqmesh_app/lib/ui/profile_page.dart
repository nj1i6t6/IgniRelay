import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/main.dart';
import 'package:ignirelay_app/ui/battery_optimization_guide.dart';
import 'package:ignirelay_app/ui/medical_card_screen.dart';

/// 身分 / 信任 Profile 頁面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _identity = IdentityManager();
  final _db = DatabaseHelper();
  int _level = 0;
  String _pubKeyHex = '';
  String _nickname = '';
  bool _hasMedicalCard = false;

  static const _badgeColors = [
    Color(0xFF9E9E9E),
    Color(0xFFCD7F32),
    Color(0xFFB0B0B0),
    Color(0xFFFFD700),
  ];
  List<String> _badgeNamesList(BuildContext context) => [
    S.of(context)!.onboardingBadgeL0,
    S.of(context)!.onboardingBadgeL1,
    S.of(context)!.onboardingBadgeL2,
    S.of(context)!.onboardingBadgeL3,
  ];
  List<String> _badgeDescList(BuildContext context) => [
    S.of(context)!.profileBadgeDescL0,
    S.of(context)!.profileBadgeDescL1,
    S.of(context)!.profileBadgeDescL2,
    S.of(context)!.profileBadgeDescL3,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(S.of(ctx)!.profileNicknameDialogTitle, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: S.of(ctx)!.profileNicknameDialogHint,
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.redAccent),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx)!.profileNicknameDialogCancel, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(S.of(ctx)!.profileNicknameDialogSave),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nickname', result);
      setState(() => _nickname = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.isNotEmpty ? S.of(context)!.profileNicknameUpdated(result) : S.of(context)!.profileNicknameCleared),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    }
  }

  Future<void> _load() async {
    final pubKey = await _identity.getPublicKeyBytes();
    final hex = pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final prefs = await SharedPreferences.getInstance();
    final mcJson = await _db.getMedicalCard(pubKey);
    if (mounted) {
      setState(() {
        _level = _identity.getIdentityLevel();
        _pubKeyHex = hex;
        _nickname = prefs.getString('nickname') ?? '';
        _hasMedicalCard = mcJson != null && mcJson.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final color = _badgeColors[_level.clamp(0, 3)];
    final badgeName = _badgeNamesList(context)[_level.clamp(0, 3)];
    final badgeDesc = _badgeDescList(context)[_level.clamp(0, 3)];

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: Text(S.of(context)!.profileTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
            const SizedBox(height: 24),
            // 徽章
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20)
                ],
              ),
              child: Icon(Icons.shield, color: color, size: 50),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _editNickname,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _nickname.isNotEmpty ? _nickname : S.of(context)!.profileAnonymous,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, color: Colors.white38, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(badgeName, style: TextStyle(color: color, fontSize: 14)),
            const SizedBox(height: 8),
            Text(badgeDesc,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.of(context)!.profilePubKeyLabel,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    _pubKeyHex.isNotEmpty
                        ? '${_pubKeyHex.substring(0, 16)}...${_pubKeyHex.substring(_pubKeyHex.length - 8)}'
                        : S.of(context)!.profilePubKeyLoading,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 背景執行設定按鈕
            if (Platform.isAndroid)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () =>
                    BatteryOptimizationGuide.showGuideManually(context),
                icon: const Icon(Icons.battery_saver, size: 18),
                label:
                    Text(S.of(context)!.profileBatteryButton, style: const TextStyle(fontSize: 13)),
              ),

            const SizedBox(height: 12),

            // 語言切換
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.language, color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(S.of(context)!.profileLanguageLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: Localizations.localeOf(context).languageCode,
                    dropdownColor: const Color(0xFF1a1a2e),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    underline: Container(height: 1, color: Colors.cyanAccent),
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
                ],
              ),
            ),

            // 醫療卡按鈕
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const MedicalCardScreen()))
                    .then((saved) {
                  if (saved == true) _load();
                });
              },
              icon: Icon(
                _hasMedicalCard
                    ? Icons.medical_information
                    : Icons.medical_information_outlined,
                size: 18,
              ),
              label: Text(
                _hasMedicalCard ? S.of(context)!.profileMedicalCardEdit : S.of(context)!.profileMedicalCardCreate,
                style: const TextStyle(fontSize: 13),
              ),
            ),

            const SizedBox(height: 16),

            // 信任升級路徑
            ...[0, 1, 2, 3].map((lvl) {
              final lvlColor = _badgeColors[lvl];
              final isReached = _level >= lvl;
              final isCurrent = _level == lvl;
              final canUpgrade = _level == lvl - 1;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isReached
                      ? lvlColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: isReached ? lvlColor : Colors.white12,
                    width: isCurrent ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReached
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isReached ? lvlColor : Colors.white24,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _badgeNamesList(context)[lvl],
                      style: TextStyle(
                        color: isReached ? lvlColor : Colors.white38,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    // L0→L1: 允許升級（暫時手動，等後端 SMS OTP）
                    if (canUpgrade && lvl == 1) ...[
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await _identity.upgradeIdentityLevel(1);
                          setState(() => _level = 1);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text(S.of(context)!.profileUpgradeSnack)),
                            );
                          }
                        },
                        child: Text(
                          S.of(context)!.profileTrustPhoneVerify,
                          style: TextStyle(color: lvlColor, fontSize: 12),
                        ),
                      ),
                    ],
                    // L2, L3: 尚未開放
                    if (canUpgrade && lvl >= 2) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          S.of(context)!.profileTrustNotOpen,
                          style: const TextStyle(color: Colors.white24, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            ],
          ),
        ),
      ),
    );
  }
}
