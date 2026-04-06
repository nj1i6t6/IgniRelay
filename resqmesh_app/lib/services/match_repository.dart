import 'dart:typed_data';
import '../db/database_helper.dart';
import '../geo/village_geofence.dart';
import '../mesh/event_manager.dart';
import '../crypto/identity_manager.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import 'location_service.dart';
import 'negotiation_manager.dart';
import 'negotiation_repo.dart';

/// 媒合相關資料查詢 (Repository 層)
/// 負責 DB 讀取和 Protobuf 解碼，不含業務邏輯
/// 使用 Match_Negotiations 取代舊 Match_Sessions
class MatchRepository {
  final _db = DatabaseHelper();
  final _identity = IdentityManager();
  final _eventManager = EventManager();
  final _negotiationRepo = NegotiationRepo();
  final _negotiationManager = NegotiationManager();

  /// 查詢所有可用的物資供給 (已解碼)
  /// 從 Materials_State 讀取 total_qty, delivery_mode
  /// 狀態篩選: AVAILABLE 或 DEPLETED
  Future<List<DecodedSupply>> getAvailableSupplies() async {
    final db = await _db.database;
    final rows = await db.query(
      'Materials_State',
      where: "status IN ('AVAILABLE', 'DEPLETED')",
      orderBy: 'hlc_timestamp DESC',
    );

    final results = <DecodedSupply>[];
    for (final row in rows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;

      final resourceId = row['resource_id'] as String;
      final totalQty = (row['total_qty'] as num?)?.toDouble() ?? 0.0;
      final deliveryMode = (row['delivery_mode'] as String?) ?? 'PICKUP';

      try {
        final rd = pb.ResourceData.fromBuffer(payload);
        final availableQty =
            await _negotiationRepo.computeAvailableQty(resourceId);

        results.add(DecodedSupply(
          resourceId: resourceId,
          resourceType: rd.resourceType,
          quantity: totalQty > 0 ? totalQty : rd.quantity,
          availableQty: availableQty,
          deliveryMode: deliveryMode,
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters,
          unit: rd.unit.isNotEmpty ? rd.unit : '份',
        ));
      } catch (e) {
        // 無法解碼 protobuf，跳過
        continue;
      }
    }
    return results;
  }

