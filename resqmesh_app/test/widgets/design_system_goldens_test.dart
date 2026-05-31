// design_system_goldens_test.dart
//
// Stage 7：Design System Golden 最小集 3×3。
//
// 三個元件 × 三個主題 = 9 張 baseline。token 任一變動 → 比對失敗，
// 手動 `flutter test --update-goldens` 才能通過（token smoke）。
//
// 元件範圍依 plan §Stage 7：
//   - GlassCard（單一 scene 即可）
//   - StatusChip（同 scene 內 6 種 tone）
//   - GlassIconBtn（同 scene 內 default / selected / danger 三態）
// 不納入動效類（SlideUpSheet / PulseEffect / RippleEffect）以避免維護負擔。
//
// Tagged `golden`: pixel comparisons are platform/GPU-dependent, so CI excludes
// this tag (`flutter test --exclude-tags golden`). Run locally with plain
// `flutter test` to validate, and `--update-goldens` to regenerate baselines.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ignirelay_app/ui/theme/app_theme.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/widgets/glass_card.dart';
import 'package:ignirelay_app/ui/widgets/glass_icon_btn.dart';
import 'package:ignirelay_app/ui/widgets/status_chip.dart';

/// 將 widget 包進指定主題的 MaterialApp，方便 golden harness 抓 sized snapshot。
Widget _wrap({required ThemeData theme, required Widget child, double width = 320}) {
  return MaterialApp(
    theme: theme,
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Widget _glassCardScene() {
  return const GlassCard(
    child: Text('GlassCard',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
  );
}

Widget _statusChipScene() {
  return const Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      StatusChip(label: 'brand', tone: StatusTone.brand),
      StatusChip(label: 'sos', tone: StatusTone.sos, icon: Icons.warning),
      StatusChip(label: 'warn', tone: StatusTone.warn),
      StatusChip(label: 'ok', tone: StatusTone.ok, icon: Icons.check),
      StatusChip(label: 'info', tone: StatusTone.info),
      StatusChip(label: 'neutral', tone: StatusTone.neutral),
    ],
  );
}

Widget _glassIconBtnScene() {
  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      GlassIconBtn(icon: Icons.layers, onPressed: () {}, tooltip: 'default'),
      GlassIconBtn(
          icon: Icons.layers_outlined,
          onPressed: () {},
          selected: true,
          tooltip: 'selected'),
      GlassIconBtn(
          icon: Icons.warning,
          onPressed: () {},
          danger: true,
          tooltip: 'danger'),
    ],
  );
}

class _Theme {
  const _Theme(this.name, this.theme);
  final String name;
  final ThemeData theme;
}

final List<_Theme> _themes = [
  _Theme('dark', AppTheme.dark()),
  _Theme('light', AppTheme.light()),
  _Theme('emergency', AppTheme.emergency()),
];

void main() {
  // Stage 7 baseline 解析度固定，避免不同機台 DPR 漂移。
  setUp(() {
    // 顯式確認 IgniPalette 存在於主題（防止意外抽掉 extension）
    final ext = AppTheme.dark().extension<IgniPalette>();
    expect(ext, isNotNull);
  });

  group('Stage 7 Golden 3×3 — GlassCard', () {
    for (final t in _themes) {
      testWidgets('GlassCard / ${t.name}', (tester) async {
        await tester.pumpWidget(_wrap(theme: t.theme, child: _glassCardScene()));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/glass_card_${t.name}.png'),
        );
      });
    }
  });

  group('Stage 7 Golden 3×3 — StatusChip', () {
    for (final t in _themes) {
      testWidgets('StatusChip(6 tones) / ${t.name}', (tester) async {
        await tester
            .pumpWidget(_wrap(theme: t.theme, child: _statusChipScene()));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/status_chip_${t.name}.png'),
        );
      });
    }
  });

  group('Stage 7 Golden 3×3 — GlassIconBtn', () {
    for (final t in _themes) {
      testWidgets('GlassIconBtn(3 states) / ${t.name}', (tester) async {
        await tester
            .pumpWidget(_wrap(theme: t.theme, child: _glassIconBtnScene()));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/glass_icon_btn_${t.name}.png'),
        );
      });
    }
  });
}
