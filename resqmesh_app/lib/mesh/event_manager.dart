import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../crdt/hlc.dart';
import '../crypto/identity_manager.dart';
import '../crypto/signer.dart';
import '../db/database_helper.dart';
import '../models/medical_card.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import '../services/location_service.dart';
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
  static const int hazardConfirm = 14;
  static const int matchLocationUpdate = 15;
}

// 物資狀態常數
class MaterialStatus {
  static const String available = 'AVAILABLE';
  static const String pending = 'PENDING';
  static const String locked = 'LOCKED';
  static const String consumed = 'CONSUMED';
}

// 需求狀態常數
class RequestStatus {
  static const String available = 'AVAILABLE';
  static const String pending = 'PENDING';
  static const String locked = 'LOCKED';
  static const String consumed = 'CONSUMED';
}

// 媒合 session 狀態
class MatchSessionStatus {
  static const String active = 'ACTIVE';
  static const String completed = 'COMPLETED';
  static const String cancelled = 'CANCELLED';
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
  EventManager._internal() {
    _ensureLocationSyncHook();
  }

  final _uuid = const Uuid();
  final _db = DatabaseHelper();
  final _identity = IdentityManager();
  final _queue = TriageQueue();

  TriageQueue get queue => _queue;

  StreamSubscription<LatLng>? _locationSyncSub;
  int _lastLocationBroadcastAt = 0;

  // ── 速率限制 ────────────────────────────────────────────────────
  // 用 HLC 時間窗口（不依賴 wallclock）防止時鐘跳躍
  int _rateWindowStartHlc = 0;
  int _rateCount = 0;
  static const int _maxPerHour = 20;
  static const int _oneHourMs = 3600000;
  static const int _sessionExpireMs = 4 * 60 * 60 * 1000;
  static const int _matchIntentExpireMs = 30 * 60 * 1000;
  static const int _locationSyncThrottleMs = 30 * 1000;

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

