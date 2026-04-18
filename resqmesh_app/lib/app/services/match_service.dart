import 'package:latlong2/latlong.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';

// ── 媒合評分權重常數 ─────────────────────────────────────────────
/// 各因子在 100 分中的比重
/// 決策依據：災難環境中，物資是否真正能送到（fulfillment + delivery）
/// 比距離和信任更關鍵；緊急程度用於優先排序
class MatchWeights {
  static const double fulfillment = 40; // 數量滿足率
  static const double urgency = 30; // 緊急程度
  static const double distance = 15; // 地理距離
  static const double trust = 15; // 身份信任等級

  /// 滿足率下限 (< 30% 不配對)
  static const double minFulfillment = 0.3;
}

/// 媒合結果條目
class MatchEntry {
  final String resourceId;
  final String resourceType;
  final String requestResourceType;
  final String requestDesc;
  final String requestEventId;
  final String requestId; // RequestData.requestId（用於媒合協議）
  final int urgency;
  final int identityLevel;
  final double score;
  final int hlcTimestamp;
  final double supplyQty;
  final double requestQty;
  final String deliveryMode;
  final String mobilityMode;
  final double fulfillmentRatio;
  final double distanceMeters;
  final double? supplyLat;
  final double? supplyLng;
  final double? requestLat;
  final double? requestLng;
  final List<int>? requesterPubKey; // 需求者公鑰（供給者發起媒合用）
  final List<int>? providerPubKey; // 供給者公鑰（需求者確認媒合用）

  const MatchEntry({
    required this.resourceId,
    required this.resourceType,
    required this.requestResourceType,
    required this.requestDesc,
    required this.requestEventId,
    this.requestId = '',
    required this.urgency,
    required this.identityLevel,
    required this.score,
    required this.hlcTimestamp,
    required this.supplyQty,
    required this.requestQty,
    required this.deliveryMode,
    required this.mobilityMode,
    required this.fulfillmentRatio,
    required this.distanceMeters,
    this.supplyLat,
    this.supplyLng,
    this.requestLat,
    this.requestLng,
    this.requesterPubKey,
    this.providerPubKey,
  });
}

/// 媒合結果（含正向與反向）
class MatchResult {
  final List<MatchEntry> outboundMatches; // 我能幫誰
  final List<MatchEntry> inboundMatches; // 誰能幫我

  const MatchResult({
    required this.outboundMatches,
    required this.inboundMatches,
  });
}

/// 純媒合邏輯 (不碰 DB、不碰 UI)
class MatchService {
  final LocationService _location;

  MatchService({LocationService? locationService})
      : _location = locationService ?? LocationService();

  /// 執行完整媒合：正向（我能幫誰）+ 反向（誰能幫我）
  MatchResult computeFullMatches({
    required List<DecodedSupply> mySupplies,
    required List<DecodedRequest> allRequests,
    required List<DecodedSupply> othersSupplies,
    required List<DecodedRequest> myRequests,
  }) {
    final outbound = computeMatches(mySupplies, allRequests);
    final inbound = computeMatches(othersSupplies, myRequests);
    return MatchResult(outboundMatches: outbound, inboundMatches: inbound);
  }

