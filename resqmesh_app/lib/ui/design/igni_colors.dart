import 'package:flutter/material.dart';

/// 烽傳 Ignirelay semantic color palette — translated from styles/tokens.css.
///
/// 五個色群：
///   brand   — 烽 / beacon 暖琥珀（accent 與其軟色/邊界）
///   state   — 背景與文字層級（bg-0..3 / text-0..3 / border-0..2 / shadow）
///   semantic— 狀態：sos / warn / ok / info（+ soft variants）
///   trust   — 信任等級/身分相關（沿用 brand + semantic 組合，不另立）
///   hazard  — 救災類別：water / food / med / shelter / tool
///
/// [IgniPalette] 是 ThemeExtension payload，dark / light / emergency 各有一組常數。
@immutable
class IgniPalette extends ThemeExtension<IgniPalette> {
  const IgniPalette({
    required this.brand,
    required this.brandHover,
    required this.brandSoft,
    required this.brandBorder,
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.bgGlass,
    required this.text0,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.border0,
    required this.border1,
    required this.border2,
    required this.shadow1,
    required this.shadow2,
    required this.sos,
    required this.sosSoft,
    required this.warn,
    required this.warnSoft,
    required this.ok,
    required this.okSoft,
    required this.info,
    required this.infoSoft,
    required this.hazardWater,
    required this.hazardFood,
    required this.hazardMed,
    required this.hazardShelter,
    required this.hazardTool,
    required this.mapLand,
    required this.mapRoad,
    required this.mapWater,
    required this.mapLabel,
    required this.isEmergency,
  });

  final Color brand;
  final Color brandHover;
  final Color brandSoft;
  final Color brandBorder;

  final Color bg0;
  final Color bg1;
  final Color bg2;
  final Color bg3;
  final Color bgGlass;

  final Color text0;
  final Color text1;
  final Color text2;
  final Color text3;

  final Color border0;
  final Color border1;
  final Color border2;

  final Color shadow1;
  final Color shadow2;

  final Color sos;
  final Color sosSoft;
  final Color warn;
  final Color warnSoft;
  final Color ok;
  final Color okSoft;
  final Color info;
  final Color infoSoft;

  final Color hazardWater;
  final Color hazardFood;
  final Color hazardMed;
  final Color hazardShelter;
  final Color hazardTool;

  final Color mapLand;
  final Color mapRoad;
  final Color mapWater;
  final Color mapLabel;

  /// true 時 UI 應啟用高對比/放大/固定深色等急難模式調整。
  final bool isEmergency;

  /// 依 hazard category 字串回傳對應顏色；未知類別回傳 [text2]。
  Color hazardFor(String category) {
    switch (category) {
      case 'water':
        return hazardWater;
      case 'food':
        return hazardFood;
      case 'med':
      case 'medical':
        return hazardMed;
      case 'shelter':
        return hazardShelter;
      case 'tool':
        return hazardTool;
      default:
        return text2;
    }
  }

  static const IgniPalette dark = IgniPalette(
    brand: Color(0xFFE8803B),
    brandHover: Color(0xFFF08E4A),
    brandSoft: Color(0x24E8803B),
    brandBorder: Color(0x59E8803B),
    bg0: Color(0xFF0E1013),
    bg1: Color(0xFF151820),
    bg2: Color(0xFF1C2029),
    bg3: Color(0xFF242936),
    bgGlass: Color(0xB8151820),
    text0: Color(0xFFEEF0F3),
    text1: Color(0xFFC6CAD1),
    text2: Color(0xFF8A8F98),
    text3: Color(0xFF5A5F68),
    border0: Color(0x0FFFFFFF),
    border1: Color(0x1AFFFFFF),
    border2: Color(0x29FFFFFF),
    shadow1: Color(0x4D000000),
    shadow2: Color(0x66000000),
    sos: Color(0xFFE5484D),
    sosSoft: Color(0x24E5484D),
    warn: Color(0xFFF5A524),
    warnSoft: Color(0x1FF5A524),
    ok: Color(0xFF30A46C),
    okSoft: Color(0x1F30A46C),
    info: Color(0xFF5B8DEF),
    infoSoft: Color(0x1F5B8DEF),
    hazardWater: Color(0xFF3E90C4),
    hazardFood: Color(0xFFC68F3B),
    hazardMed: Color(0xFFC64B5D),
    hazardShelter: Color(0xFF8C6FBD),
    hazardTool: Color(0xFF5E8C7A),
    mapLand: Color(0xFF1A1E26),
    mapRoad: Color(0xFF2E3340),
    mapWater: Color(0xFF0F1823),
    mapLabel: Color(0xFF6D7380),
    isEmergency: false,
  );

