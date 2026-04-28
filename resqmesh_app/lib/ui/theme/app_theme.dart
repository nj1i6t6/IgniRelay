import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_accent.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_tokens.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

/// 產出三組 [ThemeData]：dark / light / emergency。
///
/// Stage 2 / Stage 4a 歷史：曾經支援 [IgniAccent] 多色與 [IgniDensity] 三段。
/// Stage 7-r3 起：accent 固定 amber（產品決策：簡化選項、降低 QA 面積），
/// 而舊的「密度」改由 [IgniTextScale] 在 root 套 MediaQuery textScaler 取代，
/// `ThemeData.visualDensity` 維持 [VisualDensity.standard]。
class AppTheme {
  const AppTheme._();

  static ThemeData dark({IgniAccent accent = IgniAccent.amber}) =>
      _build(applyAccent(IgniPalette.dark, accent), Brightness.dark);
  static ThemeData light({IgniAccent accent = IgniAccent.amber}) =>
      _build(applyAccent(IgniPalette.light, accent), Brightness.light);
  static ThemeData emergency() =>
      _build(IgniPalette.emergency, Brightness.dark);

  static ThemeData _build(IgniPalette p, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.brand,
      onPrimary: Colors.white,
      secondary: p.info,
      onSecondary: Colors.white,
      error: p.sos,
      onError: Colors.white,
      surface: p.bg1,
      onSurface: p.text0,
      surfaceContainerHighest: p.bg2,
      onSurfaceVariant: p.text1,
      outline: p.border2,
      outlineVariant: p.border1,
      shadow: Colors.black,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.bg0,
      canvasColor: p.bg0,
      dividerColor: p.border1,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: IgniTypography.sansFamily,
      fontFamilyFallback: IgniTypography.sansFallback,
      textTheme: TextTheme(
        displayLarge: IgniTypography.display(p.text0),
        titleLarge: IgniTypography.titleLarge(p.text0),
        titleMedium: IgniTypography.titleMedium(p.text0),
        bodyLarge: IgniTypography.bodyLarge(p.text0),
        bodyMedium: IgniTypography.bodyMedium(p.text1),
        bodySmall: IgniTypography.bodySmall(p.text2),
        labelLarge: IgniTypography.labelLarge(p.text0),
        labelMedium: IgniTypography.labelSmall(p.text1),
        labelSmall: IgniTypography.sectionHeader(p.text2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg0,
        foregroundColor: p.text0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: IgniTypography.titleLarge(p.text0),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bg1,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: IgniRadii.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.bg2,
        contentTextStyle: IgniTypography.bodyMedium(p.text0),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(IgniRadii.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bg1,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(IgniRadii.xl),
        ),
        titleTextStyle: IgniTypography.titleMedium(p.text0),
        contentTextStyle: IgniTypography.bodyMedium(p.text1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bg2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: IgniSpacing.lg,
          vertical: IgniSpacing.md,
        ),
        hintStyle: IgniTypography.bodyMedium(p.text3),
        labelStyle: IgniTypography.labelSmall(p.text2),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(IgniRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(IgniRadii.md),
          borderSide: BorderSide(color: p.border1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(IgniRadii.md),
          borderSide: BorderSide(color: p.brand, width: 1.5),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[p],
    );
  }
}