  /// 查詢所有物資需求 (已解碼)
  /// 從 Requests_State 讀取 quantity_needed, mobility_mode, note
  /// 狀態篩選: OPEN 或 MATCHED
  Future<List<DecodedRequest>> getRequests({int limit = 50}) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT r.request_id, r.event_id, r.sender_pub_key, r.status,
             r.hlc_timestamp, r.quantity_needed, r.mobility_mode, r.note,
             r.payload, e.urgency, e.identity_level
      FROM Requests_State r
      LEFT JOIN Event_Logs e ON r.event_id = e.event_id
      WHERE r.status IN ('OPEN', 'MATCHED')
      ORDER BY r.hlc_timestamp DESC
      LIMIT ?
    ''', [limit]);

    final results = <DecodedRequest>[];
    for (final row in rows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;

      final requestId = (row['request_id'] as String?) ?? '';
      final stateQty = (row['quantity_needed'] as num?)?.toDouble();
      final stateMobility = row['mobility_mode'] as String?;
      final stateNote = row['note'] as String?;

      try {
        final rd = pb.RequestData.fromBuffer(payload);
        if (rd.resourceType.isEmpty) continue;

        // 優先使用 Requests_State 欄位，fallback 到 description 解析
        String mobilityMode;
        String note;
        if (stateMobility != null && stateMobility.isNotEmpty) {
          mobilityMode = stateMobility;
        } else {
          final descParts = rd.description.split('|');
          mobilityMode = descParts.isNotEmpty ? descParts[0] : 'CAN_GO';
        }
        if (stateNote != null && stateNote.isNotEmpty) {
          note = stateNote;
        } else {
          final descParts = rd.description.split('|');
          note = descParts.length > 1 ? descParts.sublist(1).join('|') : '';
        }

        final quantityNeeded = stateQty ?? rd.quantityNeeded;
        final remainingNeed =
            await _negotiationRepo.computeRemainingNeed(requestId);

        results.add(DecodedRequest(
          eventId: (row['event_id'] as String?) ?? '',
          requestId: requestId,
          resourceType: rd.resourceType,
          quantityNeeded: quantityNeeded,
          remainingNeed: remainingNeed,
          mobilityMode: mobilityMode,
          note: note,
          urgency: (row['urgency'] as int?) ?? 0,
          identityLevel: (row['identity_level'] as int?) ?? 0,
          hlcTimestamp: (row['hlc_timestamp'] as int?) ?? 0,
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters,
          senderPubKey: (row['sender_pub_key'] as Uint8List?)?.toList(),
          status: (row['status'] as String?) ?? 'OPEN',
        ));
      } catch (_) {
        // 無法解碼或不是 RequestData，跳過
        continue;
      }
    }
    return results;
  }

  /// 查詢自己的發布 (供給 + 需求)，含協商狀態
  Future<List<MyPublish>> getMyPublishes({int limit = 20}) async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final myPubKey = Uint8List.fromList(pubKeyBytes);
    final db = await _db.database;

    final results = <MyPublish>[];

    // ── 供給部分：從 Materials_State JOIN Event_Logs ──
    final supplyRows = await db.rawQuery('''
      SELECT m.resource_id, m.status AS mat_status, m.total_qty,
             m.delivery_mode, m.payload, e.hlc_timestamp, e.event_id
      FROM Materials_State m
      JOIN Event_Logs e ON m.payload = e.payload AND e.event_type = ?
      WHERE e.sender_pub_key = ?
      ORDER BY e.hlc_timestamp DESC
      LIMIT ?
    ''', [EventType.resourceRegister, myPubKey, limit]);

    for (final row in supplyRows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;

      final resourceId = row['resource_id'] as String;
      final matStatus = (row['mat_status'] as String?) ?? 'AVAILABLE';

      // 跳過已消耗的
      if (matStatus == 'CONSUMED' || matStatus == 'CANCELLED') continue;

      try {
        final rd = pb.ResourceData.fromBuffer(payload);
        final totalQty = (row['total_qty'] as num?)?.toDouble() ?? rd.quantity;
        final deliveryMode =
            (row['delivery_mode'] as String?) ?? 'PICKUP';

        String title = rd.resourceType;
        String subtitle = '${totalQty.toInt()} 份';
        subtitle +=
            deliveryMode == 'DELIVER' ? ' · 可協助送達' : ' · 需求者自取';

        // 查詢協商數量
        final negotiations = await _negotiationRepo.getByResource(
          resourceId,
          statuses: ['PENDING', 'ACCEPTED', 'NAVIGATING'],
        );
        if (negotiations.isNotEmpty) {
          subtitle += ' · ${negotiations.length} 筆協商中';
        }

        results.add(MyPublish(
          eventId: (row['event_id'] as String?) ?? '',
          isSupply: true,
          title: title,
          subtitle: subtitle,
          timestamp: (row['hlc_timestamp'] as int?) ?? 0,
          status: matStatus,
        ));
      } catch (_) {
        continue;
      }
    }

    // ── 需求部分：從 Requests_State ──
    final requestRows = await db.rawQuery('''
      SELECT r.request_id, r.event_id, r.status, r.hlc_timestamp,
             r.quantity_needed, r.mobility_mode, r.note, r.payload
      FROM Requests_State r
      WHERE r.sender_pub_key = ?
      ORDER BY r.hlc_timestamp DESC
      LIMIT ?
    ''', [myPubKey, limit]);

    for (final row in requestRows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;

      final requestId = (row['request_id'] as String?) ?? '';
      final reqStatus = (row['status'] as String?) ?? 'OPEN';

      // 跳過已取消/已滿足的
      if (reqStatus == 'CANCELLED' || reqStatus == 'FULFILLED') continue;

      try {
        final rd = pb.RequestData.fromBuffer(payload);
        if (rd.resourceType.isEmpty) continue;

        final qtyNeeded =
            (row['quantity_needed'] as num?)?.toDouble() ?? rd.quantityNeeded;
        final mobilityMode =
            (row['mobility_mode'] as String?) ??
            (rd.description.split('|').isNotEmpty
                ? rd.description.split('|')[0]
                : 'CAN_GO');

        String title = rd.resourceType;
        String subtitle = '${qtyNeeded.toInt()} 份';
        subtitle +=
            mobilityMode == 'NEED_DELIVER' ? ' · 需協助送達' : ' · 可自行前往';

        // 查詢協商數量
        final negotiations = await _negotiationRepo.getByRequest(
          requestId,
          statuses: ['PENDING', 'ACCEPTED', 'NAVIGATING'],
        );
        if (negotiations.isNotEmpty) {
          subtitle += ' · ${negotiations.length} 筆協商中';
        }

        results.add(MyPublish(
          eventId: (row['event_id'] as String?) ?? '',
          isSupply: false,
          title: title,
          subtitle: subtitle,
          timestamp: (row['hlc_timestamp'] as int?) ?? 0,
          status: reqStatus,
        ));
      } catch (_) {
        continue;
      }
    }

    // 按時間排序
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// 查詢別人的可用物資供給（需求者反向媒合用）
  /// 使用 Materials_State 的 total_qty, delivery_mode 欄位
  Future<List<DecodedSupply>> getOthersSupplies() async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final myPubKey = Uint8List.fromList(pubKeyBytes);
    final db = await _db.database;

    final rows = await db.rawQuery('''
      SELECT m.resource_id, m.total_qty, m.delivery_mode, m.payload,
             e.sender_pub_key
      FROM Materials_State m
      JOIN Event_Logs e ON m.payload = e.payload AND e.event_type = ?
      WHERE m.status = 'AVAILABLE' AND e.sender_pub_key != ?
    ''', [EventType.resourceRegister, myPubKey]);

    final results = <DecodedSupply>[];
    final seenIds = <String>{};
    for (final row in rows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;

      final resourceId = (row['resource_id'] as String?) ?? '';
      if (seenIds.contains(resourceId)) continue;
      seenIds.add(resourceId);

      try {
        final rd = pb.ResourceData.fromBuffer(payload);
        final totalQty = (row['total_qty'] as num?)?.toDouble() ?? rd.quantity;
        final deliveryMode =
            (row['delivery_mode'] as String?) ?? 'PICKUP';
        final availableQty =
            await _negotiationRepo.computeAvailableQty(resourceId);

        results.add(DecodedSupply(
          resourceId: resourceId,
          resourceType: rd.resourceType,
          quantity: totalQty,
          availableQty: availableQty,
          deliveryMode: deliveryMode,
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters,
          senderPubKey: (row['sender_pub_key'] as Uint8List?)?.toList(),
          unit: rd.unit.isNotEmpty ? rd.unit : '份',
        ));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  /// 查詢我自己發布的需求（反向媒合用）
  /// 直接從 Requests_State 讀取新欄位
  Future<List<DecodedRequest>> getMyRequests({int limit = 50}) async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final myPubKey = Uint8List.fromList(pubKeyBytes);
    final db = await _db.database;

    final rows = await db.rawQuery('''
      SELECT r.request_id, r.event_id, r.sender_pub_key, r.status,
             r.hlc_timestamp, r.quantity_needed, r.mobility_mode, r.note,
             r.payload, e.urgency, e.identity_level
      FROM Requests_State r
      LEFT JOIN Event_Logs e ON r.event_id = e.event_id
      WHERE r.sender_pub_key = ? AND r.status IN ('OPEN', 'MATCHED')
      ORDER BY r.hlc_timestamp DESC
      LIMIT ?
    ''', [myPubKey, limit]);

    final results = <DecodedRequest>[];
    for (final row in rows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;

      final requestId = (row['request_id'] as String?) ?? '';
      final stateQty = (row['quantity_needed'] as num?)?.toDouble();
      final stateMobility = row['mobility_mode'] as String?;
      final stateNote = row['note'] as String?;

      try {
        final rd = pb.RequestData.fromBuffer(payload);
        if (rd.resourceType.isEmpty) continue;

        // 優先使用 Requests_State 欄位，fallback 到 description 解析
        String mobilityMode;
        String note;
        if (stateMobility != null && stateMobility.isNotEmpty) {
          mobilityMode = stateMobility;
        } else {
          final descParts = rd.description.split('|');
          mobilityMode = descParts.isNotEmpty ? descParts[0] : 'CAN_GO';
        }
        if (stateNote != null && stateNote.isNotEmpty) {
          note = stateNote;
        } else {
          final descParts = rd.description.split('|');
          note = descParts.length > 1 ? descParts.sublist(1).join('|') : '';
        }

        final quantityNeeded = stateQty ?? rd.quantityNeeded;
        final remainingNeed =
            await _negotiationRepo.computeRemainingNeed(requestId);

        results.add(DecodedRequest(
          eventId: (row['event_id'] as String?) ?? '',
          requestId: requestId,
          resourceType: rd.resourceType,
          quantityNeeded: quantityNeeded,
          remainingNeed: remainingNeed,
          mobilityMode: mobilityMode,
          note: note,
          urgency: (row['urgency'] as int?) ?? 0,
          identityLevel: (row['identity_level'] as int?) ?? 0,
          hlcTimestamp: (row['hlc_timestamp'] as int?) ?? 0,
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters,
          senderPubKey: (row['sender_pub_key'] as Uint8List?)?.toList(),
          status: (row['status'] as String?) ?? 'OPEN',
        ));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  /// 查詢同里/同鄉鎮的他人供給與需求（社區動態）
  ///
  /// 篩選邏輯：
  /// - sender_pub_key != 自己
  /// - event_type = RESOURCE_REGISTER 或 REQUEST_BROADCAST
  /// - 24 小時內
  /// - origin_lat/origin_lng 與我同里（物資）或同鄉鎮（SOS）
  /// - 排除已消耗/已取消的物資 (透過 Materials_State/Requests_State)
  Future<List<CommunityItem>> getCommunityItems({int limit = 50}) async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final myPubKey = Uint8List.fromList(pubKeyBytes);
    final db = await _db.database;
    final cutoff24h =
        DateTime.now().millisecondsSinceEpoch - (24 * 3600 * 1000);

    final rows = await db.query(
      'Event_Logs',
      where:
          'sender_pub_key != ? AND (event_type = ? OR event_type = ?) AND urgency <= 1 AND hlc_timestamp > ?',
      whereArgs: [
        myPubKey,
        EventType.resourceRegister,
        EventType.requestBroadcast,
        cutoff24h,
      ],
      orderBy: 'urgency DESC, hlc_timestamp DESC',
      limit: limit,
    );

    // 取得已消耗/取消的 resource_id，從社群動態排除
    final excludedResourceIds = <String>{};
    try {
      final excludedRows = await db.query('Materials_State',
          columns: ['resource_id'],
          where: "status IN ('CONSUMED', 'CANCELLED')");
      for (final r in excludedRows) {
        final rid = r['resource_id'] as String?;
        if (rid != null) excludedResourceIds.add(rid);
      }
    } catch (_) {}

    // 取得已取消/已滿足的 request_id
    final excludedRequestIds = <String>{};
    try {
      final excludedReqs = await db.query('Requests_State',
          columns: ['request_id'],
          where: "status IN ('CANCELLED', 'FULFILLED')");
      for (final r in excludedReqs) {
        final rid = r['request_id'] as String?;
        if (rid != null) excludedRequestIds.add(rid);
      }
    } catch (_) {}

    final myLoc = LocationService().currentLocation;
    final results = <CommunityItem>[];

    for (final row in rows) {
      final eventType = (row['event_type'] as int?) ?? 0;
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;

      final isSupply = eventType == EventType.resourceRegister;
      final originLat = (row['origin_lat'] as num?)?.toDouble();
      final originLng = (row['origin_lng'] as num?)?.toDouble();

      // 地理圍欄篩選：有座標時檢查是否同里
      if (originLat != null && originLng != null && myLoc != null) {
        final urgency = (row['urgency'] as int?) ?? 0;
        bool? inZone;
        if (urgency >= 2) {
          // SOS 等級 → 鄉鎮範圍
          inZone = await VillageGeofence.isSameTownshipZone(
              originLat, originLng, myLoc.latitude, myLoc.longitude);
        } else {
          // 一般物資 → 同里範圍
          inZone = await VillageGeofence.isSameVillageZone(
              originLat, originLng, myLoc.latitude, myLoc.longitude);
        }
        // inZone == null → 查不到里（離島/缺漏），放行
        // inZone == false → 不同區域，跳過
        if (inZone == false) continue;
      }

      if (isSupply) {
        try {
          final rd = pb.ResourceData.fromBuffer(payload);
          // 排除已消耗/已取消的物資
          if (excludedResourceIds.contains(rd.resourceId)) continue;
          results.add(CommunityItem(
            eventId: (row['event_id'] as String?) ?? '',
            isSupply: true,
            resourceType: rd.resourceType,
            quantity: rd.quantity,
            description: rd.description,
            urgency: (row['urgency'] as int?) ?? 0,
            identityLevel: (row['identity_level'] as int?) ?? 0,
            timestamp: (row['hlc_timestamp'] as int?) ?? 0,
            lat: rd.lat != 0 ? rd.lat : null,
            lng: rd.lng != 0 ? rd.lng : null,
          ));
        } catch (_) {
          continue;
        }
      } else {
        try {
          final rd = pb.RequestData.fromBuffer(payload);
          if (rd.resourceType.isEmpty) continue;
          // 排除已取消/已滿足的需求
          if (excludedRequestIds.contains(rd.requestId)) continue;

          final descParts = rd.description.split('|');
          final note =
              descParts.length > 1 ? descParts.sublist(1).join('|') : '';

          results.add(CommunityItem(
            eventId: (row['event_id'] as String?) ?? '',
            isSupply: false,
            resourceType: rd.resourceType,
            quantity: rd.quantityNeeded,
            description: note,
            urgency: (row['urgency'] as int?) ?? 0,
            identityLevel: (row['identity_level'] as int?) ?? 0,
            timestamp: (row['hlc_timestamp'] as int?) ?? 0,
            lat: rd.lat != 0 ? rd.lat : null,
            lng: rd.lng != 0 ? rd.lng : null,
          ));
        } catch (_) {
          continue;
        }
      }
    }
    return results;
  }
}

// ── 資料模型 ─────────────────────────────────────────────────────

class DecodedSupply {
  final String resourceId;
  final String resourceType;
  final double quantity;
  final double availableQty;
  final String deliveryMode;
  final double? lat;
  final double? lng;
  final double maxRangeMeters;
  final List<int>? senderPubKey;
  final String unit;

  const DecodedSupply({
    required this.resourceId,
    required this.resourceType,
    required this.quantity,
    required this.availableQty,
    required this.deliveryMode,
    this.lat,
    this.lng,
    this.maxRangeMeters = 20000,
    this.senderPubKey,
    this.unit = '份',
  });
}

class DecodedRequest {
  final String eventId;
  final String requestId;
  final String resourceType;
  final double quantityNeeded;
  final double remainingNeed;
  final String mobilityMode;
  final String note;
  final int urgency;
  final int identityLevel;
  final int hlcTimestamp;
  final double? lat;
  final double? lng;
  final double maxRangeMeters;
  final List<int>? senderPubKey;
  final String status;

  const DecodedRequest({
    required this.eventId,
    this.requestId = '',
    required this.resourceType,
    required this.quantityNeeded,
    this.remainingNeed = 0.0,
    required this.mobilityMode,
    required this.note,
    required this.urgency,
    required this.identityLevel,
    required this.hlcTimestamp,
    this.lat,
    this.lng,
    this.maxRangeMeters = 20000,
    this.senderPubKey,
    this.status = 'OPEN',
  });
}

class MyPublish {
  final String eventId;
  final bool isSupply;
  final String title;
  final String subtitle;
  final int timestamp;
  final String status;

  const MyPublish({
    required this.eventId,
    required this.isSupply,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.status = '',
  });
}

/// 社區動態項目（他人透過 Mesh 同步過來的供給/需求）
class CommunityItem {
  final String eventId;
  final bool isSupply;
  final String resourceType;
  final double quantity;
  final String description;
  final int urgency;
  final int identityLevel;
  final int timestamp;
  final double? lat;
  final double? lng;

  const CommunityItem({
    required this.eventId,
    required this.isSupply,
    required this.resourceType,
    required this.quantity,
    required this.description,
    required this.urgency,
    required this.identityLevel,
    required this.timestamp,
    this.lat,
    this.lng,
  });
}
