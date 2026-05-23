import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:uuid/uuid.dart';
import 'package:ignirelay_app/app/crdt/hlc.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/crypto/signer.dart';

import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/models/medical_card.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;
import 'package:ignirelay_app/app/proto/handshake_schema.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';
import 'package:ignirelay_app/app/mesh/hazard_manager.dart';
import 'package:ignirelay_app/app/mesh/triage_queue.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/rate_limit_exception.dart';

// Re-export so existing callers that `import event_manager.dart show RateLimitException`
// still compile during transition. New callers should import the non-mesh path directly.
export 'package:ignirelay_app/app/services/rate_limit_exception.dart' show RateLimitException;

// 物資狀態常數
class MaterialStatus {
  static const String available = 'AVAILABLE';
  static const String depleted = 'DEPLETED';
  static const String consumed = 'CONSUMED';
  static const String cancelled = 'CANCELLED';
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

  /// Hazard 管理委派（publish, confirm, update, delete, query）
  final HazardManager hazards = HazardManager();

  // ── 速率限制 ────────────────────────────────────────────────────
  // 用 HLC 時間窗口（不依賴 wallclock）防止時鐘跳躍
  int _rateWindowStartHlc = 0;
  int _rateCount = 0;
  static const int _maxPerHour = 20;

  @visibleForTesting
  void resetRateLimit() {
    _rateWindowStartHlc = 0;
    _rateCount = 0;
  }
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

    // TODO: 醫療卡附加功能需擴充 RequestData proto (加 bytes medical_summary 欄位)
    // 目前接收端尚無解析醫療資料邏輯，暫不附加以避免破壞 protobuf 格式

    // 使用 RequestData protobuf 序列化（接收端以 RequestData.fromBuffer 解碼）
    final payload = Uint8List.fromList(requestData.writeToBuffer());

    final signature = await Signer.signEvent(
      eventId: eventId, eventType: EventType.requestBroadcast, payload: payload,
    );

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
      ..deliveryMode = deliveryMode
      ..quantity = quantity.toDouble()
      ..unit = unit
      ..maxRangeMeters = maxRangeMeters.toDouble();
    if (lat != null) resourceData.lat = lat;
    if (lng != null) resourceData.lng = lng;
    final payload = Uint8List.fromList(resourceData.writeToBuffer());
    final signature = await Signer.signEvent(
      eventId: eventId, eventType: EventType.resourceRegister, payload: payload,
    );

    final db = await _db.database;

