import 'package:flutter/material.dart';

/// Stage 4d：地圖 pin 色彩大類一色 + icon 次分類。
///
/// 規範（對齊 Refactoring-0.2.0-plan §Stage 4d L222）：
///   - 紅  = 危險（HAZARD / SOS）
///   - 藍  = 醫療（MEDICAL / TRIAGE）
///   - 綠  = 物資（SUPPLY / REQUEST 媒合成功）
///   - 橘  = 生活（REQUEST / 一般通報）
///   - 紫  = 工具（TOOL / 通訊設備）
///
/// Icon 只承擔「次分類」的語意，例如：紅底 × `local_fire_department` 代表火警、
/// 紅底 × `water_drop` 代表水災。避免每個次分類自己發明一套底色，讓使用者
/// 先以「顏色」判斷事件大類（災區、醫療救援、物資供給等），再以 icon 辨識細節。
enum PinCategory {
  hazard, // 紅
  medical, // 藍
  supply, // 綠
  life, // 橘
  tool, // 紫
}

class PinPalette {
  PinPalette._();

  /// 大類一色 — 顏色挑選對應 igni 調色盤的語意色（與 `context.igni` 同色源）。
  static Color color(PinCategory c) {
    switch (c) {
      case PinCategory.hazard:
        return const Color(0xFFD94A4A); // igni.sos
      case PinCategory.medical:
        return const Color(0xFF3A7BD5); // igni.info
      case PinCategory.supply:
        return const Color(0xFF39A56A); // igni.ok
      case PinCategory.life:
        return const Color(0xFFE8803B); // igni.brand
      case PinCategory.tool:
        return const Color(0xFF7A5DB8); // 紫
    }
  }

  /// 由事件類型字串推回大類。未知類型 fallback = life（橘）。
  static PinCategory categoryForEvent(String eventType) {
    final t = eventType.toUpperCase();
    if (t.startsWith('HAZARD') || t == 'SOS' || t == 'TRIAGE_SOS') {
      return PinCategory.hazard;
    }
    if (t == 'MEDICAL' || t == 'TRIAGE' || t == 'AID') {
      return PinCategory.medical;
    }
    if (t == 'SUPPLY' || t == 'MATCH_ACCEPT') return PinCategory.supply;
    if (t == 'TOOL' || t == 'COMMS') return PinCategory.tool;
    // REQUEST / 一般通報 → 橘
    return PinCategory.life;
  }

  /// 危險地點類型 → 次分類 icon（底色一律紅）。
  static IconData hazardIcon(String hazardType) {
    switch (hazardType) {
      case 'FIRE':
        return Icons.local_fire_department;
      case 'FLOOD':
        return Icons.water_drop;
      case 'CHEMICAL':
        return Icons.science;
      case 'BUILDING':
        return Icons.domain_disabled;
      case 'LANDSLIDE':
        return Icons.landscape;
      case 'ROADBLOCK':
      default:
        return Icons.block;
    }
  }

  /// 叢集優先級（Stage 4d plan L221）：
  ///   SOS(hazard) > 避難(supply) > 醫療(medical) > 其他(life/tool)
  /// 回傳值越小優先級越高，供 cluster builder 決定代表色。
  static int clusterPriority(PinCategory c) {
    switch (c) {
      case PinCategory.hazard:
        return 0;
      case PinCategory.supply:
        return 1;
      case PinCategory.medical:
        return 2;
      case PinCategory.life:
        return 3;
      case PinCategory.tool:
        return 4;
    }
  }
}
