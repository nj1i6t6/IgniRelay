import 'package:flutter/material.dart';

import 'package:ignirelay_app/ui/screens/map/widgets/poi_category.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';

/// Stage 4d Round 2：POI 詳情 BottomSheet。
///
/// 原位：`map_screen.dart` 原 `_showPoiInfoSheet`（L671-771）+
/// `_poiInfoRow`（L773）+ `_poiHoursWidget`（L795）+
/// `_formatOpeningHours`（L829）。一併搬過來，避免主檔殘留工具函式。
///
/// 使用：`PoiInfoSheet.show(context, poi)`。
class PoiInfoSheet {
  PoiInfoSheet._();

  static void show(BuildContext context, Map<String, String> poi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.igni.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PoiInfoSheetBody(poi: poi),
    );
  }
}

class _PoiInfoSheetBody extends StatelessWidget {
  const _PoiInfoSheetBody({required this.poi});

  final Map<String, String> poi;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final name = poi['name'] ?? '';
    final cls = poi['class'] ?? '';
    final sub = poi['subclass'] ?? '';
    final phone = poi['phone'] ?? '';
    final hours = poi['opening_hours'] ?? '';
    final houseNo = poi['housenumber'] ?? '';
    final street = poi['addr_street'] ?? '';
    final city = poi['addr_city'] ?? '';
    final district = poi['addr_district'] ?? '';
    final addrFull = poi['addr_full'] ?? '';

    // 組合地址：優先使用 addr:full，否則拼接
    String address = '';
    if (addrFull.isNotEmpty) {
      address = addrFull;
    } else {
      final parts = <String>[];
      if (city.isNotEmpty) parts.add(city);
      if (district.isNotEmpty) parts.add(district);
      if (street.isNotEmpty) parts.add(street);
      if (houseNo.isNotEmpty) parts.add('$houseNo號');
      address = parts.join('');
    }

    final category = PoiCategories.label(context, cls, sub);
    final categoryColor = PoiCategories.color(cls, sub);
    final l = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖曳指示器
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: p.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 名稱 + 類別標籤
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: p.text0,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: categoryColor, width: 1),
                ),
                child: Text(
                  category,
                  style: TextStyle(color: categoryColor, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 資訊列表
          if (address.isNotEmpty)
            _PoiInfoRow(
                icon: Icons.location_on,
                label: l.mapPoiInfoAddress,
                value: address),
          if (phone.isNotEmpty)
            _PoiInfoRow(icon: Icons.phone, label: l.mapPoiInfoPhone, value: phone),
          if (hours.isNotEmpty) _PoiHoursRow(raw: hours),
          // 如果三項都空，顯示提示
          if (address.isEmpty && phone.isEmpty && hours.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l.mapPoiInfoNoDetail,
                  style: TextStyle(color: p.text3, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _PoiInfoRow extends StatelessWidget {
  const _PoiInfoRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.text2, size: 18),
          const SizedBox(width: 10),
          Text('$label  ',
              style: TextStyle(color: p.text2, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: p.text0, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoiHoursRow extends StatelessWidget {
  const _PoiHoursRow({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final lines = _formatOpeningHours(context, raw);
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.access_time, color: p.text2, size: 18),
          const SizedBox(width: 10),
          Text('${l.mapPoiInfoOpen}  ',
              style: TextStyle(color: p.text2, fontSize: 13)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map((ln) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(ln,
                            style: TextStyle(
                                color: p.text0, fontSize: 13)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 解析 OSM opening_hours 字串，回傳格式化的行列表。
  ///
  /// 例: "Mo-Tu 09:00-12:00,15:30-17:30; We 09:00-12:00; Su off"
  /// →  ["週一～週二  09:00-12:00, 15:30-17:30",
  ///     "週三        09:00-12:00",
  ///     "週日        公休"]
  static List<String> _formatOpeningHours(BuildContext context, String raw) {
    final l = context.l10n;
    final dayMap = {
      'Mo': l.mapDayMonday,
      'Tu': l.mapDayTuesday,
      'We': l.mapDayWednesday,
      'Th': l.mapDayThursday,
      'Fr': l.mapDayFriday,
      'Sa': l.mapDaySaturday,
      'Su': l.mapDaySunday,
    };
    final holidayLabel = l.mapDayHoliday;
    final closedLabel = l.mapDayClosed;

    String translateDays(String s) {
      var result = s;
      // 先處理 "-" 連接的範圍 (Mo-Fr → 週一～週五)
      result = result.replaceAllMapped(
        RegExp(r'\b(Mo|Tu|We|Th|Fr|Sa|Su)\s*-\s*(Mo|Tu|We|Th|Fr|Sa|Su)\b'),
        (m) => '${dayMap[m[1]] ?? m[1]!}～${dayMap[m[2]] ?? m[2]!}',
      );
      // 再處理 "," 分隔的多日 (Mo,We → 週一、週三)
      result = result.replaceAllMapped(
        RegExp(r'\b(Mo|Tu|We|Th|Fr|Sa|Su)\b'),
        (m) => dayMap[m[0]] ?? m[0]!,
      );
      result = result.replaceAll(RegExp(r'PH\b'), holidayLabel);
      return result;
    }

    final rules =
        raw.split(';').map((r) => r.trim()).where((r) => r.isNotEmpty);
    final lines = <String>[];

    for (final rule in rules) {
      var formatted = rule.replaceAll(
          RegExp(r'\boff\b', caseSensitive: false), closedLabel);
      formatted = translateDays(formatted);
      formatted = formatted.replaceAll(',', ', ');
      lines.add(formatted.trim());
    }

    return lines.isEmpty ? [raw] : lines;
  }
}
