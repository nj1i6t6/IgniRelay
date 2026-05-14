import 'dart:convert';

/// Stage 2A 拆分：station_supply 的元資料 / 資料模型。
///
/// `StationMeta` 編碼在 `ResourceData.deliveryMode` 欄位中
/// （格式：`STATION:{json}`），讓「據點物資」復用 supply event 而不需新增 protocol。
class StationMeta {
  final bool isStation;
  final int perUserCategoryLimit;
  final int perUserTotalLimit;
  final int resetIntervalMs;
  final List<String>? visibleZones;
  final String? visibleTownship;

  const StationMeta({
    required this.isStation,
    required this.perUserCategoryLimit,
    required this.perUserTotalLimit,
    required this.resetIntervalMs,
    this.visibleZones,
    this.visibleTownship,
  });

  String toJson() {
    final map = <String, dynamic>{
      'is_station': isStation,
      'per_user_category_limit': perUserCategoryLimit,
      'per_user_total_limit': perUserTotalLimit,
      'reset_interval_ms': resetIntervalMs,
    };
    if (visibleZones != null) map['visible_zones'] = visibleZones;
    if (visibleTownship != null) map['visible_township'] = visibleTownship;
    return jsonEncode(map);
  }

  static StationMeta? tryParse(String description) {
    if (!description.startsWith('STATION:')) return null;
    try {
      final jsonStr = description.substring('STATION:'.length);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return StationMeta(
        isStation: map['is_station'] as bool? ?? false,
        perUserCategoryLimit: map['per_user_category_limit'] as int? ?? 5,
        perUserTotalLimit: map['per_user_total_limit'] as int? ?? 10,
        resetIntervalMs: map['reset_interval_ms'] as int? ?? 86400000,
        visibleZones: (map['visible_zones'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        visibleTownship: map['visible_township'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class StationItem {
  final String eventId;
  final String resourceId;
  final String resourceType;
  final double quantity;
  final StationMeta meta;
  final List<Map<String, dynamic>> quotaRows;
  final int hlcTimestamp;

  const StationItem({
    required this.eventId,
    required this.resourceId,
    required this.resourceType,
    required this.quantity,
    required this.meta,
    required this.quotaRows,
    required this.hlcTimestamp,
  });
}
