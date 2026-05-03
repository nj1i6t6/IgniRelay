import 'package:flutter/widgets.dart';

import 'package:ignirelay_app/app/geo/admin_name_resolver.dart';
import 'package:ignirelay_app/app/geo/village_geofence.dart';

/// 聊天室顯示名稱解析器。
///
/// 依 roomType / roomId / locale 決定 localized display name。
/// - nation / county / township 只需 admin name cache（sync）。
/// - village 需查 `village_boundary.db`（async）。
/// - custom 一律回傳 fallbackRoomName。
///
/// 當 admin lookup miss 時，回傳 locale-aware generic 字串
/// （zh: `縣市公告` / `鄉鎮區公告` / `村里聊天室`；
///  en: `County Announcements` / `Township Announcements` / `Village Chat`），
/// 不回傳 DB 的 `room_name`（可能是舊版中文資料）。
class RoomDisplayNameResolver {
  RoomDisplayNameResolver._();

  static final RoomDisplayNameResolver _instance = RoomDisplayNameResolver._();
  factory RoomDisplayNameResolver() => _instance;

  final AdminNameResolver _adminNames = AdminNameResolver();

  /// 解析聊天室顯示名稱。
  ///
  /// [roomId] 聊天室 ID（nation 為 `TW_NATION`，county 為 `TW_{code}`，
  ///   township 為 `TW_{code}`，village 為 11 碼 villcode）。
  /// [roomType] `nation` / `county` / `township` / `village` / `custom`。
  /// [fallbackRoomName] DB 裡的 `room_name`，僅 custom 類型使用。
  /// [locale] 當前 UI locale。
  Future<String> resolve({
    required String roomId,
    required String roomType,
    required String fallbackRoomName,
    required Locale locale,
  }) async {
    final useZh = locale.languageCode.toLowerCase() == 'zh';

    switch (roomType) {
      case 'nation':
        return useZh ? '全國公告' : 'National Announcements';

      case 'county':
        return _resolveCounty(roomId, useZh);

      case 'township':
        return _resolveTownship(roomId, useZh);

      case 'village':
        return await _resolveVillage(roomId, useZh);

      case 'custom':
      default:
        return fallbackRoomName;
    }
  }

  String _resolveCounty(String roomId, bool useZh) {
    final countyCode = roomId.startsWith('TW_')
        ? roomId.substring(3)
        : roomId;
    final info = _adminNames.county(countyCode);
    if (info == null) return useZh ? '縣市公告' : 'County Announcements';
    return useZh ? '${info.zhHant} 公告' : '${info.en} Announcements';
  }

  String _resolveTownship(String roomId, bool useZh) {
    final townCode = roomId.startsWith('TW_')
        ? roomId.substring(3)
        : roomId;
    final countyCode = townCode.length >= 5 ? townCode.substring(0, 5) : null;
    final townInfo = _adminNames.town(townCode);
    final countyInfo = countyCode != null
        ? _adminNames.county(countyCode)
        : null;

    if (useZh) {
      final county = countyInfo?.zhHant ?? '';
      final town = townInfo?.zhHant ?? '';
      if (county.isEmpty && town.isEmpty) return '鄉鎮區公告';
      return '$county$town 公告';
    } else {
      final county = countyInfo?.en ?? '';
      final town = townInfo?.en ?? '';
      if (county.isEmpty && town.isEmpty) return 'Township Announcements';
      if (county.isEmpty) return '$town Announcements';
      if (town.isEmpty) return '$county Announcements';
      return '$county $town Announcements';
    }
  }

  Future<String> _resolveVillage(String villcode, bool useZh) async {
    final countyCode =
        villcode.length >= 5 ? villcode.substring(0, 5) : null;
    final townCode =
        villcode.length >= 8 ? villcode.substring(0, 8) : null;

    final countyInfo = countyCode != null
        ? _adminNames.county(countyCode)
        : null;
    final townInfo = townCode != null
        ? _adminNames.town(townCode)
        : null;

    VillageInfo? villageInfo;
    try {
      villageInfo = await VillageGeofence.queryByCode(villcode);
    } catch (_) {}

    if (useZh) {
      final county = countyInfo?.zhHant ?? '';
      final town = townInfo?.zhHant ?? '';
      final vill = villageInfo?.villName ?? '';
      if (county.isEmpty && town.isEmpty && vill.isEmpty) return '村里聊天室';
      return '$county$town$vill 聊天室';
    } else {
      return formatVillageEnglish(
        countyEn: countyInfo?.en,
        townEn: townInfo?.en,
        villEng: villageInfo?.villEng,
      );
    }
  }

  /// Sync English village display name formatter.
  ///
  /// Given already-resolved name components, produces the canonical English
  /// display string. Used by both async [resolve] (after DB lookup) and
  /// sync list rendering (e.g. ChatJoinScreen search results) to avoid
  /// duplicating formatting logic.
  static String formatVillageEnglish({
    required String? countyEn,
    required String? townEn,
    required String? villEng,
  }) {
    final county = countyEn ?? '';
    final town = townEn ?? '';
    final rawVill = villEng ?? '';
    final vill = rawVill.replaceAll(RegExp(r'\s*Vil\.\s*$'), '').trim();
    if (vill.isEmpty) return 'Village Chat';
    if (county.isEmpty && town.isEmpty) return '$vill Chat';
    if (county.isEmpty) return '$town $vill Chat';
    if (town.isEmpty) return '$county $vill Chat';
    return '$county $town $vill Chat';
  }
}