  void _ensureLocationSyncHook() {
    _locationSyncSub ??= LocationService().positionUpdates.listen((loc) {
      _broadcastLocationForActiveSession(loc).catchError((_) {});
    });
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _reporterHex(List<int> pubKeyBytes) =>
      pubKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  String _sessionIdFor(String resourceId, String requestId) =>
      '$resourceId::$requestId';

  Future<void> _insertEventLog({
    required String eventId,
    required List<int> senderPubKey,
    required int eventType,
    required int urgency,
    required Uint8List payload,
    required Uint8List signature,
    required int hlcTimestamp,
    required int hlcCounter,
    int ttl = 10,
    double? lat,
    double? lng,
    double? originLat,
    double? originLng,
  }) async {
    final db = await _db.database;
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(senderPubKey),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': eventType,
      'urgency': urgency,
      'hlc_timestamp': hlcTimestamp,
      'hlc_counter': hlcCounter,
      'ttl': ttl,
      'received_lat': lat,
      'received_lng': lng,
      'origin_lat': originLat ?? lat,
      'origin_lng': originLng ?? lng,
      'node_tier': 1,
      'chunk_index': 0,
      'total_chunks': 1,
      'payload': payload,
      'signature': signature,
      'is_synced': 0,
    });
  }

  Future<String> _publishMeshPayload({
    required int eventType,
    required int urgency,
    required Uint8List payload,
    double? lat,
    double? lng,
    double? originLat,
    double? originLng,
    int ttl = 10,
  }) async {
    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final signature = await Signer.signPayload(payload);
    await _insertEventLog(
      eventId: eventId,
      senderPubKey: pubKeyBytes,
      eventType: eventType,
      urgency: urgency,
      payload: payload,
      signature: signature,
      hlcTimestamp: hlc.timestamp,
      hlcCounter: hlc.counter,
      ttl: ttl,
      lat: lat,
      lng: lng,
      originLat: originLat,
      originLng: originLng,
    );
    _queue.enqueue(MeshTask(eventId, urgency, payload, eventType: eventType));
    return eventId;
  }

  Future<void> _upsertMatchSession({
    required String resourceId,
    required String requestId,
    required List<int> requesterPubKey,
    required List<int> providerPubKey,
    required String status,
    int? expiresAt,
    double? requesterLat,
    double? requesterLng,
    double? providerLat,
    double? providerLng,
    int? lastLocationUpdateAt,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionId = _sessionIdFor(resourceId, requestId);
    final existing = await db.query(
      'Match_Sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    final record = <String, dynamic>{
      'session_id': sessionId,
      'resource_id': resourceId,
      'request_id': requestId,
      'requester_pub_key': Uint8List.fromList(requesterPubKey),
      'provider_pub_key': Uint8List.fromList(providerPubKey),
      'status': status,
      'created_at': existing.isNotEmpty ? existing.first['created_at'] : now,
      'updated_at': now,
      'expires_at': expiresAt,
      'last_requester_lat': requesterLat,
      'last_requester_lng': requesterLng,
      'last_provider_lat': providerLat,
      'last_provider_lng': providerLng,
      'last_location_update_at': lastLocationUpdateAt,
    };
    await db.insert(
      'Match_Sessions',
      record,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLatestActiveSession() async {
    final db = await _db.database;
    final rows = await db.query(
      'Match_Sessions',
      where: 'status = ?',
      whereArgs: [MatchSessionStatus.active],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> getActiveSessionByMatch(
      String resourceId, String requestId) async {
    final db = await _db.database;
    final rows = await db.query(
      'Match_Sessions',
      where: 'resource_id = ? AND request_id = ? AND status = ?',
      whereArgs: [resourceId, requestId, MatchSessionStatus.active],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> _broadcastLocationForActiveSession(LatLng loc) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLocationBroadcastAt < _locationSyncThrottleMs) return;

    final session = await getLatestActiveSession();
    if (session == null) return;

    final myPubKey = await _identity.getPublicKeyBytes();
    final requesterPubKey =
        (session['requester_pub_key'] as Uint8List?)?.toList() ?? const <int>[];
    final providerPubKey =
        (session['provider_pub_key'] as Uint8List?)?.toList() ?? const <int>[];
    if (requesterPubKey.isEmpty || providerPubKey.isEmpty) return;

    final isRequester = _bytesEqual(myPubKey, requesterPubKey);
    final isProvider = _bytesEqual(myPubKey, providerPubKey);
    if (!isRequester && !isProvider) return;

    final requestId = session['request_id'] as String? ?? '';
    final resourceId = session['resource_id'] as String? ?? '';
    if (requestId.isEmpty || resourceId.isEmpty) return;

    final payload = Uint8List.fromList((pb.MatchLocationUpdateData()
          ..requestId = requestId
          ..resourceId = resourceId
          ..requesterPubKey = requesterPubKey
          ..providerPubKey = providerPubKey
          ..senderPubKey = myPubKey
          ..lat = loc.latitude
          ..lng = loc.longitude
          ..observedAt = fixnum.Int64(now))
        .writeToBuffer());

    await _publishMeshPayload(
      eventType: EventType.matchLocationUpdate,
      urgency: 1,
      payload: payload,
      lat: loc.latitude,
      lng: loc.longitude,
      ttl: 6,
    );

    final db = await _db.database;
    final updates = <String, dynamic>{
      'updated_at': now,
      'last_location_update_at': now,
    };
    if (isRequester) {
      updates['last_requester_lat'] = loc.latitude;
      updates['last_requester_lng'] = loc.longitude;
    } else {
      updates['last_provider_lat'] = loc.latitude;
      updates['last_provider_lng'] = loc.longitude;
    }
    await db.update(
      'Match_Sessions',
      updates,
      where: 'session_id = ?',
      whereArgs: [_sessionIdFor(resourceId, requestId)],
    );
    _lastLocationBroadcastAt = now;
  }

  Future<void> handleRemoteLocationUpdate(
      pb.MatchLocationUpdateData data) async {
    final sender = data.senderPubKey;
    final requesterPubKey = data.requesterPubKey;
    final providerPubKey = data.providerPubKey;
    if (sender.isEmpty || requesterPubKey.isEmpty || providerPubKey.isEmpty) {
      return;
    }
    final updates = <String, dynamic>{
      'updated_at': data.observedAt.toInt() > 0
          ? data.observedAt.toInt()
          : DateTime.now().millisecondsSinceEpoch,
      'last_location_update_at': data.observedAt.toInt() > 0
          ? data.observedAt.toInt()
          : DateTime.now().millisecondsSinceEpoch,
    };
    if (_bytesEqual(sender, requesterPubKey)) {
      updates['last_requester_lat'] = data.lat;
      updates['last_requester_lng'] = data.lng;
    } else if (_bytesEqual(sender, providerPubKey)) {
      updates['last_provider_lat'] = data.lat;
      updates['last_provider_lng'] = data.lng;
    }
    final db = await _db.database;
    await db.update(
      'Match_Sessions',
      updates,
      where: 'session_id = ?',
      whereArgs: [_sessionIdFor(data.resourceId, data.requestId)],
    );
  }

  Future<void> handleMatchConfirm(pb.MatchConfirmData data) async {
    final db = await _db.database;
    final hlc = HLC.now();
    final expiresAt = DateTime.now().millisecondsSinceEpoch + _sessionExpireMs;

    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.locked,
        'matched_request_id': data.requestId,
        'match_expires_at': expiresAt,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
      },
      where: 'resource_id = ?',
      whereArgs: [data.resourceId],
    );

    await db.update(
      'Requests_State',
      {
        'status': RequestStatus.locked,
        'matched_resource_id': data.resourceId,
        'match_expires_at': expiresAt,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
      },
      where: 'request_id = ?',
      whereArgs: [data.requestId],
    );

    await _upsertMatchSession(
      resourceId: data.resourceId,
      requestId: data.requestId,
      requesterPubKey: data.requesterPubKey,
      providerPubKey: data.providerPubKey,
      status: MatchSessionStatus.active,
      expiresAt: expiresAt,
    );
  }

  Future<void> handleMatchReject(pb.MatchRejectData data) async {
    final db = await _db.database;
    final hlc = HLC.now();
    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.available,
        'matched_request_id': null,
        'match_expires_at': null,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
      },
      where: 'resource_id = ? AND matched_request_id = ?',
      whereArgs: [data.resourceId, data.requestId],
    );
  }

  Future<void> handleMatchCancelEvent(pb.MatchCancelData data) async {
    final db = await _db.database;
    final hlc = HLC.now();
    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.available,
        'matched_request_id': null,
        'match_expires_at': null,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
      },
      where: 'resource_id = ?',
      whereArgs: [data.resourceId],
    );
    await db.update(
      'Requests_State',
      {
        'status': RequestStatus.available,
        'matched_resource_id': null,
        'match_expires_at': null,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
      },
      where: 'request_id = ?',
      whereArgs: [data.requestId],
    );
    await db.update(
      'Match_Sessions',
      {
        'status': MatchSessionStatus.cancelled,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'session_id = ?',
      whereArgs: [_sessionIdFor(data.resourceId, data.requestId)],
    );
  }

  Future<void> handlePhysicalHandshakeEvent(
      pb.PhysicalHandshakeData data) async {
    final db = await _db.database;
    final hlc = HLC.now();
    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.consumed,
        'matched_request_id': data.requestId,
        'match_expires_at': null,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
      },
      where: 'resource_id = ?',
      whereArgs: [data.resourceId],
    );
    await db.update(
      'Requests_State',
      {
        'status': RequestStatus.consumed,
        'matched_resource_id': data.resourceId,
        'match_expires_at': null,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
      },
      where: 'request_id = ?',
      whereArgs: [data.requestId],
    );
    await db.update(
      'Match_Sessions',
      {
        'status': MatchSessionStatus.completed,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': null,
      },
      where: 'session_id = ?',
      whereArgs: [_sessionIdFor(data.resourceId, data.requestId)],
    );
  }

  Future<bool> respondToMatchIntent(pb.MatchIntentData intent) async {
    final db = await _db.database;
    final requestRows = await db.query(
      'Requests_State',
      where: 'request_id = ? AND status = ?',
      whereArgs: [intent.requestId, RequestStatus.available],
      limit: 1,
    );

    if (requestRows.isEmpty) {
      final rejectPayload = Uint8List.fromList((pb.MatchRejectData()
            ..requestId = intent.requestId
            ..resourceId = intent.resourceId
            ..requesterPubKey = intent.requesterPubKey
            ..providerPubKey = intent.providerPubKey
            ..reason = 'REQUEST_UNAVAILABLE')
          .writeToBuffer());
      await _publishMeshPayload(
        eventType: EventType.matchReject,
        urgency: 1,
        payload: rejectPayload,
        ttl: 8,
      );
      return false;
    }

    final hlc = HLC.now();
    final expiresAt = DateTime.now().millisecondsSinceEpoch + _sessionExpireMs;
    await db.update(
      'Requests_State',
      {
        'status': RequestStatus.locked,
        'matched_resource_id': intent.resourceId,
        'match_expires_at': expiresAt,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
      },
      where: 'request_id = ?',
      whereArgs: [intent.requestId],
    );

    await _upsertMatchSession(
      resourceId: intent.resourceId,
      requestId: intent.requestId,
      requesterPubKey: intent.requesterPubKey,
      providerPubKey: intent.providerPubKey,
      status: MatchSessionStatus.active,
      expiresAt: expiresAt,
    );

    final confirmPayload = Uint8List.fromList((pb.MatchConfirmData()
          ..requestId = intent.requestId
          ..resourceId = intent.resourceId
          ..requesterPubKey = intent.requesterPubKey
          ..providerPubKey = intent.providerPubKey)
        .writeToBuffer());
    await _publishMeshPayload(
      eventType: EventType.matchConfirm,
      urgency: 1,
      payload: confirmPayload,
      ttl: 8,
    );
    return true;
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
    final requestData = pb.RequestData()
      ..requestId = eventId
      ..description = description
      ..urgency = pb.UrgencyLevel.valueOf(urgency) ?? pb.UrgencyLevel.INFO;
    if (lat != null) requestData.lat = lat;
    if (lng != null) requestData.lng = lng;
    requestData.maxRangeMeters = maxRangeMeters.toDouble();

    Uint8List? medicalBytes;
    if (attachMedicalCard && urgency >= 2) {
      final card = await loadMedicalCardForSos();
      if (card != null) {
        medicalBytes = buildMedicalPayload(card);
      }
    }

    final descBytes = utf8.encode(description);
    Uint8List payload;
    if (medicalBytes != null && medicalBytes.isNotEmpty) {
      payload = Uint8List(descBytes.length + 1 + medicalBytes.length);
      payload.setRange(0, descBytes.length, descBytes);
      payload[descBytes.length] = 0x00;
      payload.setRange(descBytes.length + 1, payload.length, medicalBytes);
    } else {
      payload = Uint8List.fromList(descBytes);
    }

    final hlc = HLC.now();
    final pubKeyBytes = await _identity.getPublicKeyBytes();
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

    _queue.enqueue(MeshTask(eventId, urgency, payload,
        eventType: EventType.requestBroadcast));
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
    await db.insert('Materials_State', {
      'resource_id': resourceId,
      'status': MaterialStatus.available,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'matched_request_id': null,
      'match_expires_at': null,
      'payload': payload,
      'provider_pub_key': Uint8List.fromList(pubKeyBytes),
    });

    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.resourceRegister,
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

    _queue.enqueue(
        MeshTask(eventId, 1, payload, eventType: EventType.resourceRegister));
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
    await db.insert('Requests_State', {
      'request_id': eventId,
      'status': RequestStatus.available,
      'hlc_timestamp': hlc.timestamp,
      'hlc_counter': hlc.counter,
      'matched_resource_id': null,
      'match_expires_at': null,
      'payload': payload,
      'requester_pub_key': Uint8List.fromList(pubKeyBytes),
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

    _queue.enqueue(
        MeshTask(eventId, 1, payload, eventType: EventType.requestBroadcast));
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

    final hazardData = pb.HazardData()
      ..hazardId = hazardId
      ..hazardType = type
      ..severity = severity
      ..centerLat = lat
      ..centerLng = lng
      ..radiusMeters = radiusMeters.toDouble()
      ..observedAt = fixnum.Int64(hlc.timestamp)
      ..description = description;
    final payload = Uint8List.fromList(hazardData.writeToBuffer());
    final signature = await Signer.signPayload(payload);

    final db = await _db.database;
    final reporterHex = _reporterHex(pubKeyBytes);
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

    _queue.enqueue(
        MeshTask(eventId, 2, payload, eventType: EventType.hazardMarker));
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

    final payloadMap = <String, dynamic>{
      'room_id': roomId,
      'room_type': roomType,
      'content': content,
      if (replyTo != null) 'reply_to': replyTo,
    };
    final payload = Uint8List.fromList(utf8.encode(jsonEncode(payloadMap)));
    final signature = await Signer.signPayload(payload);

    final db = await _db.database;
    await db.insert('Event_Logs', {
      'event_id': eventId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'identity_level': _identity.getIdentityLevel(),
      'event_type': EventType.chatMessage,
      'urgency': 0,
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

    await db.insert('Chat_Messages', {
      'event_id': eventId,
      'room_id': roomId,
      'sender_pub_key': Uint8List.fromList(pubKeyBytes),
      'content': content,
      'reply_to': replyTo,
      'hlc_timestamp': hlc.timestamp,
    });

    _queue.enqueue(
        MeshTask(eventId, 0, payload, eventType: EventType.chatMessage));
    return eventId;
  }

  // ── 超時自動釋放配對 ─────────────────────────────────────────
  Future<void> expireStaleMatches() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _db.database;

    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.available,
        'matched_request_id': null,
        'match_expires_at': null,
      },
      where:
          "status IN ('PENDING', 'LOCKED') AND match_expires_at IS NOT NULL AND match_expires_at < ?",
      whereArgs: [now],
    );

    await db.update(
      'Requests_State',
      {
        'status': RequestStatus.available,
        'matched_resource_id': null,
        'match_expires_at': null,
      },
      where:
          "status IN ('PENDING', 'LOCKED') AND match_expires_at IS NOT NULL AND match_expires_at < ?",
      whereArgs: [now],
    );

    await db.update(
      'Match_Sessions',
      {
        'status': MatchSessionStatus.cancelled,
        'updated_at': now,
      },
      where: 'status = ? AND expires_at IS NOT NULL AND expires_at < ?',
      whereArgs: [MatchSessionStatus.active, now],
    );
  }

  // ── 發布配對意向（供給者主動提出）──────────────────────────────
  Future<String> publishMatchIntent({
    required String resourceId,
    required String requestId,
    required List<int> requesterPubKey,
    required double matchScore,
  }) async {
    final db = await _db.database;
    final mat = await db.query('Materials_State',
        where: 'resource_id = ? AND status = ?',
        whereArgs: [resourceId, MaterialStatus.available],
        limit: 1);
    if (mat.isEmpty) throw Exception('Supply no longer available');

    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final payload = Uint8List.fromList((pb.MatchIntentData()
          ..requestId = requestId
          ..resourceId = resourceId
          ..requesterPubKey = requesterPubKey
          ..providerPubKey = pubKeyBytes
          ..matchScore = matchScore
          ..matchExpiresAt = fixnum.Int64(
              DateTime.now().millisecondsSinceEpoch + _matchIntentExpireMs))
        .writeToBuffer());

    return _publishMeshPayload(
      eventType: EventType.matchIntent,
      urgency: 1,
      payload: payload,
      ttl: 10,
    );
  }

  // ── 處理 PIN 完成實體交接 ─────────────────────────────────────
  Future<void> completeHandoff({
    required String resourceId,
    required String requestId,
  }) async {
    final session = await getActiveSessionByMatch(resourceId, requestId);
    final db = await _db.database;
    final hlc = HLC.now();

    await db.update(
      'Materials_State',
      {
        'status': MaterialStatus.consumed,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
        'matched_request_id': requestId,
        'match_expires_at': null,
      },
      where: 'resource_id = ?',
      whereArgs: [resourceId],
    );
    await db.update(
      'Requests_State',
      {
        'status': RequestStatus.consumed,
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
        'matched_resource_id': resourceId,
        'match_expires_at': null,
      },
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
    await db.update(
      'Match_Sessions',
      {
        'status': MatchSessionStatus.completed,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': null,
      },
      where: 'session_id = ?',
      whereArgs: [_sessionIdFor(resourceId, requestId)],
    );

    final pubKeyBytes = await _identity.getPublicKeyBytes();
    final requesterPubKey =
        (session?['requester_pub_key'] as Uint8List?)?.toList() ?? pubKeyBytes;
    final providerPubKey =
        (session?['provider_pub_key'] as Uint8List?)?.toList() ?? pubKeyBytes;
    final handoffDigest =
        utf8.encode('$resourceId|$requestId|${hlc.timestamp}');
    final localSig = await Signer.signPayload(handoffDigest);
    final payload = Uint8List.fromList((pb.PhysicalHandshakeData()
          ..resourceId = resourceId
          ..requestId = requestId
          ..requesterPubKey = requesterPubKey
          ..providerPubKey = providerPubKey
          ..requesterSignature = localSig
          ..providerSignature = localSig
          ..method = 'PIN_4DIGIT')
        .writeToBuffer());
    await _publishMeshPayload(
      eventType: EventType.physicalHandshake,
      urgency: 1,
      payload: payload,
      ttl: 8,
    );
  }

  // ── 取消媒合（PIN 失敗超限）─────────────────────────────────────
  Future<void> cancelHandoff({required String resourceId}) async {
    final db = await _db.database;
    final mat = await db.query(
      'Materials_State',
      where: 'resource_id = ?',
      whereArgs: [resourceId],
      limit: 1,
    );
    if (mat.isEmpty) return;
    final requestId = mat.first['matched_request_id'] as String? ?? '';
    final hlc = HLC.now();

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
    if (requestId.isNotEmpty) {
      await db.update(
        'Requests_State',
        {
          'status': RequestStatus.available,
          'hlc_timestamp': hlc.timestamp,
          'hlc_counter': hlc.counter,
          'matched_resource_id': null,
          'match_expires_at': null,
        },
        where: 'request_id = ?',
        whereArgs: [requestId],
      );
      await db.update(
        'Match_Sessions',
        {
          'status': MatchSessionStatus.cancelled,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'session_id = ?',
        whereArgs: [_sessionIdFor(resourceId, requestId)],
      );

      final payload = Uint8List.fromList((pb.MatchCancelData()
            ..requestId = requestId
            ..resourceId = resourceId
            ..reason = 'HANDOFF_CANCELLED')
          .writeToBuffer());
      await _publishMeshPayload(
        eventType: EventType.matchCancel,
        urgency: 0,
        payload: payload,
        ttl: 8,
      );
    }
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
    return _reporterHex(pubKeyBytes);
  }

  // ── 搜尋附近同類型危險標記 ────────────────────────────────────
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
    final hazardRows = await db.query(
      'Hazards_State',
      where: 'hazard_id = ?',
      whereArgs: [hazardId],
      limit: 1,
    );
    if (hazardRows.isEmpty) return;

    final hazard = hazardRows.first;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      'UPDATE Hazards_State SET confirm_count = confirm_count + 1, '
      'updated_at = ? WHERE hazard_id = ?',
      [now, hazardId],
    );

    final confirmer = await _identity.getPublicKeyBytes();
    final payload = Uint8List.fromList((pb.HazardConfirmData()
          ..hazardId = hazardId
          ..hazardType = (hazard['type'] as String?) ?? ''
          ..severity = (hazard['severity'] as int?) ?? 1
          ..centerLat = (hazard['lat'] as num?)?.toDouble() ?? 0
          ..centerLng = (hazard['lng'] as num?)?.toDouble() ?? 0
          ..radiusMeters = (hazard['radius'] as num?)?.toDouble() ?? 200
          ..observedAt = fixnum.Int64(now)
          ..description = (hazard['description'] as String?) ?? ''
          ..confirmerPubKey = confirmer)
        .writeToBuffer());
    await _publishMeshPayload(
      eventType: EventType.hazardConfirm,
      urgency: 2,
      payload: payload,
      lat: (hazard['lat'] as num?)?.toDouble(),
      lng: (hazard['lng'] as num?)?.toDouble(),
      ttl: 8,
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
        ..radiusMeters = (h['radius'] as num?)?.toDouble() ?? 200
        ..observedAt = fixnum.Int64(now)
        ..description = (h['description'] as String?) ?? '';
      final payload = Uint8List.fromList(hazardData.writeToBuffer());
      await _publishMeshPayload(
        eventType: EventType.hazardMarker,
        urgency: 2,
        payload: payload,
        lat: (h['lat'] as num?)?.toDouble(),
        lng: (h['lng'] as num?)?.toDouble(),
        ttl: 8,
      );
    }
  }

  // ── 刪除（解除）自己的危險標記（同時廣播至 Mesh）────────────
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
        ..radiusMeters = 0
        ..observedAt = fixnum.Int64(DateTime.now().millisecondsSinceEpoch)
        ..description = (h['description'] as String?) ?? '';
      final payload = Uint8List.fromList(hazardData.writeToBuffer());
      await _publishMeshPayload(
        eventType: EventType.hazardMarker,
        urgency: 0,
        payload: payload,
        lat: (h['lat'] as num?)?.toDouble(),
        lng: (h['lng'] as num?)?.toDouble(),
        ttl: 8,
      );
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
  Future<void> cancelSupply(String eventId) async {
    final db = await _db.database;
    final events = await db
        .query('Event_Logs', where: 'event_id = ?', whereArgs: [eventId]);
    if (events.isEmpty) return;

    final payload = events.first['payload'] as Uint8List?;
    String resourceId = '';
    if (payload != null) {
      try {
        final rd = pb.ResourceData.fromBuffer(payload);
        resourceId = rd.resourceId;
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

    await db.delete('Event_Logs', where: 'event_id = ?', whereArgs: [eventId]);

    if (resourceId.isNotEmpty) {
      final cancelPayload = Uint8List.fromList((pb.MatchCancelData()
            ..requestId = ''
            ..resourceId = resourceId
            ..reason = 'SUPPLY_CANCELLED')
          .writeToBuffer());
      await _publishMeshPayload(
        eventType: EventType.matchCancel,
        urgency: 0,
        payload: cancelPayload,
        ttl: 8,
      );
    }
  }

  // ── 取消物資需求 ───────────────────────────────────────────────
  Future<void> cancelRequest(String eventId) async {
    final db = await _db.database;
    await db.delete('Event_Logs', where: 'event_id = ?', whereArgs: [eventId]);
    await db.update(
      'Requests_State',
      {
        'status': RequestStatus.consumed,
        'hlc_timestamp': HLC.now().timestamp,
        'hlc_counter': HLC.now().counter,
      },
      where: 'request_id = ?',
      whereArgs: [eventId],
    );

    final cancelPayload = Uint8List.fromList((pb.MatchCancelData()
          ..requestId = eventId
          ..resourceId = ''
          ..reason = 'REQUEST_CANCELLED')
        .writeToBuffer());
    await _publishMeshPayload(
      eventType: EventType.matchCancel,
      urgency: 0,
      payload: cancelPayload,
      ttl: 8,
    );
  }
}
