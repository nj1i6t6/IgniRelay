import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 行政區名稱解析器。
///
/// 載入 `assets/geodata/taiwan_admin_names.json`，提供 county / town
/// 的中英文名稱查詢。`ensureLoaded()` 為唯一 async 入口；
/// cache ready 後 `county()` / `town()` 為同步 Map lookup。
class AdminNameResolver {
  AdminNameResolver._();

  static final AdminNameResolver _instance = AdminNameResolver._();
  factory AdminNameResolver() => _instance;

  bool _loaded = false;

  final Map<String, _AdminEntry> _counties = {};
  final Map<String, _AdminEntry> _towns = {};

  /// 載入 asset JSON。首次呼叫載入並建立 cache，後續 no-op。
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final jsonStr = await rootBundle.loadString(
      'assets/geodata/taiwan_admin_names.json',
    );
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final counties = data['counties'] as Map<String, dynamic>;
    for (final entry in counties.entries) {
      final m = entry.value as Map<String, dynamic>;
      _counties[entry.key] = _AdminEntry(
        zhHant: m['zhHant'] as String,
        en: m['en'] as String,
      );
    }

    final towns = data['towns'] as Map<String, dynamic>;
    for (final entry in towns.entries) {
      final m = entry.value as Map<String, dynamic>;
      _towns[entry.key] = _AdminEntry(
        zhHant: m['zhHant'] as String,
        en: m['en'] as String,
      );
    }

    _loaded = true;
  }

  /// 依 county code 回傳中英文名稱。找不到回傳 null。
  ({String zhHant, String en})? county(String code) {
    final e = _counties[code];
    if (e == null) return null;
    return (zhHant: e.zhHant, en: e.en);
  }

  /// 依 town code 回傳中英文名稱。找不到回傳 null。
  ({String zhHant, String en})? town(String code) {
    final e = _towns[code];
    if (e == null) return null;
    return (zhHant: e.zhHant, en: e.en);
  }

  /// 測試專用：直接注入資料，跳過 asset 載入。
  @visibleForTesting
  void debugSetData({
    required Map<String, ({String zhHant, String en})> counties,
    required Map<String, ({String zhHant, String en})> towns,
  }) {
    _counties.clear();
    _towns.clear();
    for (final e in counties.entries) {
      _counties[e.key] = _AdminEntry(zhHant: e.value.zhHant, en: e.value.en);
    }
    for (final e in towns.entries) {
      _towns[e.key] = _AdminEntry(zhHant: e.value.zhHant, en: e.value.en);
    }
    _loaded = true;
  }
}

class _AdminEntry {
  const _AdminEntry({required this.zhHant, required this.en});
  final String zhHant;
  final String en;
}
