import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:ignirelay_app/app/crdt/hlc.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/crypto/signer.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/triage_queue.dart';

/// 危險標記管理器 — 從 EventManager 抽出的 Hazard CRUD 功能
class HazardManager {
  static final HazardManager _instance = HazardManager._internal();
  factory HazardManager() => _instance;
  HazardManager._internal();

  final _uuid = const Uuid();
  final _db = DatabaseHelper();
  final _identity = IdentityManager();
  TriageQueue get _queue => EventManager().queue;

  // ── 發布危險標記 ──────────────────────────────────────────────
  Future<String> publishHazard({
    required String type,
    required int severity,
    required double lat,
    required double lng,
    double radiusMeters = 200.0,
    String description = '',
  }) async {
    final hazardId = _uuid.v4();
    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    final hazardData = pb.HazardData()
      ..hazardId = hazardId
      ..hazardType = type
      ..severity = severity
      ..centerLat = lat
      ..centerLng = lng
      ..radiusMeters = radiusMeters.toDouble();
    if (description.isNotEmpty) hazardData.description = description;
    final payload = Uint8List.fromList(hazardData.writeToBuffer());
    final signature = await Signer.signEvent(
      eventId: eventId, eventType: EventType.hazardMarker, payload: payload,
    );

    final db = await _db.database;

    final reporterHex =
        pubKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await db.insert('Hazards_State', {
      'hazard_id': hazardId,
      'type': type,
      'severity': severity,
      'lat': lat,
      'lng': lng,
      'radius': radiusMeters,
      'reported_by': reporterHex,
      'created_at': hlc.timestamp,
      'confirm_count': 1,
      'description': description.isNotEmpty ? description : null,
      'updated_at': hlc.timestamp,
    });

    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.hazardMarker,
      'urgency': 2,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 8,
      'received_lat': lat,
      'received_lng': lng,
      'origin_lat': lat,
      'origin_lng': lng,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, 2, payload, eventType: EventType.hazardMarker));
    return hazardId;
  }

  // ── 確認（附議）他人危險標記 ─────────────────────────────────
  Future<void> confirmHazard(String hazardId) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.rawUpdate(
      'UPDATE Hazards_State SET confirm_count = confirm_count + 1, '
      'updated_at = ? WHERE hazard_id = ?',
      [now, hazardId],
    );

    final hazard = await db.query('Hazards_State',
        where: 'hazard_id = ?', whereArgs: [hazardId], limit: 1);
    if (hazard.isNotEmpty) {
      final h = hazard.first;
      final hazardData = pb.HazardData()
        ..hazardId = hazardId
        ..hazardType = (h['type'] as String?) ?? ''
        ..severity = (h['severity'] as int?) ?? 3
        ..centerLat = (h['lat'] as num?)?.toDouble() ?? 0
        ..centerLng = (h['lng'] as num?)?.toDouble() ?? 0
        ..radiusMeters = (h['radius'] as num?)?.toDouble() ?? 200
        ..isConfirmation = true;
      final payload = Uint8List.fromList(hazardData.writeToBuffer());
      final eventId = _uuid.v4();
      final hlc = HLC.now();
      final pubKeyBytes = await _identity.getPublicKeyBytes();
      final signature = await Signer.signEvent(
        eventId: eventId, eventType: EventType.hazardMarker, payload: payload,
      );
      await db.insert('Event_Logs', {
        'event_id': eventId,
        'sender_pub_key': Uint8List.fromList(pubKeyBytes),
        'identity_level': _identity.getIdentityLevel(),
        'event_type': EventType.hazardMarker,
        'urgency': 2,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
        'ttl': 8,
        'received_lat': h['lat'],
        'received_lng': h['lng'],
        'origin_lat': h['lat'],
        'origin_lng': h['lng'],
        'node_tier': 1,
        'chunk_index': 0,
        'total_chunks': 1,
        'payload': payload,
        'signature': Uint8List.fromList(signature),
        'is_synced': 0,
      });
      _queue.enqueue(MeshTask(eventId, 2, payload, eventType: EventType.hazardMarker));
    }
  }

  // ── 更新危險標記 ────────────────────────────────────────────
  Future<void> updateHazard(
    String hazardId, {
    String? type,
    int? severity,
    double? lat,
    double? lng,
    double? radiusMeters,
    String? description,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{'updated_at': now};
    if (type != null) updates['type'] = type;
    if (severity != null) updates['severity'] = severity;
    if (lat != null) updates['lat'] = lat;
    if (lng != null) updates['lng'] = lng;
    if (radiusMeters != null) updates['radius'] = radiusMeters;
    if (description != null) updates['description'] = description;
    await db.update('Hazards_State', updates,
        where: 'hazard_id = ?', whereArgs: [hazardId]);

    final updated = await db
        .query('Hazards_State', where: 'hazard_id = ?', whereArgs: [hazardId]);
    if (updated.isNotEmpty) {
      final h = updated.first;
      final hazardData = pb.HazardData()
        ..hazardId = hazardId
        ..hazardType = (h['type'] as String?) ?? ''
        ..severity = (h['severity'] as int?) ?? 3
        ..centerLat = (h['lat'] as num?)?.toDouble() ?? 0
        ..centerLng = (h['lng'] as num?)?.toDouble() ?? 0
        ..radiusMeters = (h['radius'] as num?)?.toDouble() ?? 200;
      final payload = Uint8List.fromList(hazardData.writeToBuffer());
      final eventId = _uuid.v4();
      final hlc = HLC.now();
      final pubKeyBytes = await _identity.getPublicKeyBytes();
      final signature = await Signer.signEvent(
        eventId: eventId, eventType: EventType.hazardMarker, payload: payload,
      );
      await db.insert('Event_Logs', {
        'event_id': eventId,
        'sender_pub_key': Uint8List.fromList(pubKeyBytes),
        'identity_level': _identity.getIdentityLevel(),
        'event_type': EventType.hazardMarker,
        'urgency': 2,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
        'ttl': 8,
        'received_lat': h['lat'],
        'received_lng': h['lng'],
        'origin_lat': h['lat'],
        'origin_lng': h['lng'],
        'node_tier': 1,
        'chunk_index': 0,
        'total_chunks': 1,
        'payload': payload,
        'signature': Uint8List.fromList(signature),
        'is_synced': 0,
      });
      _queue.enqueue(MeshTask(eventId, 2, payload, eventType: EventType.hazardMarker));
    }
  }

  // ── 刪除危險標記 ────────────────────────────────────────────
  Future<void> deleteHazard(String hazardId) async {
    final db = await _db.database;

    final existing = await db
        .query('Hazards_State', where: 'hazard_id = ?', whereArgs: [hazardId]);

    await db
        .delete('Hazards_State', where: 'hazard_id = ?', whereArgs: [hazardId]);

    if (existing.isNotEmpty) {
      final h = existing.first;
      final hazardData = pb.HazardData()
        ..hazardId = hazardId
        ..hazardType = (h['type'] as String?) ?? ''
        ..severity = 0
        ..centerLat = (h['lat'] as num?)?.toDouble() ?? 0
        ..centerLng = (h['lng'] as num?)?.toDouble() ?? 0
        ..radiusMeters = 0;
      final payload = Uint8List.fromList(hazardData.writeToBuffer());
      final eventId = _uuid.v4();
      final hlc = HLC.now();
      final pubKeyBytes = await _identity.getPublicKeyBytes();
      final signature = await Signer.signEvent(
        eventId: eventId, eventType: EventType.hazardMarker, payload: payload,
      );
      await db.insert('Event_Logs', {
        'event_id': eventId,
        'sender_pub_key': Uint8List.fromList(pubKeyBytes),
        'identity_level': _identity.getIdentityLevel(),
        'event_type': EventType.hazardMarker,
        'urgency': 0,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
        'ttl': 8,
        'received_lat': h['lat'],
        'received_lng': h['lng'],
        'origin_lat': h['lat'],
        'origin_lng': h['lng'],
        'node_tier': 1,
        'chunk_index': 0,
        'total_chunks': 1,
        'payload': payload,
        'signature': Uint8List.fromList(signature),
        'is_synced': 0,
      });
      _queue.enqueue(MeshTask(eventId, 0, payload, eventType: EventType.hazardMarker));
    }
  }

  // ── 查詢危險標記 ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getActiveHazards() async {
    final db = await _db.database;
    return await db.query('Hazards_State', orderBy: 'created_at DESC');
  }

  // ── 取得目前使用者的 reporter hex ───────────────────────────
  Future<String> getReporterHex() async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    return pubKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ── 搜尋附近同類型危險標記 ──────────────────────────────────
  Future<Map<String, dynamic>?> findNearbyHazard(
    double lat,
    double lng,
    String type, {
    double searchRadius = 500.0,
  }) async {
    final db = await _db.database;
    final hazards = await db.query(
      'Hazards_State',
      where: 'type = ?',
      whereArgs: [type],
    );
    Map<String, dynamic>? nearest;
    double nearestDist = double.infinity;
    for (final h in hazards) {
      final hLat = (h['lat'] as num).toDouble();
      final hLng = (h['lng'] as num).toDouble();
      final dist = _haversineMeters(lat, lng, hLat, hLng);
      if (dist < searchRadius && dist < nearestDist) {
        nearest = Map<String, dynamic>.from(h);
        nearest['_distance'] = dist;
        nearestDist = dist;
      }
    }
    return nearest;
  }

  static double _haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
