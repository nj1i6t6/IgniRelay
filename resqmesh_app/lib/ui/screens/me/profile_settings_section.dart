import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/main.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_text_scale.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/widgets/igni_card.dart';

/// 「我」分頁的設定區段。
/// Stage 2B：由 profile_screen god file 拆出。
///
/// Stage 7-r3 設定面板瘦身：
///   - 移除「主題色」選擇（產品決策：固定 amber，減少 QA 面積）。
///   - 「密度」改為「字體大小」(IgniTextScale)，對 a11y / 老人家更實際。
///   - 移除「急難模式（手動）」UI 入口（自動 trigger 尚未全接，先不暴露
///     一個半成品開關；底層 EmergencyModeController.manual 仍可保留供未來
///     再開回，這裡只是不在設定頁顯示）。
class ProfileSettingsCard extends StatelessWidget {
  const ProfileSettingsCard({super.key, this.onOpenBatteryGuide});

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
