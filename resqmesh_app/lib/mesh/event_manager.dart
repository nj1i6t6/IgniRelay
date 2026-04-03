import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:uuid/uuid.dart';
import '../crdt/hlc.dart';
import '../crypto/identity_manager.dart';
import '../crypto/signer.dart';
import '../db/database_helper.dart';
import '../models/medical_card.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import 'mesh_event_handler.dart';
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
  static const int fireAlarmRf = 7;
  static const int matchConfirm = 8;
  static const int matchReject = 9;
  static const int matchInquiry = 10;
  static const int matchAvailable = 11;
  static const int matchGone = 12;
  static const int chatMessage = 13;
  static const int locationUpdate = 14;
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
      'origin_lat': lat,
      'origin_lng': lng,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, urgency, payload, eventType: EventType.requestBroadcast));
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
      'origin_lat': lat,
      'origin_lng': lng,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, 1, payload, eventType: EventType.resourceRegister));
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
      'origin_lat': lat,
      'origin_lng': lng,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, 1, payload, eventType: EventType.requestBroadcast));
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
    if (description.isNotEmpty) hazardData.description = description;
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

  // ── 發布聊天訊息 ─────────────────────────────────────────────
  Future<String> publishChatMessage({
    required String roomId,
    required String roomType,
    required String content,
    String? replyTo,
  }) async {
    await _checkRateLimit();

    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    // Build payload: JSON with room info + content
    final payloadMap = <String, dynamic>{
      'room_id': roomId,
      'room_type': roomType,
      'content': content,
      if (replyTo != null) 'reply_to': replyTo,
    };
    final payload = Uint8List.fromList(utf8.encode(jsonEncode(payloadMap)));
    final signature = await Signer.signPayload(payload);

    final db = await _db.database;

    // 寫入事件溯源日誌
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.chatMessage,
      'urgency': 0, // INFO level
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 5,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    // 寫入 Chat_Messages 供本機顯示
    await db.insert('Chat_Messages', {
      'event_id': eventId,
      'room_id': roomId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'content': content,
      'reply_to': replyTo,
      'hlc_timestamp': hlc.timestamp,
    });

    _queue.enqueue(MeshTask(eventId, 0, payload, eventType: EventType.chatMessage));
    return eventId;
  }

  // ── 超時自動釋放配對 ─────────────────────────────────────────
  /// PENDING 超過 30 分鐘 → AVAILABLE，LOCKED 超過 4 小時 → AVAILABLE
  Future<void> expireStaleMatches() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _db.database;

    // PENDING 超過 30 分鐘 → 回到 AVAILABLE
    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.available,
        'matched_request_id': null,
        'match_expires_at': null,
      },
      where: "status = 'PENDING' AND match_expires_at IS NOT NULL AND match_expires_at < ?",
      whereArgs: [now],
    );

    // LOCKED 超過 4 小時 → 回到 AVAILABLE
    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.available,
        'matched_request_id': null,
        'match_expires_at': null,
      },
      where: "status = 'LOCKED' AND match_expires_at IS NOT NULL AND match_expires_at < ?",
      whereArgs: [now],
    );
  }

  // ── 發布配對意向（鎖定 supply 為 PENDING）──────────────────────
  Future<String> publishMatchIntent({
    required String resourceId,
    required String requestId,
    required List<int> requesterPubKey,
    required double matchScore,
  }) async {
    final hlc = HLC.now();
    final db = await _db.database;

    // 檢查 supply 是否仍為 AVAILABLE
    final mat = await db.query('Materials_State',
        where: 'resource_id = ? AND status = ?',
        whereArgs: [resourceId, MaterialStatus.available]);
    if (mat.isEmpty) throw Exception('Supply no longer available');

    // 立刻改為 PENDING + 設定 30 分鐘超時
    final expiresAt = DateTime.now().millisecondsSinceEpoch + (30 * 60 * 1000);
    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.pending,
        'matched_request_id': requestId,
        'match_expires_at': expiresAt,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
      },
      where: 'resource_id = ?',
      whereArgs: [resourceId],
    );

    // 建立 MatchIntentData 並廣播
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final intentData = pb.MatchIntentData()
      ..requestId = requestId
      ..resourceId = resourceId
      ..requesterPubKey = requesterPubKey
      ..providerPubKey = pubKeyBytes
      ..matchScore = matchScore;
    final payload = Uint8List.fromList(intentData.writeToBuffer());
    final signature = await Signer.signPayload(payload);

    final eventId = _uuid.v4();
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.matchIntent,
      'urgency': 1,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 10,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(
        MeshTask(eventId, 1, payload, eventType: EventType.matchIntent));
    return eventId;
  }

  // ── 發布媒合確認（需求者 → 全網）────────────────────────────────
  Future<String> publishMatchConfirm({
    required String requestId,
    required String resourceId,
    required List<int> requesterPubKey,
    required List<int> providerPubKey,
  }) async {
    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    final confirmData = pb.MatchConfirmData()
      ..requestId = requestId
      ..resourceId = resourceId
      ..requesterPubKey = requesterPubKey
      ..providerPubKey = providerPubKey;
    final payload = Uint8List.fromList(confirmData.writeToBuffer());
    final signature = await Signer.signPayload(payload);

    final db = await _db.database;
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.matchConfirm,
      'urgency': 1,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 10,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    // 建立 Match_Session
    final sessionId = '${resourceId}_$requestId';
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await db.insert('Match_Sessions', {
        'session_id': sessionId,
        'resource_id': resourceId,
        'request_id': requestId,
        'provider_pub_key': Uint8List.fromList(providerPubKey),
        'requester_pub_key': Uint8List.fromList(requesterPubKey),
        'status': 'ACTIVE',
        'created_at': now,
        'updated_at': now,
      });
    } catch (_) {}

    _queue.enqueue(MeshTask(eventId, 1, payload, eventType: EventType.matchConfirm));
    return eventId;
  }

  // ── 發布媒合拒絕（需求者 → 供給者）─────────────────────────────
  Future<String> publishMatchReject({
    required String requestId,
    required String resourceId,
    String reason = 'ALREADY_LOCKED',
  }) async {
    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    final rejectData = pb.MatchRejectData()
      ..requestId = requestId
      ..resourceId = resourceId
      ..reason = reason;
    final payload = Uint8List.fromList(rejectData.writeToBuffer());
    final signature = await Signer.signPayload(payload);

    final db = await _db.database;
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.matchReject,
      'urgency': 1,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 10,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, 1, payload, eventType: EventType.matchReject));
    return eventId;
  }

  // ── 處理 PIN 完成實體交接（含廣播 PHYSICAL_HANDSHAKE）─────────
  Future<void> completeHandoff({
    required String resourceId,
    required String requestId,
  }) async {
    final hlc = HLC.now();
    final db = await _db.database;
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    // 更新本地 Materials_State
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

    // 更新 Requests_State
    await db.update(
      'Requests_State',
      {'status': 'CONSUMED'},
      where: 'request_id = ?',
      whereArgs: [requestId],
    );

    // 完成 Match_Session
    final sessionId = '${resourceId}_$requestId';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'Match_Sessions',
      {
        'status': 'COMPLETED',
        'completed_at': now,
        'updated_at': now,
      },
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    // 廣播 PHYSICAL_HANDSHAKE 到 Mesh
    final handshakeData = pb.PhysicalHandshakeData()
      ..resourceId = resourceId
      ..requestId = requestId
      ..providerPubKey = pubKeyBytes
      ..method = 'PIN_4DIGIT';
    final payload = Uint8List.fromList(handshakeData.writeToBuffer());
    final signature = await Signer.signPayload(payload);

    final eventId = _uuid.v4();
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.physicalHandshake,
      'urgency': 1,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 10,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });
    _queue.enqueue(MeshTask(eventId, 1, payload, eventType: EventType.physicalHandshake));
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

  // ── 處理 pending match actions（由 MeshEventHandler 產生）──────
  Future<void> processPendingMatchActions() async {
    final handler = MeshEventHandler();
    final actions = handler.drainPendingMatchActions();
    for (final action in actions) {
      try {
        if (action.type == 'CONFIRM') {
          await publishMatchConfirm(
            requestId: action.requestId,
            resourceId: action.resourceId,
            requesterPubKey: action.requesterPubKey,
            providerPubKey: action.providerPubKey,
          );
        } else if (action.type == 'REJECT') {
          await publishMatchReject(
            requestId: action.requestId,
            resourceId: action.resourceId,
            reason: action.reason,
          );
        }
      } catch (e) {
        debugPrint('[EventMgr] Process pending match action error: $e');
      }
    }
  }

  // ── 媒合中位置同步（10m + 30s 節流）──────────────────────────
  int _lastLocationSyncMs = 0;
  static const int _locationSyncThrottleMs = 30000; // 30 秒

  Future<void> publishLocationUpdate({
    required String sessionId,
    required double lat,
    required double lng,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLocationSyncMs < _locationSyncThrottleMs) return;
    _lastLocationSyncMs = now;

    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();

    final locData = pb.LocationUpdateData()
      ..sessionId = sessionId
      ..lat = lat
      ..lng = lng
      ..timestamp = fixnum.Int64(now);
    final payload = Uint8List.fromList(locData.writeToBuffer());
    final signature = await Signer.signPayload(payload);

    final db = await _db.database;
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.locationUpdate,
      'urgency': 0,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': 3, // 短 TTL，位置資訊不需要長距離傳播
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

    // 更新 Match_Sessions 中自己的位置
    final myPubKey = Uint8List.fromList(pubKeyBytes);
    // 判斷自己是 provider 還是 requester
    final session = await db.query('Match_Sessions',
        where: 'session_id = ?', whereArgs: [sessionId], limit: 1);
    if (session.isNotEmpty) {
      final providerKey = session.first['provider_pub_key'] as Uint8List?;
      if (providerKey != null && _bytesEqual(providerKey, myPubKey)) {
        await db.update('Match_Sessions', {
          'provider_lat': lat,
          'provider_lng': lng,
          'updated_at': now,
        }, where: 'session_id = ?', whereArgs: [sessionId]);
      } else {
        await db.update('Match_Sessions', {
          'requester_lat': lat,
          'requester_lng': lng,
          'updated_at': now,
        }, where: 'session_id = ?', whereArgs: [sessionId]);
      }
    }

    _queue.enqueue(MeshTask(eventId, 0, payload, eventType: EventType.locationUpdate));
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── 查詢活躍 Match Sessions ───────────────────────────────────
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    final db = await _db.database;
    return db.query('Match_Sessions',
        where: "status = 'ACTIVE'",
        orderBy: 'created_at DESC');
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

  // ── 確認（附議）他人危險標記（本地 + 廣播）─────────────────────
  Future<void> confirmHazard(String hazardId) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 本地 +1
    await db.rawUpdate(
      'UPDATE Hazards_State SET confirm_count = confirm_count + 1, '
      'updated_at = ? WHERE hazard_id = ?',
      [now, hazardId],
    );

    // 廣播確認事件到 Mesh
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
        ..isConfirmation = true; // 標記為附議事件
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
    _queue.enqueue(MeshTask(cancelId, 0, Uint8List.fromList(cancelPayload), eventType: EventType.matchCancel));
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
    _queue.enqueue(MeshTask(cancelId, 0, Uint8List.fromList(cancelPayload), eventType: EventType.matchCancel));
  }
}
