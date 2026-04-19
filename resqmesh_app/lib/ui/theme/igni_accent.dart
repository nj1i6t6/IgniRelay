import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// 可切換的 accent 色調（計畫 §2）。
///
/// - [amber]：預設烽 brand（#E8803B）
/// - [teal]：靜態場景 / 內勤觀察模式用的沉穩青
/// - [blue]：指引/導航情境用的冷藍
///
/// 不影響 semantic（sos/warn/ok/info/hazard）色，只替換 brand 四件組
/// (`brand` / `brandHover` / `brandSoft` / `brandBorder`) 與 FAB 陰影來源。
enum IgniAccent {
  amber,
  teal,
  blue;

  String get label {
    switch (this) {
      case IgniAccent.amber:
        return '琥珀';
      case IgniAccent.teal:
        return '青';
      case IgniAccent.blue:
        return '冷藍';
    }
  }

  /// 序列化至 SharedPreferences。
  String get storageKey => name;

  static IgniAccent parse(String? s) {
    switch (s) {
      case 'teal':
        return IgniAccent.teal;
      case 'blue':
        return IgniAccent.blue;
      case 'amber':
      default:
        return IgniAccent.amber;
    }
  }
}

class _AccentSet {
  const _AccentSet({
    required this.brand,
    required this.brandHover,
    required this.brandSoft,
    required this.brandBorder,
  });

  final Color brand;
  final Color brandHover;
  final Color brandSoft;
  final Color brandBorder;
}

const _amber = _AccentSet(
  brand: Color(0xFFE8803B),
  brandHover: Color(0xFFF08E4A),
  brandSoft: Color(0x24E8803B),
  brandBorder: Color(0x59E8803B),
);

const _teal = _AccentSet(
  brand: Color(0xFF2FA58A),
  brandHover: Color(0xFF39BB9D),
  brandSoft: Color(0x262FA58A),
  brandBorder: Color(0x5C2FA58A),
);

const _blue = _AccentSet(
  brand: Color(0xFF4C7BE3),
  brandHover: Color(0xFF5D8BF0),
  brandSoft: Color(0x264C7BE3),
  brandBorder: Color(0x5C4C7BE3),
);

_AccentSet _setFor(IgniAccent a) {
  switch (a) {
    case IgniAccent.amber:
      return _amber;
    case IgniAccent.teal:
      return _teal;
    case IgniAccent.blue:
      return _blue;
  }
}

/// 回傳套用 [accent] 之後的 palette 副本。
IgniPalette applyAccent(IgniPalette base, IgniAccent accent) {
  final set = _setFor(accent);
  return base.copyWith(
    brand: set.brand,
    brandHover: set.brandHover,
    brandSoft: set.brandSoft,
    brandBorder: set.brandBorder,
  );
}
