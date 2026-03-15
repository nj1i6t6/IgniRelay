import 'package:latlong2/latlong.dart';
import '../db/database_helper.dart';

class MeshRouter {
  /// 評估是否接受並轉發該封包 (Adaptive Geo-Fencing 核心邏輯)
  static Future<bool> shouldForwardPacket({
    required int urgency,
    required double receivedLat,
    required double receivedLng,
    required double originLat,
    required double originLng,
    required double maxRangeMeters,
    required int senderIdentityLevel,
    required bool isHardwareMule,
    required bool isAndroidTier1Foreground,
  }) async {
    // 有效的 maxRange（依據 urgency 放寬）
    double effectiveRange = maxRangeMeters;

    // 1. 第一層前置驗證 (Signature & Blacklist) 已在外部網路層做完。

    // 2. 第二層：SOS_RED 身分分級豁免
    if (urgency == 3) {
      // SOS_RED
      if (senderIdentityLevel >= 1) {
        // 等級 1 以上的手機認證用戶：無條件豁免距離限制，全功率擴散
        return true;
      } else {
        // 匿名用戶：放寬 5 倍距離
        effectiveRange *= 5.0;
      }
    } else if (urgency == 2) {
      // SOS_YELLOW
      effectiveRange *= 5.0;
    } else if (urgency == 1) {
      // RESOURCE
      effectiveRange *= 2.0;
    }
    // urgency == 0 (INFO)：不放寬

    // 3. 第三層：Tier 0 & Data Mule 特權豁免
    if (isHardwareMule) {
      return true; // 公務車(Tier 0) 永遠豁免
    }

    if (isAndroidTier1Foreground) {
      return true; // Android 掛載 Foreground Service 的 Data Mule 享有搬運豁免
    }

    // 4. 第四層：常規距離衰減計算
    final distance = const Distance();
    final meters = distance.as(
      LengthUnit.Meter,
      LatLng(originLat, originLng),
      LatLng(receivedLat, receivedLng),
    );

    return meters <= effectiveRange;
  }

  /// 處理 Quarantine Vote 檢舉投票累加
  /// targetPubKeyHex: 目標公鑰的 hex 字串
  static Future<void> processQuarantineVote(
      String targetPubKeyHex, double voteWeight) async {
    final db = await DatabaseHelper().database;

    // 使用 hex 字串比對（TEXT 欄位）
    await db.execute('''
      UPDATE Local_Users 
      SET quarantine_votes_weight = quarantine_votes_weight + ? 
      WHERE pub_key = ?
    ''', [voteWeight, targetPubKeyHex]);

    // 檢查是否超過 3.0 門檻 -> 直接設為黑名單
    await db.execute('''
      UPDATE Local_Users 
      SET is_blacklisted = 1 
      WHERE pub_key = ? AND quarantine_votes_weight > 3.0
    ''', [targetPubKeyHex]);
  }

  /// 檢查某公鑰是否已被黑名單
  static Future<bool> isBlacklisted(String pubKeyHex) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'Local_Users',
      columns: ['is_blacklisted'],
      where: 'pub_key = ? AND is_blacklisted = 1',
      whereArgs: [pubKeyHex],
    );
    return result.isNotEmpty;
  }
}
