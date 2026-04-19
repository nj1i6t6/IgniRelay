import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_typography.dart';

/// 等寬字體包裝（JetBrains Mono）。
///
/// 用於座標、時間戳、版本號、ID 等機讀性資訊。中文內文請直接用 [Text]。
/// 行為與 [Text] 一致，差別在 fontFamily / letterSpacing 預設。
class MonoText extends StatelessWidget {
  const MonoText(
    this.data, {
    super.key,
    this.fontSize = 12,
    this.color,
    this.fontWeight,
    this.letterSpacing = 0.5,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final double fontSize;
  final Color? color;
  final FontWeight? fontWeight;
  final double letterSpacing;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontFamily: IgniTypography.monoFamily,
        fontFamilyFallback: IgniTypography.monoFallback,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight ?? FontWeight.w500,
        letterSpacing: letterSpacing,
        height: 1.2,
      ),
    );
  }
}