  static const IgniPalette light = IgniPalette(
    brand: Color(0xFFE8803B),
    brandHover: Color(0xFFF08E4A),
    brandSoft: Color(0x24E8803B),
    brandBorder: Color(0x59E8803B),
    bg0: Color(0xFFF7F5F1),
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFF0EDE7),
    bg3: Color(0xFFE6E2DA),
    bgGlass: Color(0xD1FFFFFF),
    text0: Color(0xFF1A1C20),
    text1: Color(0xFF3D4148),
    text2: Color(0xFF6A6E76),
    text3: Color(0xFF9498A0),
    border0: Color(0x0D000000),
    border1: Color(0x17000000),
    border2: Color(0x26000000),
    shadow1: Color(0x0F1E1E28),
    shadow2: Color(0x141E1E28),
    sos: Color(0xFFE5484D),
    sosSoft: Color(0x1FE5484D),
    warn: Color(0xFFF5A524),
    warnSoft: Color(0x1FF5A524),
    ok: Color(0xFF30A46C),
    okSoft: Color(0x1F30A46C),
    info: Color(0xFF5B8DEF),
    infoSoft: Color(0x1F5B8DEF),
    hazardWater: Color(0xFF3E90C4),
    hazardFood: Color(0xFFC68F3B),
    hazardMed: Color(0xFFC64B5D),
    hazardShelter: Color(0xFF8C6FBD),
    hazardTool: Color(0xFF5E8C7A),
    mapLand: Color(0xFFEFEBE2),
    mapRoad: Color(0xFFFFFFFF),
    mapWater: Color(0xFFC8D9E5),
    mapLabel: Color(0xFF6A6E76),
    isEmergency: false,
  );

  /// 急難模式：以 dark 為底，抽高對比（text 更白、border 更亮、sos 更飽和），
  /// 不切換整體色相，確保與 dark 狀態的肌肉記憶一致。
  static const IgniPalette emergency = IgniPalette(
    brand: Color(0xFFF5A524),
    brandHover: Color(0xFFFFB84A),
    brandSoft: Color(0x33F5A524),
    brandBorder: Color(0x80F5A524),
    bg0: Color(0xFF000000),
    bg1: Color(0xFF0B0D10),
    bg2: Color(0xFF14171E),
    bg3: Color(0xFF1E232D),
    bgGlass: Color(0xE60B0D10),
    text0: Color(0xFFFFFFFF),
    text1: Color(0xFFE8EAEE),
    text2: Color(0xFFB6BAC2),
    text3: Color(0xFF7C818A),
    border0: Color(0x1FFFFFFF),
    border1: Color(0x33FFFFFF),
    border2: Color(0x4DFFFFFF),
    shadow1: Color(0x66000000),
    shadow2: Color(0x80000000),
    sos: Color(0xFFFF5B5F),
    sosSoft: Color(0x3DFF5B5F),
    warn: Color(0xFFFFB42E),
    warnSoft: Color(0x33FFB42E),
    ok: Color(0xFF3FBE7F),
    okSoft: Color(0x333FBE7F),
    info: Color(0xFF74A2FF),
    infoSoft: Color(0x3374A2FF),
    hazardWater: Color(0xFF5BAFDF),
    hazardFood: Color(0xFFDFA84E),
    hazardMed: Color(0xFFE06070),
    hazardShelter: Color(0xFFA889D2),
    hazardTool: Color(0xFF78A893),
    mapLand: Color(0xFF14171E),
    mapRoad: Color(0xFF2A2F3C),
    mapWater: Color(0xFF0A1520),
    mapLabel: Color(0xFF9BA2AE),
    isEmergency: true,
  );

  @override
  IgniPalette copyWith({
    Color? brand,
    Color? brandHover,
    Color? brandSoft,
    Color? brandBorder,
    Color? bg0,
    Color? bg1,
    Color? bg2,
    Color? bg3,
    Color? bgGlass,
    Color? text0,
    Color? text1,
    Color? text2,
    Color? text3,
    Color? border0,
    Color? border1,
    Color? border2,
    Color? shadow1,
    Color? shadow2,
    Color? sos,
    Color? sosSoft,
    Color? warn,
    Color? warnSoft,
    Color? ok,
    Color? okSoft,
    Color? info,
    Color? infoSoft,
    Color? hazardWater,
    Color? hazardFood,
    Color? hazardMed,
    Color? hazardShelter,
    Color? hazardTool,
    Color? mapLand,
    Color? mapRoad,
    Color? mapWater,
    Color? mapLabel,
    bool? isEmergency,
  }) {
    return IgniPalette(
      brand: brand ?? this.brand,
      brandHover: brandHover ?? this.brandHover,
      brandSoft: brandSoft ?? this.brandSoft,
      brandBorder: brandBorder ?? this.brandBorder,
      bg0: bg0 ?? this.bg0,
      bg1: bg1 ?? this.bg1,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      bgGlass: bgGlass ?? this.bgGlass,
      text0: text0 ?? this.text0,
      text1: text1 ?? this.text1,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      border0: border0 ?? this.border0,
      border1: border1 ?? this.border1,
      border2: border2 ?? this.border2,
      shadow1: shadow1 ?? this.shadow1,
      shadow2: shadow2 ?? this.shadow2,
      sos: sos ?? this.sos,
      sosSoft: sosSoft ?? this.sosSoft,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      ok: ok ?? this.ok,
      okSoft: okSoft ?? this.okSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      hazardWater: hazardWater ?? this.hazardWater,
      hazardFood: hazardFood ?? this.hazardFood,
      hazardMed: hazardMed ?? this.hazardMed,
      hazardShelter: hazardShelter ?? this.hazardShelter,
      hazardTool: hazardTool ?? this.hazardTool,
      mapLand: mapLand ?? this.mapLand,
      mapRoad: mapRoad ?? this.mapRoad,
      mapWater: mapWater ?? this.mapWater,
      mapLabel: mapLabel ?? this.mapLabel,
      isEmergency: isEmergency ?? this.isEmergency,
    );
  }

  @override
  IgniPalette lerp(ThemeExtension<IgniPalette>? other, double t) {
    if (other is! IgniPalette) return this;
    return IgniPalette(
      brand: Color.lerp(brand, other.brand, t)!,
      brandHover: Color.lerp(brandHover, other.brandHover, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      brandBorder: Color.lerp(brandBorder, other.brandBorder, t)!,
      bg0: Color.lerp(bg0, other.bg0, t)!,
      bg1: Color.lerp(bg1, other.bg1, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      bg3: Color.lerp(bg3, other.bg3, t)!,
      bgGlass: Color.lerp(bgGlass, other.bgGlass, t)!,
      text0: Color.lerp(text0, other.text0, t)!,
      text1: Color.lerp(text1, other.text1, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      border0: Color.lerp(border0, other.border0, t)!,
      border1: Color.lerp(border1, other.border1, t)!,
      border2: Color.lerp(border2, other.border2, t)!,
      shadow1: Color.lerp(shadow1, other.shadow1, t)!,
      shadow2: Color.lerp(shadow2, other.shadow2, t)!,
      sos: Color.lerp(sos, other.sos, t)!,
      sosSoft: Color.lerp(sosSoft, other.sosSoft, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      okSoft: Color.lerp(okSoft, other.okSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      hazardWater: Color.lerp(hazardWater, other.hazardWater, t)!,
      hazardFood: Color.lerp(hazardFood, other.hazardFood, t)!,
      hazardMed: Color.lerp(hazardMed, other.hazardMed, t)!,
      hazardShelter: Color.lerp(hazardShelter, other.hazardShelter, t)!,
      hazardTool: Color.lerp(hazardTool, other.hazardTool, t)!,
      mapLand: Color.lerp(mapLand, other.mapLand, t)!,
      mapRoad: Color.lerp(mapRoad, other.mapRoad, t)!,
      mapWater: Color.lerp(mapWater, other.mapWater, t)!,
      mapLabel: Color.lerp(mapLabel, other.mapLabel, t)!,
      isEmergency: t < 0.5 ? isEmergency : other.isEmergency,
    );
  }
}

/// BuildContext 的便利取用：`context.igni`。
extension IgniPaletteX on BuildContext {
  IgniPalette get igni =>
      Theme.of(this).extension<IgniPalette>() ?? IgniPalette.dark;
}
