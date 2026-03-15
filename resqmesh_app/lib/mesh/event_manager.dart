import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../crdt/hlc.dart';
import '../crypto/identity_manager.dart';
import '../crypto/signer.dart';
import '../db/database_helper.dart';
import '../models/medical_card.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import 'triage_queue.dart';

// 事件類型常數（對應 Protobuf EventType enum）
class EventType {
  static const int resourceRegister = 0;
  static const int requestBroadcast = 1;
  static const int matchIntent = 2;
  static const int physicalHandshake = 3;
  static const int hazardMarker = 4;
  static const int quarantineVote = 5;
  static const int matchCancel = 6;
}

// 物資狀態常數
class MaterialStatus {
  static const String available = 'AVAILABLE';
  static const String pending = 'PENDING';
  static const String locked = 'LOCKED';
  static const String consumed = 'CONSUMED';
}

/// 速率限制例外
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  @override
  String toString() => 'RateLimitException: $message';
}

/// 統一的 MeshEvent 建立、簽名、DB 儲存中心
class EventManager {
  static final EventManager _instance = EventManager._internal();
  factory EventManager() => _instance;
  EventManager._internal();

  final _uuid = const Uuid();
  final _db = DatabaseHelper();
  final _identity = IdentityManager();
  final _queue = TriageQueue();

  TriageQueue get queue => _queue;

  // ── 速率限制 ────────────────────────────────────────────────────
  // 用 HLC 時間窗口（不依賴 wallclock）防止時鐘跳躍
  int _rateWindowStartHlc = 0;
  int _rateCount = 0;
  static const int _maxPerHour = 20;
  static const int _oneHourMs = 3600000;

  Future<void> _checkRateLimit() async {
    final now = HLC.now();
    if (now.timestamp - _rateWindowStartHlc > _oneHourMs) {
      _rateWindowStartHlc = now.timestamp;
      _rateCount = 0;
    }
    if (_rateCount >= _maxPerHour) {
      throw RateLimitException(
        '已達每小時上限 $_maxPerHour 次廣播，請稍後再試。',
      );
    }
    _rateCount++;
  }

