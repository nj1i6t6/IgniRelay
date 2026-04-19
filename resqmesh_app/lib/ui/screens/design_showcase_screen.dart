// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/app_theme.dart';
import 'package:ignirelay_app/ui/theme/igni_accent.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/widgets/glass_card.dart';
import 'package:ignirelay_app/ui/widgets/glass_icon_btn.dart';
import 'package:ignirelay_app/ui/widgets/hairline.dart';
import 'package:ignirelay_app/ui/widgets/igni_button.dart';
import 'package:ignirelay_app/ui/widgets/igni_card.dart';
import 'package:ignirelay_app/ui/widgets/igni_chip.dart';
import 'package:ignirelay_app/ui/widgets/igni_section_label.dart';
import 'package:ignirelay_app/ui/widgets/igni_sub_page_header.dart';
import 'package:ignirelay_app/ui/widgets/mono_text.dart';
import 'package:ignirelay_app/ui/widgets/pulse_effect.dart';
import 'package:ignirelay_app/ui/widgets/ripple_effect.dart';
import 'package:ignirelay_app/ui/widgets/slide_up_sheet.dart';
import 'package:ignirelay_app/ui/widgets/status_chip.dart';

/// 設計系統預覽頁（Debug / Profile build 限定）。
///
/// 路由 `/design-showcase`；main.dart 僅在 kDebugMode || kProfileMode 時註冊，
/// release build 不可進入。提供顏色、排版、按鈕、卡片、chip、hazard 類別、
/// accent 切換，與 Stage 2 共用 widget（GlassCard / GlassIconBtn / StatusChip /
/// MonoText / Hairline / PulseEffect / RippleEffect / SlideUpSheet）的完整視覺 QA。
///
/// 右上角切換 dark / light / emergency，不靠 MaterialApp 的 theme，直接 Theme wrapper。
class DesignShowcaseScreen extends StatefulWidget {
  const DesignShowcaseScreen({super.key});

  @override
  State<DesignShowcaseScreen> createState() => _DesignShowcaseScreenState();
}

class _DesignShowcaseScreenState extends State<DesignShowcaseScreen> {
  _Mode _mode = _Mode.dark;
  IgniAccent _accent = IgniAccent.amber;

