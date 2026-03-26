import 'dart:typed_data';
import '../db/database_helper.dart';
import '../geo/village_geofence.dart';
import '../mesh/event_manager.dart';
import '../crypto/identity_manager.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import 'location_service.dart';

/// 媒合相關資料查詢 (Repository 層)
/// 負責 DB 讀取和 Protobuf 解碼，不含業務邏輯
class MatchRepository {
  final _db = DatabaseHelper();
  final _identity = IdentityManager();
  final _eventManager = EventManager();

  /// 查詢所有可用的物資供給 (已解碼)
  Future<List<DecodedSupply>> getAvailableSupplies() async {
    final raw = await _eventManager.getAvailableSupplies();
    final results = <DecodedSupply>[];

    for (final row in raw) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;
      try {
        final rd = pb.ResourceData.fromBuffer(payload);
        results.add(DecodedSupply(
          resourceId: rd.resourceId,
          resourceType: rd.resourceType,
          quantity: rd.quantity,
          deliveryMode:
              (rd.description == 'PICKUP' || rd.description == 'DELIVER')
                  ? rd.description
                  : 'PICKUP',
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters,
        ));
      } catch (e) {
        // 無法解碼 protobuf，跳過
        continue;
      }
    }
    return results;
  }

  /// 查詢所有物資需求 (已解碼)
  Future<List<DecodedRequest>> getRequests({int limit = 50}) async {
    final db = await _db.database;
    final rows = await db.query(
      'Event_Logs',
      where: 'event_type = ?',
      whereArgs: [EventType.requestBroadcast],
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );

    final results = <DecodedRequest>[];
    for (final row in rows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;

      try {
        final rd = pb.RequestData.fromBuffer(payload);
        if (rd.resourceType.isEmpty) continue;

        final descParts = rd.description.split('|');
        final mode = descParts.isNotEmpty ? descParts[0] : 'CAN_GO';
        final note = descParts.length > 1 ? descParts.sublist(1).join('|') : '';

        results.add(DecodedRequest(
          eventId: (row['event_id'] as String?) ?? '',
          resourceType: rd.resourceType,
          quantityNeeded: rd.quantityNeeded,
          mobilityMode: mode,
          note: note,
          urgency: (row['urgency'] as int?) ?? 0,
          identityLevel: (row['identity_level'] as int?) ?? 0,
          hlcTimestamp: (row['hlc_timestamp'] as int?) ?? 0,
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters,
        ));
      } catch (_) {
        // 無法解碼或不是 RequestData，跳過
        continue;
      }
    }
    return results;
  }

  /// 查詢自己的發布 (供給 + 需求)
  Future<List<MyPublish>> getMyPublishes({int limit = 20}) async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final myPubKey = Uint8List.fromList(pubKeyBytes);
    final db = await _db.database;

    final rows = await db.query(
      'Event_Logs',
      where: 'sender_pub_key = ? AND (event_type = ? OR event_type = ?)',
      whereArgs: [
        myPubKey,
        EventType.resourceRegister,
        EventType.requestBroadcast
      ],
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );

    final results = <MyPublish>[];
    for (final row in rows) {
      final eventType = (row['event_type'] as int?) ?? 0;
      final payload = row['payload'] as Uint8List?;
      final hlcTs = (row['hlc_timestamp'] as int?) ?? 0;
      final eventId = (row['event_id'] as String?) ?? '';
      final isSupply = eventType == EventType.resourceRegister;

      String title = '';
      String subtitle = '';

      if (isSupply && payload != null) {
        try {
          final rd = pb.ResourceData.fromBuffer(payload);
          title = rd.resourceType; // 由 UI 層用 getReadableName 轉換
          subtitle = '${rd.quantity.toInt()} 份';
          subtitle += rd.description == 'DELIVER' ? ' · 可協助送達' : ' · 需求者自取';

          // 檢查是否已鎖定/消耗
          final matState = await db.query('Materials_State',
              where: 'resource_id = ?', whereArgs: [rd.resourceId]);
          if (matState.isNotEmpty) {
            final status = matState.first['status'] as String?;
            if (status == 'LOCKED' || status == 'CONSUMED') continue;
          }
        } catch (_) {
          title = 'UNKNOWN_SUPPLY';
        }
      } else if (!isSupply && payload != null) {
        try {
          final rd = pb.RequestData.fromBuffer(payload);
          if (rd.resourceType.isEmpty) continue;
          title = rd.resourceType;
          subtitle = '${rd.quantityNeeded.toInt()} 份';
          final parts = rd.description.split('|');
          final mode = parts.isNotEmpty ? parts[0] : 'CAN_GO';
          subtitle += mode == 'NEED_DELIVER' ? ' · 需協助送達' : ' · 可自行前往';
        } catch (_) {
          continue;
        }
      }

      results.add(MyPublish(
        eventId: eventId,
        isSupply: isSupply,
        title: title,
        subtitle: subtitle,
        timestamp: hlcTs,
      ));
    }
    return results;
  }

  /// 查詢別人的可用物資供給（需求者反向媒合用）
  Future<List<DecodedSupply>> getOthersSupplies() async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final myPubKey = Uint8List.fromList(pubKeyBytes);
    final db = await _db.database;

    // 查詢 Materials_State AVAILABLE 且 sender 不是自己的
    final rows = await db.rawQuery('''
      SELECT m.resource_id, m.payload
      FROM Materials_State m
      JOIN Event_Logs e ON m.payload = e.payload AND e.event_type = 0
      WHERE m.status = 'AVAILABLE' AND e.sender_pub_key != ?
    ''', [myPubKey]);

    final results = <DecodedSupply>[];
    for (final row in rows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;
      try {
        final rd = pb.ResourceData.fromBuffer(payload);
        results.add(DecodedSupply(
          resourceId: rd.resourceId,
          resourceType: rd.resourceType,
          quantity: rd.quantity,
          deliveryMode:
              (rd.description == 'PICKUP' || rd.description == 'DELIVER')
                  ? rd.description
                  : 'PICKUP',
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters,
        ));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  /// 查詢我自己發布的需求（反向媒合用）
  Future<List<DecodedRequest>> getMyRequests({int limit = 50}) async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final myPubKey = Uint8List.fromList(pubKeyBytes);
    final db = await _db.database;

    final rows = await db.query(
      'Event_Logs',
      where: 'sender_pub_key = ? AND event_type = ?',
      whereArgs: [myPubKey, EventType.requestBroadcast],
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );

    final results = <DecodedRequest>[];
    for (final row in rows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;
      try {
        final rd = pb.RequestData.fromBuffer(payload);
        if (rd.resourceType.isEmpty) continue;
        final descParts = rd.description.split('|');
        final mode = descParts.isNotEmpty ? descParts[0] : 'CAN_GO';
        final note =
            descParts.length > 1 ? descParts.sublist(1).join('|') : '';
        results.add(DecodedRequest(
          eventId: (row['event_id'] as String?) ?? '',
          resourceType: rd.resourceType,
          quantityNeeded: rd.quantityNeeded,
          mobilityMode: mode,
          note: note,
          urgency: (row['urgency'] as int?) ?? 0,
          identityLevel: (row['identity_level'] as int?) ?? 0,
          hlcTimestamp: (row['hlc_timestamp'] as int?) ?? 0,
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters,
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

    // 取得已配對的 resource_id，從社群動態排除
    final matchedResourceIds = <String>{};
    try {
      final matchedRows = await db.query('Materials_State',
          columns: ['resource_id'],
          where: "status IN ('PENDING', 'LOCKED', 'CONSUMED')");
      for (final r in matchedRows) {
        final rid = r['resource_id'] as String?;
        if (rid != null) matchedResourceIds.add(rid);
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
          // 排除已配對的物資
          if (matchedResourceIds.contains(rd.resourceId)) continue;
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
  final String deliveryMode;
  final double? lat;
  final double? lng;
  final double maxRangeMeters;

  const DecodedSupply({
    required this.resourceId,
    required this.resourceType,
    required this.quantity,
    required this.deliveryMode,
    this.lat,
    this.lng,
    this.maxRangeMeters = 20000,
  });
}

class DecodedRequest {
  final String eventId;
  final String resourceType;
  final double quantityNeeded;
  final String mobilityMode;
  final String note;
  final int urgency;
  final int identityLevel;
  final int hlcTimestamp;
  final double? lat;
  final double? lng;
  final double maxRangeMeters;

  const DecodedRequest({
    required this.eventId,
    required this.resourceType,
    required this.quantityNeeded,
    required this.mobilityMode,
    required this.note,
    required this.urgency,
    required this.identityLevel,
    required this.hlcTimestamp,
    this.lat,
    this.lng,
    this.maxRangeMeters = 20000,
  });
}

class MyPublish {
  final String eventId;
  final bool isSupply;
  final String title;
  final String subtitle;
  final int timestamp;

  const MyPublish({
    required this.eventId,
    required this.isSupply,
    required this.title,
    required this.subtitle,
    required this.timestamp,
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
