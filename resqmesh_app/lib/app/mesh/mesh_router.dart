import 'dart:math';
import 'dart:typed_data';

import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/geo/village_geofence.dart';

class MeshRouter {
  /// 評估是否接受並轉發該封包（Zone-Based Geo-Fencing 核心邏輯）
  ///
  /// 路由策略（依 urgency + eventType 決定路由邊界）：
  ///
  /// | urgency / type              | 路由邊界     | 邊界緩衝 |
  /// |-----------------------------|------------|---------|
  /// | INFO (0) / RESOURCE (1)     | 里           | ~300m   |
  /// | SOS_YELLOW (2) / SOS_RED (3)| 鄉鎮市區      | ~300m   |
  /// | HAZARD_MARKER (type=4)      | 鄉鎮市區      | ~300m   |
  ///
  /// 特殊豁免（永遠轉發）：
  /// - Tier 0 硬體騾子 (isHardwareMule)
  /// - Android Foreground Service Data Mule (isAndroidTier1Foreground)
  /// - SOS_RED + identity >= 1（手機驗證用戶，生死攸關無視邊界）
  ///
  /// 離島/資料缺漏 fallback：VillageGeofence 找不到任一點的里時，
  /// 自動退回距離衰減（effectiveRange）。
  static Future<bool> shouldForwardPacket({
    required int urgency,       // UrgencyLevel enum value (0–3)
    required int eventType,     // EventType enum value (0–7)
    required double originLat,  // 事件創建者的原始緯度（MeshEvent.origin_lat）
    required double originLng,  // 事件創建者的原始經度（MeshEvent.origin_lng）
    required double myLat,      // 本節點當前 GPS 緯度
    required double myLng,      // 本節點當前 GPS 經度
    required double maxRangeMeters,     // fallback 距離（來自 payload）
    required int senderIdentityLevel,
    required bool isHardwareMule,
    required bool isAndroidTier1Foreground,
  }) async {
    // ── 1. Tier 0 / Data Mule 豁免 ──────────────────────────────────
    if (isHardwareMule) return true;
    if (isAndroidTier1Foreground) return true;

    // ── 2. SOS_RED + 驗證用戶豁免（生死攸關，不受行政區邊界限制）──
    if (urgency == 3 && senderIdentityLevel >= 1) return true;

    // ── 3. 決定路由邊界層級 ─────────────────────────────────────────
    // urgency >= SOS_YELLOW (2) 或 HAZARD_MARKER (eventType=4) → 鄉鎮市區
    // 其餘（INFO / RESOURCE）→ 里
    final bool useTownshipRouting = urgency >= 2 || eventType == 4;

    // ── 4. Zone-Based 路由判斷 ──────────────────────────────────────
    final bool? inZone = useTownshipRouting
        ? await VillageGeofence.isSameTownshipZone(
            originLat, originLng, myLat, myLng)
        : await VillageGeofence.isSameVillageZone(
            originLat, originLng, myLat, myLng);

    if (inZone != null) {
      // 資料庫找到兩點的行政區 → 用 zone 結果
      return inZone;
    }

    // ── 5. Fallback：離島 / 資料缺漏 → 距離衰減 ────────────────────
    double effectiveRange = maxRangeMeters;
    if (urgency == 3) {
      effectiveRange *= 5.0; // 匿名 SOS_RED（identity=0）仍放寬 5 倍
    } else if (urgency == 2) {
      effectiveRange *= 5.0;
    } else if (urgency == 1) {
      effectiveRange *= 2.0;
    }

    final dist = _haversineM(originLat, originLng, myLat, myLng);
    return dist <= effectiveRange;
  }

  static double _haversineM(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// hex string → Uint8List (pub_key 欄位是 BLOB)
  static Uint8List _hexToBytes(String hex) {
    final len = hex.length ~/ 2;
    final result = Uint8List(len);
    for (var i = 0; i < len; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  /// 處理 Quarantine Vote 檢舉投票累加
  static Future<void> processQuarantineVote(
      String targetPubKeyHex, double voteWeight) async {
    final db = await DatabaseHelper().database;
    final pubKeyBlob = _hexToBytes(targetPubKeyHex);
    await db.execute('''
      UPDATE Local_Users
      SET quarantine_votes_weight = quarantine_votes_weight + ?
      WHERE pub_key = ?
    ''', [voteWeight, pubKeyBlob]);
    await db.execute('''
      UPDATE Local_Users
      SET is_blacklisted = 1
      WHERE pub_key = ? AND quarantine_votes_weight > 3.0
    ''', [pubKeyBlob]);
  }

  /// 檢查某公鑰是否已被黑名單
  static Future<bool> isBlacklisted(String pubKeyHex) async {
    final db = await DatabaseHelper().database;
    final pubKeyBlob = _hexToBytes(pubKeyHex);
    final result = await db.query(
      'Local_Users',
      columns: ['is_blacklisted'],
      where: 'pub_key = ? AND is_blacklisted = 1',
      whereArgs: [pubKeyBlob],
    );
    return result.isNotEmpty;
  }
}
