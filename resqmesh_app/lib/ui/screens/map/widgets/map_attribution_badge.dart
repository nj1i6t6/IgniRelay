import 'package:flutter/material.dart';

import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// OpenStreetMap / OpenMapTiles 圖資授權標註。
///
/// 為什麼需要：地圖圖磚是 OSM / OpenMapTiles 家族資料，授權條款明確要求
/// attribution。我們把標註壓在角落，半透明、字小，避免擋到主要操作面板，
/// 但保持可讀。
///
/// 放在地圖左下角（右下會與 SOS / center FAB 撞）。
class MapAttributionBadge extends StatelessWidget {
  const MapAttributionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final isLight = Theme.of(context).brightness == Brightness.light;
    // 在淺色主題上需要白底；在深色主題上用半透黑底，兩者都保證在地圖上仍可讀。
    final bg = isLight
        ? Colors.white.withValues(alpha: 0.78)
        : Colors.black.withValues(alpha: 0.55);
    final fg = isLight ? p.text1 : Colors.white.withValues(alpha: 0.85);
    return IgnorePointer(
      // 純資訊字串，不需要可點擊；避免吃掉地圖手勢。
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          context.l10n.mapAttributionLabel,
          style: TextStyle(
            color: fg,
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