  // ── 載入醫療卡並過濾出 SOS 授權欄位 ──────────────────────────
  Future<MedicalCard?> loadMedicalCardForSos() async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final json = await _db.getMedicalCard(pubKeyBytes);
    if (json == null || json.isEmpty) return null;
    final card = MedicalCard.fromJsonString(json);
    if (!card.hasData) return null;
    return card;
  }

  /// 將醫療卡中用戶授權的欄位組裝為 Protobuf 序列化 bytes
  Uint8List? buildMedicalPayload(MedicalCard card) {
    final flags = card.sosFlags;
    // 檢查是否有任何欄位被授權
    final hasAny = flags.values.any((v) => v);
    if (!hasAny) return null;

    final summary = pb.MedicalSummary();

    if (flags[MedicalField.name] == true && card.name.isNotEmpty) {
      summary.name = card.name;
    }
    if (flags[MedicalField.age] == true && card.age != null) {
      summary.age = card.age!;
    }
    if (flags[MedicalField.heightCm] == true && card.heightCm != null) {
      summary.heightCm = card.heightCm!;
    }
    if (flags[MedicalField.weightKg] == true && card.weightKg != null) {
      summary.weightKg = card.weightKg!;
    }
    if (flags[MedicalField.bloodType] == true && card.bloodType.isNotEmpty) {
      summary.bloodType = card.bloodType;
    }
    if (flags[MedicalField.conditions] == true && card.conditions.isNotEmpty) {
      summary.conditions.addAll(card.conditions);
    }
    if (flags[MedicalField.allergies] == true && card.allergies.isNotEmpty) {
      for (final a in card.allergies) {
        summary.allergies.add(pb.AllergyEntry()
          ..allergen = a.allergen
          ..reaction = a.reaction);
      }
    }
    if (flags[MedicalField.medications] == true &&
        card.medications.isNotEmpty) {
      summary.medications.addAll(card.medications);
    }
    if (flags[MedicalField.emergencyContact] == true &&
        !card.emergencyContact.isEmpty) {
      summary.emergencyContact = pb.EmergencyContact()
        ..phone = card.emergencyContact.phone
        ..relation = card.emergencyContact.relation;
    }
    if (flags[MedicalField.organDonor] == true && card.organDonor != null) {
      summary.organDonor = card.organDonor!;
    }
    if (flags[MedicalField.primaryLanguage] == true &&
        card.primaryLanguage.isNotEmpty) {
      summary.primaryLanguage = card.primaryLanguage;
    }

    final bytes = summary.writeToBuffer();
    return bytes.isEmpty ? null : Uint8List.fromList(bytes);
  }

  // ── 發布求救 / 求援事件 ─────────────────────────────────────────
  Future<String> publishEvent({
    required int urgency,
    required String description,
    double? lat,
    double? lng,
    double maxRangeMeters = 1000.0,
    bool attachMedicalCard = false,
  }) async {
    await _checkRateLimit();

    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    // 組裝 RequestData protobuf (含可選醫療摘要)
    final requestData = pb.RequestData()
      ..requestId = eventId
      ..description = description
      ..urgency = pb.UrgencyLevel.valueOf(urgency) ?? pb.UrgencyLevel.INFO;
    if (lat != null) requestData.lat = lat;
    if (lng != null) requestData.lng = lng;
    requestData.maxRangeMeters = maxRangeMeters.toDouble();

    // 附加醫療卡（僅 SOS 等級且用戶開啟時）
    Uint8List? medicalBytes;
    if (attachMedicalCard && urgency >= 2) {
      final card = await loadMedicalCardForSos();
      if (card != null) {
        medicalBytes = buildMedicalPayload(card);
      }
    }

    // payload = description + 可選的醫療摘要 (以 \x00 分隔)
    final descBytes = utf8.encode(description);
    Uint8List payload;
    if (medicalBytes != null && medicalBytes.isNotEmpty) {
      // 格式: [description bytes] [0x00] [medical protobuf bytes]
      payload = Uint8List(descBytes.length + 1 + medicalBytes.length);
      payload.setRange(0, descBytes.length, descBytes);
      payload[descBytes.length] = 0x00; // 分隔符
      payload.setRange(descBytes.length + 1, payload.length, medicalBytes);
    } else {
      payload = Uint8List.fromList(descBytes);
    }

    final signature = await Signer.signPayload(payload);

    final db = await _db.database;
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.requestBroadcast,
      'urgency': urgency,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 10,
      'received_lat': lat,
      'received_lng': lng,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, urgency, payload));
    return eventId;
  }

  // ── 發布物資供給 ────────────────────────────────────────────────
  Future<String> publishSupply({
    required String resourceType,
    required int quantity,
    String unit = '份',
    required double maxRangeMeters,
    String deliveryMode = 'PICKUP',
    double? lat,
    double? lng,
  }) async {
    await _checkRateLimit();

    final resourceId = _uuid.v4();
    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    // 使用 Protobuf 二進位序列化 (取代字串拼接)
    final resourceData = pb.ResourceData()
      ..resourceId = resourceId
      ..resourceType = resourceType
      ..description = deliveryMode
      ..quantity = quantity.toDouble()
      ..unit = unit
      ..maxRangeMeters = maxRangeMeters.toDouble();
    if (lat != null) resourceData.lat = lat;
    if (lng != null) resourceData.lng = lng;
    final payload = Uint8List.fromList(resourceData.writeToBuffer());
    final signature = await Signer.signPayload(payload);

    final db = await _db.database;

    // 寫入物資狀態投影表 (CRDT)
    await db.insert('Materials_State', {
      'resource_id': resourceId,
      'status': MaterialStatus.available,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'matched_request_id': null,
      'match_expires_at': null,
      'payload': payload,
    });

    // 寫入事件溯源日誌
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.resourceRegister,
      'urgency': 1, // RESOURCE level
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 10,
      'received_lat': lat,
      'received_lng': lng,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, 1, payload));
    return resourceId;
  }

  // ── 發布物資需求（結構化 RequestData）──────────────────────────
  Future<String> publishRequest({
    required String resourceType,
    required int quantity,
    required String note,
    required double maxRangeMeters,
    String mobilityMode = 'CAN_GO',
    double? lat,
    double? lng,
  }) async {
    await _checkRateLimit();

    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    // 使用 RequestData protobuf（mobilityMode 編碼在 description 前綴）
    final requestData = pb.RequestData()
      ..requestId = eventId
      ..resourceType = resourceType
      ..description = '$mobilityMode|$note'
      ..quantityNeeded = quantity.toDouble()
      ..urgency = pb.UrgencyLevel.RESOURCE
      ..maxRangeMeters = maxRangeMeters.toDouble();
    if (lat != null) requestData.lat = lat;
    if (lng != null) requestData.lng = lng;

    final payload = Uint8List.fromList(requestData.writeToBuffer());
    final signature = await Signer.signPayload(payload);

    final db = await _db.database;
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.requestBroadcast,
      'urgency': 1,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 10,
      'received_lat': lat,
      'received_lng': lng,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, 1, payload));
    return eventId;
  }

  // ── 發布危險標記 ────────────────────────────────────────────────
  Future<String> publishHazard({
    required String type,
    required int severity,
    required double lat,
    required double lng,
    double radiusMeters = 200.0,
    String description = '',
  }) async {
    await _checkRateLimit();

    final hazardId = _uuid.v4();
    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    // 使用 Protobuf 二進位序列化 (取代字串拼接)
    final hazardData = pb.HazardData()
      ..hazardId = hazardId
      ..hazardType = type
      ..severity = severity
      ..centerLat = lat
      ..centerLng = lng
      ..radiusMeters = radiusMeters.toDouble();
    final payload = Uint8List.fromList(hazardData.writeToBuffer());
    final signature = await Signer.signPayload(payload);

    final db = await _db.database;

    // reported_by 存為 hex 字串（TEXT 欄位）
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
      'urgency': 2, // SOS_YELLOW
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 8,
      'received_lat': lat,
      'received_lng': lng,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, 2, payload));
    return hazardId;
  }

  // ── 處理 PIN 完成實體交接 ─────────────────────────────────────
  Future<void> completeHandoff({
    required String resourceId,
    required String requestId,
  }) async {
    final hlc = HLC.now();
    final db = await _db.database;

    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.consumed,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
        'matched_request_id': requestId,
      },
      where: 'resource_id = ?',
      whereArgs: [resourceId],
    );
  }

  // ── 取消媒合（PIN 失敗超限）─────────────────────────────────────
  Future<void> cancelHandoff({required String resourceId}) async {
    final hlc = HLC.now();
    final db = await _db.database;

    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.available,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
        'matched_request_id': null,
        'match_expires_at': null,
      },
      where: 'resource_id = ?',
      whereArgs: [resourceId],
    );
  }

  // ── 查詢可用物資 ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAvailableSupplies() async {
    final db = await _db.database;
    return await db.query(
      'Materials_State',
      where: 'status = ?',
      whereArgs: [MaterialStatus.available],
      orderBy: 'hlc_timestamp DESC',
    );
  }

  // ── 查詢危險標記 ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getActiveHazards() async {
    final db = await _db.database;
    return await db.query('Hazards_State', orderBy: 'created_at DESC');
  }

  // ── 取得目前使用者的 reporter hex ─────────────────────────────
  Future<String> getReporterHex() async {
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    return pubKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ── 搜尋附近同類型危險標記 ────────────────────────────────────
  /// 回傳最近的同類型標記 (距離 < searchRadius 公尺)，或 null
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

  // ── 確認（附議）他人危險標記 ──────────────────────────────────
  Future<void> confirmHazard(String hazardId) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE Hazards_State SET confirm_count = confirm_count + 1, '
      'updated_at = ? WHERE hazard_id = ?',
      [DateTime.now().millisecondsSinceEpoch, hazardId],
    );
  }

  // ── 更新自己建立的危險標記（同時廣播至 Mesh）────────────────
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
    final updates = <String, dynamic>{
      'updated_at': now,
    };
    if (type != null) updates['type'] = type;
    if (severity != null) updates['severity'] = severity;
    if (lat != null) updates['lat'] = lat;
    if (lng != null) updates['lng'] = lng;
    if (radiusMeters != null) updates['radius'] = radiusMeters;
    if (description != null) updates['description'] = description;
    await db.update(
      'Hazards_State',
      updates,
      where: 'hazard_id = ?',
      whereArgs: [hazardId],
    );

    // 廣播更新至 Mesh 網路
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
      final signature = await Signer.signPayload(payload);
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
        'node_tier': 1,
        'chunk_index': 0,
        'total_chunks': 1,
        'payload': payload,
        'signature': Uint8List.fromList(signature),
        'is_synced': 0,
      });
      _queue.enqueue(MeshTask(eventId, 2, payload));
    }
  }

  // ── 刪除（解除）自己的危險標記（同時廣播至 Mesh）────────────
  Future<void> deleteHazard(String hazardId) async {
    final db = await _db.database;

    // 先讀取標記資訊用於廣播
    final existing = await db
        .query('Hazards_State', where: 'hazard_id = ?', whereArgs: [hazardId]);

    await db
        .delete('Hazards_State', where: 'hazard_id = ?', whereArgs: [hazardId]);

    // 廣播刪除事件至 Mesh 網路（severity = 0 表示已解除）
    if (existing.isNotEmpty) {
      final h = existing.first;
      final hazardData = pb.HazardData()
        ..hazardId = hazardId
        ..hazardType = (h['type'] as String?) ?? ''
        ..severity = 0 // 0 = 已解除
        ..centerLat = (h['lat'] as num?)?.toDouble() ?? 0
        ..centerLng = (h['lng'] as num?)?.toDouble() ?? 0
        ..radiusMeters = 0;
      final payload = Uint8List.fromList(hazardData.writeToBuffer());
      final eventId = _uuid.v4();
      final hlc = HLC.now();
      final pubKeyBytes = await _identity.getPublicKeyBytes();
      final signature = await Signer.signPayload(payload);
      await db.insert('Event_Logs', {
        'event_id': eventId,
        'sender_pub_key': Uint8List.fromList(pubKeyBytes),
        'identity_level': _identity.getIdentityLevel(),
        'event_type': EventType.hazardMarker,
        'urgency': 0, // INFO level (解除通知)
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
        'ttl': 8,
        'received_lat': h['lat'],
        'received_lng': h['lng'],
        'node_tier': 1,
        'chunk_index': 0,
        'total_chunks': 1,
        'payload': payload,
        'signature': Uint8List.fromList(signature),
        'is_synced': 0,
      });
      _queue.enqueue(MeshTask(eventId, 0, payload));
    }
  }

  // ── Haversine 距離計算 (公尺) ─────────────────────────────────
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

  // ── 查詢最近事件日誌 ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRecentEvents({int limit = 20}) async {
    final db = await _db.database;
    return await db.query(
      'Event_Logs',
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );
  }

  // ── 取消物資供給 ───────────────────────────────────────────────
  /// 將物資狀態設為 CONSUMED（使之不再可用），並廣播取消事件
  Future<void> cancelSupply(String eventId) async {
    final db = await _db.database;

    // 找到對應的 resource_id
    final events = await db
        .query('Event_Logs', where: 'event_id = ?', whereArgs: [eventId]);
    if (events.isEmpty) return;

    final payload = events.first['payload'] as Uint8List?;
    if (payload != null) {
      try {
        final rd = pb.ResourceData.fromBuffer(payload);
        await db.update(
          'Materials_State',
          {
            'status': MaterialStatus.consumed,
            'hlc_timestamp': HLC.now().timestamp,
            'hlc_counter': HLC.now().counter,
          },
          where: 'resource_id = ?',
          whereArgs: [rd.resourceId],
        );
      } catch (_) {}
    }

    // 刪除事件紀錄
    await db.delete('Event_Logs', where: 'event_id = ?', whereArgs: [eventId]);

    // 廣播取消通知
    final cancelPayload = utf8.encode('CANCEL:SUPPLY:$eventId');
    final cancelId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final signature =
        await Signer.signPayload(Uint8List.fromList(cancelPayload));
    await db.insert('Event_Logs', {
      'event_id': cancelId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.matchCancel,
      'urgency': 0,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 8,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': Uint8List.fromList(cancelPayload),
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });
    _queue.enqueue(MeshTask(cancelId, 0, Uint8List.fromList(cancelPayload)));
  }

  // ── 取消物資需求 ───────────────────────────────────────────────
  Future<void> cancelRequest(String eventId) async {
    final db = await _db.database;

    // 刪除事件紀錄
    await db.delete('Event_Logs', where: 'event_id = ?', whereArgs: [eventId]);

    // 廣播取消通知
    final cancelPayload = utf8.encode('CANCEL:REQUEST:$eventId');
    final cancelId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final signature =
        await Signer.signPayload(Uint8List.fromList(cancelPayload));
    await db.insert('Event_Logs', {
      'event_id': cancelId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.matchCancel,
      'urgency': 0,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 8,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': Uint8List.fromList(cancelPayload),
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });
    _queue.enqueue(MeshTask(cancelId, 0, Uint8List.fromList(cancelPayload)));
  }
}