  @override
  Widget build(BuildContext context) {
    final theme = switch (_mode) {
      _Mode.dark => AppTheme.dark(accent: _accent),
      _Mode.light => AppTheme.light(accent: _accent),
      _Mode.emergency => AppTheme.emergency(),
    };

    return Theme(
      data: theme,
      child: Builder(builder: (context) {
        final p = context.igni;
        return Scaffold(
          backgroundColor: p.bg0,
          body: SafeArea(
            child: Column(
              children: [
                IgniSubPageHeader(
                  title: '設計系統',
                  subtitle: 'Design tokens / widgets / hazard categories',
                  trailing: _ModeSwitcher(
                    mode: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                ),
                _AccentSwitcher(
                  accent: _accent,
                  onChanged: (a) => setState(() => _accent = a),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      IgniSpacing.lg,
                      0,
                      IgniSpacing.lg,
                      IgniSpacing.xl3,
                    ),
                    children: const [
                      _ColorsSection(),
                      SizedBox(height: IgniSpacing.xl2),
                      _TypographySection(),
                      SizedBox(height: IgniSpacing.xl2),
                      _ButtonsSection(),
                      SizedBox(height: IgniSpacing.xl2),
                      _ChipsSection(),
                      SizedBox(height: IgniSpacing.xl2),
                      _CardsSection(),
                      SizedBox(height: IgniSpacing.xl2),
                      _HazardSection(),
                      SizedBox(height: IgniSpacing.xl2),
                      _SharedWidgetsSection(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

enum _Mode { dark, light, emergency }

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.mode, required this.onChanged});
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: p.bg2,
        borderRadius: const BorderRadius.all(IgniRadii.sm),
        border: Border.all(color: p.border0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _Mode.values.map((m) {
          final active = mode == m;
          final label = switch (m) {
            _Mode.dark => '深',
            _Mode.light => '淺',
            _Mode.emergency => '急',
          };
          return GestureDetector(
            onTap: () => onChanged(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: active ? p.bg1 : Colors.transparent,
                borderRadius: const BorderRadius.all(IgniRadii.xs),
              ),
              child: Text(label, style: IgniTypography.labelSmall(
                active ? p.text0 : p.text2,
              )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ColorsSection extends StatelessWidget {
  const _ColorsSection();

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IgniSectionLabel('顏色 · 語意'),
        IgniCard(
          padding: const EdgeInsets.all(IgniSpacing.md),
          child: Wrap(
            spacing: IgniSpacing.sm,
            runSpacing: IgniSpacing.sm,
            children: [
              _Swatch('brand', p.brand),
              _Swatch('sos', p.sos),
              _Swatch('warn', p.warn),
              _Swatch('ok', p.ok),
              _Swatch('info', p.info),
              _Swatch('bg-0', p.bg0),
              _Swatch('bg-1', p.bg1),
              _Swatch('bg-2', p.bg2),
              _Swatch('text-0', p.text0),
              _Swatch('text-2', p.text2),
            ],
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(IgniRadii.sm),
            border: Border.all(color: p.border1),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: IgniTypography.monoSmall(p.text2)),
      ],
    );
  }
}

class _TypographySection extends StatelessWidget {
  const _TypographySection();

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IgniSectionLabel('排版'),
        IgniCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Display 28pt', style: IgniTypography.display(p.text0)),
              const SizedBox(height: 6),
              Text('Title Large 20pt', style: IgniTypography.titleLarge(p.text0)),
              const SizedBox(height: 6),
              Text('Title Medium 17pt', style: IgniTypography.titleMedium(p.text0)),
              const SizedBox(height: 6),
              Text('Body Large 15pt — 這是內文範例文字。',
                  style: IgniTypography.bodyLarge(p.text0)),
              const SizedBox(height: 4),
              Text('Body Medium 14pt — 次級內文，預設 text-1。',
                  style: IgniTypography.bodyMedium(p.text1)),
              const SizedBox(height: 4),
              Text('Body Small 12.5pt — 補充說明文字。',
                  style: IgniTypography.bodySmall(p.text2)),
              const SizedBox(height: 10),
              Text('c5a824fe2aa6fd8f...dc10dbe',
                  style: IgniTypography.monoMedium(p.text1)),
              const SizedBox(height: 4),
              Text('ED25519 · L1 · BUILD 28',
                  style: IgniTypography.monoSmall(p.text3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IgniSectionLabel('按鈕'),
        IgniCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IgniButton(label: '主要', onPressed: _noop, icon: Icons.check),
                const SizedBox(width: IgniSpacing.sm),
                IgniButton(
                  label: '次要',
                  onPressed: _noop,
                  variant: IgniButtonVariant.ghost,
                ),
              ]),
              const SizedBox(height: IgniSpacing.sm),
              Row(children: [
                IgniButton(
                  label: 'SOS 求救',
                  onPressed: _noop,
                  variant: IgniButtonVariant.sos,
                  icon: Icons.warning_amber,
                ),
                const SizedBox(width: IgniSpacing.sm),
                IgniButton(
                  label: '警示',
                  onPressed: _noop,
                  variant: IgniButtonVariant.warn,
                ),
              ]),
              const SizedBox(height: IgniSpacing.sm),
              IgniButton(
                label: '儲存醫療卡',
                onPressed: _noop,
                size: IgniButtonSize.large,
                icon: Icons.check_circle_outline,
                fullWidth: true,
              ),
              const SizedBox(height: IgniSpacing.sm),
              IgniButton(label: '處理中', onPressed: _noop, loading: true),
            ],
          ),
        ),
      ],
    );
  }
}

void _noop() {}

class _ChipsSection extends StatelessWidget {
  const _ChipsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IgniSectionLabel('標籤'),
        IgniCard(
          child: Wrap(
            spacing: IgniSpacing.sm,
            runSpacing: IgniSpacing.sm,
            children: const [
              IgniChip(label: '一般'),
              IgniChip(label: 'L1 · 手機驗證', tone: IgniChipTone.brand, mono: true),
              IgniChip(label: 'SOS', tone: IgniChipTone.sos,
                  icon: Icons.warning_amber),
              IgniChip(label: '警告', tone: IgniChipTone.warn),
              IgniChip(label: '連線中', tone: IgniChipTone.ok),
              IgniChip(label: '同步', tone: IgniChipTone.info),
              IgniChip(label: 'BUILD 28', mono: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardsSection extends StatelessWidget {
  const _CardsSection();

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IgniSectionLabel('卡片'),
        IgniCard(
          elevated: true,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.brand,
                  borderRadius: const BorderRadius.all(IgniRadii.md),
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 28),
              ),
              const SizedBox(width: IgniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('匿名用戶', style: IgniTypography.titleMedium(p.text0)),
                    const SizedBox(height: 4),
                    const IgniChip(
                      label: 'L1 · 手機驗證',
                      tone: IgniChipTone.brand,
                      mono: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: IgniSpacing.sm),
        IgniCard(
          onTap: () {},
          child: Row(children: [
            Icon(Icons.chevron_right, color: p.text3),
            const SizedBox(width: IgniSpacing.sm),
            Text('可點擊卡片 — InkWell ripple',
                style: IgniTypography.bodyMedium(p.text1)),
          ]),
        ),
      ],
    );
  }
}

class _AccentSwitcher extends StatelessWidget {
  const _AccentSwitcher({required this.accent, required this.onChanged});
  final IgniAccent accent;
  final ValueChanged<IgniAccent> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IgniSpacing.lg,
        0,
        IgniSpacing.lg,
        IgniSpacing.md,
      ),
      child: Row(
        children: [
          Text('Accent', style: IgniTypography.sectionHeader(p.text2)),
          const SizedBox(width: IgniSpacing.md),
          ...IgniAccent.values.map((a) {
            final active = accent == a;
            return Padding(
              padding: const EdgeInsets.only(right: IgniSpacing.sm),
              child: GestureDetector(
                onTap: () => onChanged(a),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: IgniSpacing.md,
                    vertical: IgniSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: active ? p.brandSoft : p.bg2,
                    borderRadius: const BorderRadius.all(IgniRadii.pill),
                    border: Border.all(
                      color: active ? p.brandBorder : p.border1,
                    ),
                  ),
                  child: Text(
                    a.label,
                    style: IgniTypography.labelSmall(
                      active ? p.brand : p.text2,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SharedWidgetsSection extends StatelessWidget {
  const _SharedWidgetsSection();

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IgniSectionLabel('共用 widget · Stage 2'),

        // Glass buttons + GlassCard
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GlassCard / GlassIconBtn',
                  style: IgniTypography.titleMedium(p.text0)),
              const SizedBox(height: IgniSpacing.sm),
              Row(children: [
                GlassIconBtn(icon: Icons.layers, onPressed: () {}),
                const SizedBox(width: IgniSpacing.sm),
                GlassIconBtn(
                    icon: Icons.my_location,
                    onPressed: () {},
                    selected: true),
                const SizedBox(width: IgniSpacing.sm),
                GlassIconBtn(
                    icon: Icons.warning_amber,
                    onPressed: () {},
                    danger: true),
              ]),
            ],
          ),
        ),
        const SizedBox(height: IgniSpacing.sm),

        // StatusChip
        IgniCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('StatusChip', style: IgniTypography.titleMedium(p.text0)),
              const SizedBox(height: IgniSpacing.sm),
              Wrap(
                spacing: IgniSpacing.sm,
                runSpacing: IgniSpacing.sm,
                children: const [
                  StatusChip(
                      label: '廣播中',
                      tone: StatusTone.ok,
                      icon: Icons.wifi_tethering),
                  StatusChip(
                      label: 'SOS',
                      tone: StatusTone.sos,
                      icon: Icons.warning_amber),
                  StatusChip(
                      label: '警示',
                      tone: StatusTone.warn,
                      icon: Icons.error_outline),
                  StatusChip(
                      label: '同步',
                      tone: StatusTone.info,
                      icon: Icons.sync),
                  StatusChip(
                      label: 'L1 驗證',
                      tone: StatusTone.brand,
                      icon: Icons.verified_user),
                  StatusChip(label: '離線', tone: StatusTone.neutral),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: IgniSpacing.sm),

        // MonoText + Hairline
        IgniCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MonoText / Hairline',
                  style: IgniTypography.titleMedium(p.text0)),
              const SizedBox(height: IgniSpacing.sm),
              MonoText('23.5564°N 120.4472°E', fontSize: 13, color: p.text1),
              const SizedBox(height: IgniSpacing.xs),
              MonoText('2026-04-19T14:03:22Z', color: p.text2),
              const SizedBox(height: IgniSpacing.sm),
              const Hairline(),
              const SizedBox(height: IgniSpacing.sm),
              const Hairline(strong: true, indent: 24),
            ],
          ),
        ),
        const SizedBox(height: IgniSpacing.sm),

        // Pulse + Ripple
        IgniCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PulseEffect / RippleEffect',
                  style: IgniTypography.titleMedium(p.text0)),
              const SizedBox(height: IgniSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  PulseEffect(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: p.sos,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber,
                          color: Colors.white, size: 24),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: RippleEffect(
                      color: p.brand,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: p.brand,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.wifi,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: IgniSpacing.sm),

        // SlideUpSheet trigger
        IgniCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SlideUpSheet',
                  style: IgniTypography.titleMedium(p.text0)),
              const SizedBox(height: IgniSpacing.sm),
              IgniButton(
                label: '開啟 Sheet 範例',
                icon: Icons.unfold_more,
                onPressed: () {
                  SlideUpSheet.show<void>(
                    context: context,
                    title: '範例 Sheet',
                    builder: (ctx) {
                      final pp = ctx.igni;
                      return Padding(
                        padding: const EdgeInsets.all(IgniSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '這是 SlideUpSheet 的內容區塊。',
                              style: IgniTypography.bodyMedium(pp.text1),
                            ),
                            const SizedBox(height: IgniSpacing.md),
                            const Hairline(),
                            const SizedBox(height: IgniSpacing.md),
                            const MonoText('fingerprint: abc123def456'),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HazardSection extends StatelessWidget {
  const _HazardSection();

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final entries = <(String, String, Color)>[
      ('水', 'water', p.hazardWater),
      ('食', 'food', p.hazardFood),
      ('醫', 'med', p.hazardMed),
      ('避', 'shelter', p.hazardShelter),
      ('工', 'tool', p.hazardTool),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IgniSectionLabel('災害類別'),
        IgniCard(
          child: Row(
            children: entries
                .map((e) => Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: e.$3.withValues(alpha: 0.18),
                              borderRadius: const BorderRadius.all(IgniRadii.md),
                            ),
                            child: Center(
                              child: Text(
                                e.$1,
                                style: IgniTypography.titleMedium(e.$3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(e.$2, style: IgniTypography.monoSmall(p.text2)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