  /// 執行媒合：將供給與需求做 cross-join，過濾+評分
  List<MatchEntry> computeMatches(
    List<DecodedSupply> supplies,
    List<DecodedRequest> requests,
  ) {
    final userLoc = _location.currentLocation;
    final entries = <MatchEntry>[];

    for (final supply in supplies) {
      for (final req in requests) {
        // ① 品項層級比對
        if (!resourceTypeMatches(supply.resourceType, req.resourceType)) {
          continue;
        }

        // ② 行動模式相容性
        if (!mobilityCompatible(supply.deliveryMode, req.mobilityMode)) {
          continue;
        }

        // ③ 數量滿足率
        final fulfillment = req.quantityNeeded > 0
            ? (supply.quantity / req.quantityNeeded).clamp(0.0, 1.0)
            : 1.0;
        if (fulfillment < MatchWeights.minFulfillment) continue;

        // ④ 真實距離計算
        double distMeters = -1; // 無法計算
        if (supply.lat != null &&
            supply.lng != null &&
            req.lat != null &&
            req.lng != null) {
          distMeters = LocationService.haversineMeters(
            LatLng(supply.lat!, supply.lng!),
            LatLng(req.lat!, req.lng!),
          );
        } else if (userLoc != null) {
          // fallback: 從使用者到另一方
          if (req.lat != null && req.lng != null) {
            distMeters = LocationService.haversineMeters(
                userLoc, LatLng(req.lat!, req.lng!));
          } else if (supply.lat != null && supply.lng != null) {
            distMeters = LocationService.haversineMeters(
                userLoc, LatLng(supply.lat!, supply.lng!));
          }
        }

        final maxRange = (supply.maxRangeMeters > req.maxRangeMeters)
            ? supply.maxRangeMeters
            : req.maxRangeMeters;
        final distNorm = distMeters >= 0
            ? LocationService.normalizeDistance(distMeters, maxRange: maxRange)
            : 0.5; // 無座標時的預設

        // ⑤ 評分
        final score = matchScore(
          urgency: req.urgency,
          fulfillment: fulfillment,
          distanceNorm: distNorm,
          trustNorm: (req.identityLevel / 3.0).clamp(0.0, 1.0),
        );

        final reqDesc = req.note.isNotEmpty ? req.note : req.resourceType;

        entries.add(MatchEntry(
          resourceId: supply.resourceId,
          resourceType: supply.resourceType,
          requestResourceType: req.resourceType,
          requestDesc: reqDesc,
          requestEventId: req.eventId,
          requestId: req.requestId,
          urgency: req.urgency,
          identityLevel: req.identityLevel,
          score: score,
          hlcTimestamp: req.hlcTimestamp,
          supplyQty: supply.quantity,
          requestQty: req.quantityNeeded,
          deliveryMode: supply.deliveryMode,
          mobilityMode: req.mobilityMode,
          fulfillmentRatio: fulfillment,
          distanceMeters: distMeters,
          supplyLat: supply.lat,
          supplyLng: supply.lng,
          requestLat: req.lat,
          requestLng: req.lng,
          requesterPubKey: req.senderPubKey,
          providerPubKey: supply.senderPubKey,
        ));
      }
    }

    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }

  // ── 品項層級比對 ──────────────────────────────────────────────
  /// 規則：至少子分類 (level 2) 要相同
  ///        若雙方都指定到 level 3，則 item code 必須相同
  static bool resourceTypeMatches(String supplyType, String reqType) {
    final sParts = supplyType.split('/');
    final rParts = reqType.split('/');

    // Level 1 (大類) 必須相同
    if (sParts.isEmpty || rParts.isEmpty) return false;
    if (sParts[0] != rParts[0]) return false;

    // Level 2 (子類) 必須相同
    if (sParts.length < 2 || rParts.length < 2) return false;
    if (sParts[1] != rParts[1]) return false;

    // Level 3 (具體品項) — 若雙方都指定，必須相同
    if (sParts.length >= 3 && rParts.length >= 3) {
      return sParts[2] == rParts[2];
    }
    return true;
  }

  // ── 行動模式相容性 ────────────────────────────────────────────
  /// PICKUP + CAN_GO = ✅  DELIVER + CAN_GO = ✅  DELIVER + NEED_DELIVER = ✅
  /// PICKUP + NEED_DELIVER = ❌
  static bool mobilityCompatible(String supplyMode, String demandMode) {
    // DROP_OFF only compatible with DROP_OFF
    if (supplyMode == 'DROP_OFF' || demandMode == 'DROP_OFF') {
      return supplyMode == 'DROP_OFF' && demandMode == 'DROP_OFF';
    }
    // PICKUP + NEED_DELIVER is the only incompatible pair
    if (supplyMode == 'PICKUP' && demandMode == 'NEED_DELIVER') return false;
    return true;
  }

  // ── 評分公式 ──────────────────────────────────────────────────
  static double matchScore({
    required int urgency,
    required double fulfillment,
    required double distanceNorm,
    required double trustNorm,
  }) {
    final u = urgency / 3.0;
    return (u * MatchWeights.urgency) +
        (fulfillment * MatchWeights.fulfillment) +
        (distanceNorm * MatchWeights.distance) +
        (trustNorm * MatchWeights.trust);
  }
}