    // 寫入物資狀態投影表 (CRDT)
    await db.insert('Materials_State', {
      'resource_id': resourceId,
      'status': MaterialStatus.available,
      'total_qty': quantity.toDouble(),
      'delivery_mode': deliveryMode,
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

    // 使用 RequestData protobuf（含 mobilityMode 和 note 欄位）
    final requestData = pb.RequestData()
      ..requestId = eventId
      ..resourceType = resourceType
      ..mobilityMode = mobilityMode
      ..note = note
      ..quantityNeeded = quantity.toDouble()
      ..urgency = pb.UrgencyLevel.RESOURCE
      ..maxRangeMeters = maxRangeMeters.toDouble();
    if (lat != null) requestData.lat = lat;
    if (lng != null) requestData.lng = lng;

    final payload = Uint8List.fromList(requestData.writeToBuffer());
    final signature = await Signer.signEvent(
      eventId: eventId, eventType: EventType.requestBroadcast, payload: payload,
    );

    final db = await _db.database;

    // 寫入 Requests_State（本地也寫入）
    await db.insert('Requests_State', {
      'request_id': eventId,
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'quantity_needed': quantity.toDouble(),
      'mobility_mode': mobilityMode,
      'note': note,
      'status': 'OPEN',
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'payload': payload,
    });

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

  /// 發布危險標記（委派至 HazardManager，rate limit 在此檢查）
  Future<String> publishHazard({
    required String type,
    required int severity,
    required double lat,
    required double lng,
    double radiusMeters = 200.0,
    String description = '',
  }) async {
    await _checkRateLimit();
    return hazards.publishHazard(
      type: type, severity: severity, lat: lat, lng: lng,
      radiusMeters: radiusMeters, description: description,
    );
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
    final signature = await Signer.signEvent(
      eventId: eventId, eventType: EventType.chatMessage, payload: payload,
    );

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
  Future<void> expireStaleMatches() async {
    await NegotiationManager().expireStaleNegotiations();
  }

  /// 供給方主動：發送 MATCH_OFFER（不鎖定物資）
  Future<String?> publishMatchOffer({
    required String resourceId,
    required String requestId,
    required List<int> requesterPubKey,
    required double offeredQty,
    required double matchScore,
  }) async {
    final pubKey = await _identity.getPublicKeyBytes();
    final negotiationId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + 2700000; // 45 minutes

    // Create negotiation via Application Layer
    final created = await NegotiationManager().createNegotiation(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId,
      initiatorRole: 'PROVIDER',
      providerPubKey: pubKey,
      requesterPubKey: requesterPubKey,
      offeredQty: offeredQty,
      requestedQty: 0,
      expiresAt: expiresAt,
      matchScore: matchScore,
    );
    if (!created) return null;

    final data = pb.MatchOfferData(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId,
      providerPubKey: pubKey,
      requesterPubKey: requesterPubKey,
      offeredQty: offeredQty,
      matchScore: matchScore,
      expiresAt: fixnum.Int64(expiresAt),
    );

    final payload = data.writeToBuffer();
    final eventId = await _publishAndStore(
      payload: payload,
      eventType: EventType.matchOffer,
      urgency: 1,
      ttl: 5,
    );
    return eventId;
  }

  /// 需求方主動：發送 MATCH_REQUEST
  Future<String?> publishMatchRequest({
    required String resourceId,
    required String requestId,
    required List<int> providerPubKey,
    required double requestedQty,
  }) async {
    final pubKey = await _identity.getPublicKeyBytes();
    final negotiationId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + 2700000; // 45 minutes

    final created = await NegotiationManager().createNegotiation(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId,
      initiatorRole: 'REQUESTER',
      providerPubKey: providerPubKey,
      requesterPubKey: pubKey,
      offeredQty: 0,
      requestedQty: requestedQty,
      expiresAt: expiresAt,
    );
    if (!created) return null;

    final data = pb.MatchRequestData(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId,
      providerPubKey: providerPubKey,
      requesterPubKey: pubKey,
      requestedQty: requestedQty,
      expiresAt: fixnum.Int64(expiresAt),
    );

    final payload = data.writeToBuffer();
    final eventId = await _publishAndStore(
      payload: payload,
      eventType: EventType.matchRequest,
      urgency: 1,
      ttl: 5,
    );
    return eventId;
  }

  /// 接受對方的協商提議
  Future<String?> publishMatchAccept({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required double agreedQty,
  }) async {
    final pubKey = await _identity.getPublicKeyBytes();

    // Accept via Application Layer (CAS check)
    final accepted = await NegotiationManager().acceptNegotiation(
      negotiationId, pubKey);
    if (!accepted) return null;

    final data = pb.MatchAcceptData(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId,
      acceptorPubKey: pubKey,
      agreedQty: agreedQty,
    );

    final payload = data.writeToBuffer();
    final eventId = await _publishAndStore(
      payload: payload,
      eventType: EventType.matchAccept,
      urgency: 1,
      ttl: 5,
    );
    return eventId;
  }

  /// 拒絕對方的協商提議
  Future<String?> publishMatchDecline({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required String reason,
  }) async {
    final pubKey = await _identity.getPublicKeyBytes();
    await NegotiationManager().declineNegotiation(
      negotiationId, pubKey, reason);

    final data = pb.MatchDeclineData(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId,
      reason: reason,
    );

    final payload = data.writeToBuffer();
    final eventId = await _publishAndStore(
      payload: payload,
      eventType: EventType.matchDecline,
      urgency: 1,
      ttl: 3,
    );
    return eventId;
  }

  /// 交接完成
  Future<String?> publishHandshakeComplete({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required List<int> providerPubKey,
    required List<int> requesterPubKey,
    required double actualDeliveredQty,
    required String method,
  }) async {
    final pubKey = await _identity.getPublicKeyBytes();
    await NegotiationManager().completeHandshake(
      negotiationId, pubKey, actualDeliveredQty);

    final data = pb.HandshakeCompleteData(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId,
      providerPubKey: providerPubKey,
      requesterPubKey: requesterPubKey,
      actualDeliveredQty: actualDeliveredQty,
      method: method,
      // Stage 6 (commit #10)：標示本 payload 由新版 schema 寫出。
      schemaVersion: HandshakeSchema.currentSchemaVersion,
    );

    final payload = data.writeToBuffer();
    final eventId = await _publishAndStore(
      payload: payload,
      eventType: EventType.handshakeComplete,
      urgency: 1,
      ttl: 10,
    );
    return eventId;
  }

  /// 取消協商
  Future<String?> publishMatchCancel({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required String reason,
  }) async {
    final pubKey = await _identity.getPublicKeyBytes();
    await NegotiationManager().cancelNegotiation(
      negotiationId, pubKey, reason);

    final data = pb.MatchCancelData(
      negotiationId: negotiationId,
      resourceId: resourceId,
      requestId: requestId,
      reason: reason,
    );

    final payload = data.writeToBuffer();
    final eventId = await _publishAndStore(
      payload: payload,
      eventType: EventType.matchCancel,
      urgency: 2, // SOS_YELLOW — higher priority
      ttl: 5,
    );
    return eventId;
  }

  // ── 媒合中位置同步（10m + 30s 節流）──────────────────────────
  int _lastLocationSyncMs = 0;
  static const int _locationSyncThrottleMs = 30000; // 30 秒

  Future<void> publishLocationUpdate({
    required String negotiationId,
    required double lat,
    required double lng,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLocationSyncMs < _locationSyncThrottleMs) return;
    _lastLocationSyncMs = now;

    final pubKeyBytes = await _identity.getPublicKeyBytes();

    final locData = pb.LocationUpdateData()
      ..sessionId = negotiationId
      ..lat = lat
      ..lng = lng
      ..timestamp = fixnum.Int64(now);
    final payload = locData.writeToBuffer();

    // Store location in Match_Negotiations via NegotiationManager
    await NegotiationManager().updateLocation(
      negotiationId, pubKeyBytes, lat, lng);

    await _publishAndStore(
      payload: payload,
      eventType: EventType.locationUpdate,
      urgency: 0,
      ttl: 3, // 短 TTL，位置資訊不需要長距離傳播
      lat: lat,
      lng: lng,
    );
  }

  // ── 查詢活躍 Match Negotiations ─────────────────────────────────
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    final db = await _db.database;
    return db.query('Match_Negotiations',
        where: "status IN ('PENDING', 'ACCEPTED', 'NAVIGATING')",
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

  // ── Hazard 查詢（委派至 HazardManager）───────────────────────
  Future<List<Map<String, dynamic>>> getActiveHazards() => hazards.getActiveHazards();
  Future<String> getReporterHex() => hazards.getReporterHex();
  Future<Map<String, dynamic>?> findNearbyHazard(
    double lat, double lng, String type, {double searchRadius = 500.0,
  }) => hazards.findNearbyHazard(lat, lng, type, searchRadius: searchRadius);

  // ── Hazard CRUD 委派 ──────────────────────────────────────────
  Future<void> confirmHazard(String hazardId) => hazards.confirmHazard(hazardId);
  Future<void> updateHazard(String hazardId, {
    String? type, int? severity, double? lat, double? lng,
    double? radiusMeters, String? description,
  }) => hazards.updateHazard(hazardId, type: type, severity: severity,
      lat: lat, lng: lng, radiusMeters: radiusMeters, description: description);
  Future<void> deleteHazard(String hazardId) => hazards.deleteHazard(hazardId);

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
        final hlcCancel = HLC.now();
        await db.update(
          'Materials_State',
          {
            'status': MaterialStatus.consumed,
            'hlc_timestamp': hlcCancel.timestamp,
            'hlc_counter': hlcCancel.counter,
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
    final signature = await Signer.signEvent(
      eventId: cancelId, eventType: EventType.matchCancel, payload: cancelPayload,
    );
    final pos = LocationService().currentLocation;
    final cLat = pos?.latitude;
    final cLng = pos?.longitude;
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
      'received_lat': cLat,
      'received_lng': cLng,
      'origin_lat': cLat,
      'origin_lng': cLng,
      'payload': Uint8List.fromList(cancelPayload),
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });
    _queue.enqueue(MeshTask(cancelId, 0, Uint8List.fromList(cancelPayload), eventType: EventType.matchCancel));
  }

  // ── 取消物資需求 ───────────────────────────────────────────────
  Future<void> cancelRequest(String eventId) async {
    final db = await _db.database;

    // 更新 Requests_State 為 CANCELLED
    await db.update(
      'Requests_State',
      {'status': 'CANCELLED'},
      where: 'event_id = ?',
      whereArgs: [eventId],
    );

    // 刪除事件紀錄
    await db.delete('Event_Logs', where: 'event_id = ?', whereArgs: [eventId]);

    // 廣播取消通知
    final cancelPayload = utf8.encode('CANCEL:REQUEST:$eventId');
    final cancelId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final signature = await Signer.signEvent(
      eventId: cancelId, eventType: EventType.matchCancel, payload: cancelPayload,
    );
    final pos = LocationService().currentLocation;
    final cLat = pos?.latitude;
    final cLng = pos?.longitude;
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
      'received_lat': cLat,
      'received_lng': cLng,
      'origin_lat': cLat,
      'origin_lng': cLng,
      'payload': Uint8List.fromList(cancelPayload),
      'signature': Uint8List.fromList(signature),
      'is_synced': 0,
    });
    _queue.enqueue(MeshTask(cancelId, 0, Uint8List.fromList(cancelPayload), eventType: EventType.matchCancel));
  }

  // ── 簽名、儲存、廣播 helper ──────────────────────────────────────
  ///
  /// [lat]/[lng]：當前裝置（=發送者）的座標。若 caller 沒提供，會從
  /// `LocationService().currentLocation` 取；仍取不到則寫 null。
  /// null 代表無座標；接收端路由將跳過地理圍欄，以有限跳數傳播。
  /// 這兩個值同時當作 `received_lat/lng`（接收節點 = 自己）和
  /// `origin_lat/lng`（事件發源地）寫入。
  Future<String> _publishAndStore({
    required List<int> payload,
    required int eventType,
    required int urgency,
    required int ttl,
    double? lat,
    double? lng,
  }) async {
    final hlc = HLC.now();
    final eventId = _uuid.v4();
    final pubKey = await _identity.getPublicKeyBytes();
    final idLevel = _identity.getIdentityLevel();
    final sig = await Signer.signEvent(
      eventId: eventId, eventType: eventType, payload: payload,
    );

    // 取得座標：caller 顯式提供 > LocationService > null（無座標，跳過地理圍欄）
    double? effLat = lat;
    double? effLng = lng;
    if (lat == null || lng == null) {
      final pos = LocationService().currentLocation;
      if (pos != null) {
        effLat ??= pos.latitude;
        effLng ??= pos.longitude;
      }
    }

    final db = await _db.database;
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKey),
      'identity_level': idLevel,
      'event_type': eventType,
      'urgency': urgency,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'ttl': ttl,
      'node_tier': 0,
      'chunk_index': 0,
      'total_chunks': 1,
      'received_lat': effLat,
      'received_lng': effLng,
      'origin_lat': effLat,
      'origin_lng': effLng,
      'payload': Uint8List.fromList(payload),
      'signature': Uint8List.fromList(sig),
      'is_synced': 0,
    });

    _queue.enqueue(MeshTask(eventId, urgency, Uint8List.fromList(payload), eventType: eventType));
    return eventId;
  }
}
