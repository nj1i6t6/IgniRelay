import 'dart:typed_data';

import '../crypto/identity_manager.dart';
import '../db/database_helper.dart';
import '../geo/village_geofence.dart';
import '../mesh/event_manager.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import 'location_service.dart';

/// 媒合相關資料查詢 (Repository 層)
/// 負責 DB 讀取和 Protobuf 解碼，不含業務邏輯
class MatchRepository {
  final _db = DatabaseHelper();
  final _identity = IdentityManager();

  bool _samePubKey(Uint8List? a, Uint8List? b) {
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _normalizedDeliveryMode(String raw) {
    return raw == 'DELIVER' ? 'DELIVER' : 'PICKUP';
  }

  ({String mobilityMode, String note}) _decodeRequestDescription(String raw) {
    final parts = raw.split('|');
    final mobilityMode =
        parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : 'CAN_GO';
    final note = parts.length > 1 ? parts.sublist(1).join('|') : '';
    return (mobilityMode: mobilityMode, note: note);
  }

  Future<Map<String, dynamic>?> _findEventLog(String eventId) async {
    final db = await _db.database;
    final rows = await db.query(
      'Event_Logs',
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// 查詢所有可用的「我的」物資供給 (已解碼)
  Future<List<DecodedSupply>> getAvailableSupplies() async {
    final db = await _db.database;
    final myPubKey = Uint8List.fromList(await _identity.getPublicKeyBytes());
    final rows = await db.query(
      'Materials_State',
      where: 'status = ? AND provider_pub_key = ?',
      whereArgs: [MaterialStatus.available, myPubKey],
      orderBy: 'hlc_timestamp DESC',
    );

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
          deliveryMode: _normalizedDeliveryMode(rd.description),
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters > 0 ? rd.maxRangeMeters : 20000,
          providerPubKey: row['provider_pub_key'] as Uint8List?,
        ));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  /// 查詢所有他人的可用需求 (已解碼)
  Future<List<DecodedRequest>> getRequests({int limit = 50}) async {
    final db = await _db.database;
    final myPubKey = Uint8List.fromList(await _identity.getPublicKeyBytes());
    final rows = await db.query(
      'Requests_State',
      where: 'status = ? AND requester_pub_key != ?',
      whereArgs: [RequestStatus.available, myPubKey],
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
        final log = await _findEventLog(rd.requestId);
        final desc = _decodeRequestDescription(rd.description);
        results.add(DecodedRequest(
          eventId: rd.requestId,
          resourceType: rd.resourceType,
          quantityNeeded: rd.quantityNeeded,
          mobilityMode: desc.mobilityMode,
          note: desc.note,
          urgency: (log?['urgency'] as int?) ?? 1,
          identityLevel: (log?['identity_level'] as int?) ?? 0,
          hlcTimestamp: (row['hlc_timestamp'] as int?) ?? 0,
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters > 0 ? rd.maxRangeMeters : 20000,
          requesterPubKey: row['requester_pub_key'] as Uint8List?,
        ));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  /// 查詢自己的發布 (供給 + 需求)
  Future<List<MyPublish>> getMyPublishes({int limit = 20}) async {
    final db = await _db.database;
    final myPubKey = Uint8List.fromList(await _identity.getPublicKeyBytes());
    final results = <MyPublish>[];

    final supplyRows = await db.query(
      'Materials_State',
      where: 'provider_pub_key = ? AND status = ?',
      whereArgs: [myPubKey, MaterialStatus.available],
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );
    for (final row in supplyRows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;
      try {
        final rd = pb.ResourceData.fromBuffer(payload);
        var subtitle = '${rd.quantity.toInt()} 份';
        subtitle += _normalizedDeliveryMode(rd.description) == 'DELIVER'
            ? ' · 可協助送達'
            : ' · 需求者自取';
        results.add(MyPublish(
          eventId: rd.resourceId,
          isSupply: true,
          title: rd.resourceType,
          subtitle: subtitle,
          timestamp: (row['hlc_timestamp'] as int?) ?? 0,
        ));
      } catch (_) {}
    }

    final requestRows = await db.query(
      'Requests_State',
      where: 'requester_pub_key = ? AND status = ?',
      whereArgs: [myPubKey, RequestStatus.available],
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );
    for (final row in requestRows) {
      final payload = row['payload'] as Uint8List?;
      if (payload == null) continue;
      try {
        final rd = pb.RequestData.fromBuffer(payload);
        final desc = _decodeRequestDescription(rd.description);
        var subtitle = '${rd.quantityNeeded.toInt()} 份';
        subtitle +=
            desc.mobilityMode == 'NEED_DELIVER' ? ' · 需協助送達' : ' · 可自行前往';
        results.add(MyPublish(
          eventId: rd.requestId,
          isSupply: false,
          title: rd.resourceType,
          subtitle: subtitle,
          timestamp: (row['hlc_timestamp'] as int?) ?? 0,
        ));
      } catch (_) {}
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results.take(limit).toList();
  }

  /// 查詢別人的可用物資供給（需求者反向媒合用）
  Future<List<DecodedSupply>> getOthersSupplies() async {
    final db = await _db.database;
    final myPubKey = Uint8List.fromList(await _identity.getPublicKeyBytes());
    final rows = await db.query(
      'Materials_State',
      where: 'status = ? AND provider_pub_key != ?',
      whereArgs: [MaterialStatus.available, myPubKey],
      orderBy: 'hlc_timestamp DESC',
    );

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
          deliveryMode: _normalizedDeliveryMode(rd.description),
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters > 0 ? rd.maxRangeMeters : 20000,
          providerPubKey: row['provider_pub_key'] as Uint8List?,
        ));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  /// 查詢我自己發布的需求（反向媒合用）
  Future<List<DecodedRequest>> getMyRequests({int limit = 50}) async {
    final db = await _db.database;
    final myPubKey = Uint8List.fromList(await _identity.getPublicKeyBytes());
    final rows = await db.query(
      'Requests_State',
      where: 'requester_pub_key = ? AND status = ?',
      whereArgs: [myPubKey, RequestStatus.available],
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
        final log = await _findEventLog(rd.requestId);
        final desc = _decodeRequestDescription(rd.description);
        results.add(DecodedRequest(
          eventId: rd.requestId,
          resourceType: rd.resourceType,
          quantityNeeded: rd.quantityNeeded,
          mobilityMode: desc.mobilityMode,
          note: desc.note,
          urgency: (log?['urgency'] as int?) ?? 1,
          identityLevel: (log?['identity_level'] as int?) ?? 0,
          hlcTimestamp: (row['hlc_timestamp'] as int?) ?? 0,
          lat: rd.lat != 0 ? rd.lat : null,
          lng: rd.lng != 0 ? rd.lng : null,
          maxRangeMeters: rd.maxRangeMeters > 0 ? rd.maxRangeMeters : 20000,
          requesterPubKey: row['requester_pub_key'] as Uint8List?,
        ));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  Future<List<ActiveMatchSession>> getActiveSessions({int limit = 10}) async {
    final db = await _db.database;
    final myPubKey = Uint8List.fromList(await _identity.getPublicKeyBytes());
    final rows = await db.query(
      'Match_Sessions',
      where: 'status = ?',
      whereArgs: [MatchSessionStatus.active],
      orderBy: 'updated_at DESC',
      limit: limit,
    );

    final results = <ActiveMatchSession>[];
    for (final row in rows) {
      final resourceId = row['resource_id'] as String? ?? '';
      final requestId = row['request_id'] as String? ?? '';
      if (resourceId.isEmpty || requestId.isEmpty) continue;

      final supplyRows = await db.query(
        'Materials_State',
        where: 'resource_id = ?',
        whereArgs: [resourceId],
        limit: 1,
      );
      final requestRows = await db.query(
        'Requests_State',
        where: 'request_id = ?',
        whereArgs: [requestId],
        limit: 1,
      );
      if (supplyRows.isEmpty || requestRows.isEmpty) continue;

      final supplyPayload = supplyRows.first['payload'] as Uint8List?;
      final requestPayload = requestRows.first['payload'] as Uint8List?;
      if (supplyPayload == null || requestPayload == null) continue;

      try {
        final supply = pb.ResourceData.fromBuffer(supplyPayload);
        final request = pb.RequestData.fromBuffer(requestPayload);
        final desc = _decodeRequestDescription(request.description);
        final requestLog = await _findEventLog(requestId);
        final requesterPubKey = row['requester_pub_key'] as Uint8List?;
        final providerPubKey = row['provider_pub_key'] as Uint8List?;

        results.add(ActiveMatchSession(
          sessionId: row['session_id'] as String? ?? '$resourceId::$requestId',
          resourceId: resourceId,
          requestId: requestId,
          resourceType: supply.resourceType,
          requestResourceType: request.resourceType,
          requestDesc: desc.note.isNotEmpty ? desc.note : request.resourceType,
          urgency: (requestLog?['urgency'] as int?) ?? 1,
          deliveryMode: _normalizedDeliveryMode(supply.description),
          mobilityMode: desc.mobilityMode,
          supplyQty: supply.quantity,
          requestQty: request.quantityNeeded,
          requesterPubKey: requesterPubKey,
          providerPubKey: providerPubKey,
          lastRequesterLat: (row['last_requester_lat'] as num?)?.toDouble() ??
              (request.lat != 0 ? request.lat : null),
          lastRequesterLng: (row['last_requester_lng'] as num?)?.toDouble() ??
              (request.lng != 0 ? request.lng : null),
          lastProviderLat: (row['last_provider_lat'] as num?)?.toDouble() ??
              (supply.lat != 0 ? supply.lat : null),
          lastProviderLng: (row['last_provider_lng'] as num?)?.toDouble() ??
              (supply.lng != 0 ? supply.lng : null),
          updatedAt: (row['updated_at'] as int?) ?? 0,
          iAmRequester: _samePubKey(myPubKey, requesterPubKey),
        ));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  /// 查詢同里/同鄉鎮的他人供給與需求（社區動態）
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

    final matchedResourceIds = <String>{};
    try {
      final matchedRows = await db.query(
        'Materials_State',
        columns: ['resource_id'],
        where: "status IN ('PENDING', 'LOCKED', 'CONSUMED')",
      );
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

      if (originLat != null && originLng != null && myLoc != null) {
        final urgency = (row['urgency'] as int?) ?? 0;
        bool? inZone;
        if (urgency >= 2) {
          inZone = await VillageGeofence.isSameTownshipZone(
              originLat, originLng, myLoc.latitude, myLoc.longitude);
        } else {
          inZone = await VillageGeofence.isSameVillageZone(
              originLat, originLng, myLoc.latitude, myLoc.longitude);
        }
        if (inZone == false) continue;
      }

      if (isSupply) {
        try {
          final rd = pb.ResourceData.fromBuffer(payload);
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
          final desc = _decodeRequestDescription(rd.description);
          results.add(CommunityItem(
            eventId: (row['event_id'] as String?) ?? '',
            isSupply: false,
            resourceType: rd.resourceType,
            quantity: rd.quantityNeeded,
            description: desc.note,
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
  final Uint8List? providerPubKey;

  const DecodedSupply({
    required this.resourceId,
    required this.resourceType,
    required this.quantity,
    required this.deliveryMode,
    this.lat,
    this.lng,
    this.maxRangeMeters = 20000,
    this.providerPubKey,
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
  final Uint8List? requesterPubKey;

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
    this.requesterPubKey,
  });
}

class ActiveMatchSession {
  final String sessionId;
  final String resourceId;
  final String requestId;
  final String resourceType;
  final String requestResourceType;
  final String requestDesc;
  final int urgency;
  final String deliveryMode;
  final String mobilityMode;
  final double supplyQty;
  final double requestQty;
  final Uint8List? requesterPubKey;
  final Uint8List? providerPubKey;
  final double? lastRequesterLat;
  final double? lastRequesterLng;
  final double? lastProviderLat;
  final double? lastProviderLng;
  final int updatedAt;
  final bool iAmRequester;

  const ActiveMatchSession({
    required this.sessionId,
    required this.resourceId,
    required this.requestId,
    required this.resourceType,
    required this.requestResourceType,
    required this.requestDesc,
    required this.urgency,
    required this.deliveryMode,
    required this.mobilityMode,
    required this.supplyQty,
    required this.requestQty,
    this.requesterPubKey,
    this.providerPubKey,
    this.lastRequesterLat,
    this.lastRequesterLng,
    this.lastProviderLat,
    this.lastProviderLng,
    required this.updatedAt,
    required this.iAmRequester,
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
