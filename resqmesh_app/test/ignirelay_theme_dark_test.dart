// Phase 5：buildIgniRelayTheme 深淺色 smoke test。
//
// 重點：
//   - light / dark 兩種 brightness 都能 build 出 Theme，不 throw。
//   - dark theme layer 數量與 light 一致（dark patch 只覆寫 paint，不增刪 layer）。

import 'dart:ui' show Brightness, Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/ui/theme/ignirelay_theme.dart';

void main() {
  group('buildIgniRelayTheme — brightness', () {
    test('light brightness 可以建出 Theme', () {
      final theme = buildIgniRelayTheme(
        locale: const Locale('zh', 'TW'),
        brightness: Brightness.light,
      );
      expect(theme.layers, isNotEmpty);
    });

    test('dark brightness layer 集合與 light 完全一致（dark patch 只改既有 paint）', () {
      final light = buildIgniRelayTheme(
        locale: const Locale('zh', 'TW'),
        brightness: Brightness.light,
      );
      final dark = buildIgniRelayTheme(
        locale: const Locale('zh', 'TW'),
        brightness: Brightness.dark,
      );
      // 設計原則：dark palette 只改 paint，不增刪 layer。若這個斷言開始 fail，
      // 代表 _applyDarkPalette 又補了原本沒被渲染的 layer，需要回去調整白名單。
      expect(dark.layers.length, light.layers.length);
    });

    test('英文 locale 也能套 dark palette', () {
      final theme = buildIgniRelayTheme(
        locale: const Locale('en', 'US'),
        brightness: Brightness.dark,
      );
      expect(theme.layers, isNotEmpty);
    });
  });
}
