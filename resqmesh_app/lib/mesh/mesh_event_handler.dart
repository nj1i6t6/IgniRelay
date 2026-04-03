import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../crdt/hlc.dart';
import '../crypto/identity_manager.dart';
import '../crypto/signer.dart';
import '../db/database_helper.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import '../services/location_service.dart';
import 'event_manager.dart' as event_mgr;
import 'mesh_router.dart';
import 'mesh_transport.dart';

/// 事件類型常數（供 wire payload 解碼使用）
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

/// Wire payload 解碼結果
class WirePayload {
  final String eventId;
  final List<int> payload;
  final int urgency;
  final int eventType;
  final int hlcTimestamp;
  final int hlcCounter;
  final int ttl;
  final double? lat;
  final double? lng;
  final double? originLat;
  final double? originLng;
  final int identityLevel;
  final List<int>? signature;
  final List<int>? senderPubKey;

  WirePayload(
    this.eventId,
    this.payload, {
    this.urgency = 0,
    this.eventType = 0,
    this.hlcTimestamp = 0,
    this.hlcCounter = 0,
    this.ttl = 9,
    this.lat,
    this.lng,
    this.originLat,
    this.originLng,
    this.identityLevel = 0,
    this.signature,
    this.senderPubKey,
  });
}

/// MeshEventHandler — 統一的接收端邏輯
class MeshEventHandler {
  static final MeshEventHandler _instance = MeshEventHandler._internal();
  factory MeshEventHandler() => _instance;
  MeshEventHandler._internal();

  final Set<String> _seenEvents = {};

  final StreamController<MeshDataReceived> _eventStreamController =
      StreamController<MeshDataReceived>.broadcast();
  Stream<MeshDataReceived> get events => _eventStreamController.stream;

  int receivedEventCount = 0;

  static const int _maxDebugLogs = 80;
  final List<String> debugLogs = [];

  void _dlog(String msg) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = '[$ts] $msg';
    debugLogs.add(entry);
    if (debugLogs.length > _maxDebugLogs) debugLogs.removeAt(0);
    debugPrint('[MeshEvt] $msg');
    DatabaseHelper().writeDebugLog('MESH', entry);
  }

  bool hasSeen(String eventId) => _seenEvents.contains(eventId);

  void markSeen(String eventId) => _seenEvents.add(eventId);

  int get seenEventsCount => _seenEvents.length;

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _pubKeyHex(List<int>? bytes, String fallback) {
    if (bytes == null || bytes.isEmpty) return fallback;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<bool> _isIncomingStateNewer(
    Database db,
    String table,
    String idColumn,
    String idValue,
    int incomingTs,
    int incomingCounter,
  ) async {
    final rows = await db.query(
      table,
      columns: ['hlc_timestamp', 'hlc_counter'],
      where: '$idColumn = ?',
      whereArgs: [idValue],
      limit: 1,
    );
    if (rows.isEmpty) return true;
    final currentTs = (rows.first['hlc_timestamp'] as int?) ?? 0;
    final currentCounter = (rows.first['hlc_counter'] as int?) ?? 0;
    if (incomingTs > currentTs) return true;
    if (incomingTs == currentTs && incomingCounter >= currentCounter) {
      return true;
    }
    return false;
  }

  Future<void> handleIncomingData(Uint8List data, String sourceNodeId) async {
    try {
      final decoded = decodeWirePayload(data);
      if (decoded == null) {
        debugPrint('[MeshEvt] Invalid wire payload from $sourceNodeId');
        return;
      }

      final evtId = decoded.eventId;
      final payload = decoded.payload;

      _dlog(
          'RECV ${evtId.substring(0, 8)}.. type=${decoded.eventType} urg=${decoded.urgency} payload=${payload.length}B from $sourceNodeId');

      if (_seenEvents.contains(evtId)) {
        _dlog('RECV SKIP(seen) ${evtId.substring(0, 8)}..');
        return;
      }

      if (decoded.signature == null ||
          decoded.signature!.isEmpty ||
          decoded.senderPubKey == null ||
          decoded.senderPubKey!.isEmpty) {
        _dlog('RECV REJECT(no-sig) ${evtId.substring(0, 8)}..');
        return;
      }

      final verified = await Signer.verifySignature(
        payloadBytes: decoded.payload,
        signatureBytes: decoded.signature!,
        publicKeyBytes: decoded.senderPubKey!,
      );
      if (!verified) {
        _dlog('RECV REJECT(sig-fail) ${evtId.substring(0, 8)}..');
        return;
      }

      if (decoded.originLat != null && decoded.originLng != null) {
        final myLoc = LocationService().currentLocation;
        if (myLoc != null) {
          final shouldForward = await MeshRouter.shouldForwardPacket(
            urgency: decoded.urgency,
            eventType: decoded.eventType,
            originLat: decoded.originLat!,
            originLng: decoded.originLng!,
            myLat: myLoc.latitude,
            myLng: myLoc.longitude,
            maxRangeMeters: 5000.0,
            senderIdentityLevel: decoded.identityLevel,
            isHardwareMule: false,
            isAndroidTier1Foreground: false,
          );
          if (!shouldForward) {
            _dlog('RECV ROUTE_DROP ${evtId.substring(0, 8)}.. (out of zone)');
            return;
          }
        }
      }

      if (decoded.hlcTimestamp > 0) {
        HLC.merge(HLC(decoded.hlcTimestamp, decoded.hlcCounter));
      } else {
        HLC.merge(HLC(DateTime.now().millisecondsSinceEpoch, 0));
      }

      final db = await DatabaseHelper().database;
      var inserted = false;
      try {
        await db.insert('Event_Logs', {
          'event_id': evtId,
          'sender_pub_key': Uint8List.fromList(decoded.senderPubKey!),
          'identity_level': decoded.identityLevel,
          'event_type': decoded.eventType,
          'urgency': decoded.urgency,
          'hlc_timestamp': decoded.hlcTimestamp > 0
              ? decoded.hlcTimestamp
              : DateTime.now().millisecondsSinceEpoch,
          'hlc_counter': decoded.hlcCounter,
          'ttl': decoded.ttl > 0 ? decoded.ttl - 1 : 9,
          'received_lat': decoded.lat,
          'received_lng': decoded.lng,
          'origin_lat': decoded.originLat,
          'origin_lng': decoded.originLng,
          'node_tier': 2,
          'chunk_index': 0,
          'total_chunks': 1,
          'payload': Uint8List.fromList(payload),
          'signature': Uint8List.fromList(decoded.signature!),
          'is_synced': 0,
        });
        inserted = true;
      } catch (e) {
        _seenEvents.add(evtId);
        _dlog('RECV SKIP(db-dup) ${evtId.substring(0, 8)}.. $e');
        return;
      }

      if (!inserted) return;
      _seenEvents.add(evtId);

      await _projectEvent(decoded, payload, sourceNodeId, db);

      receivedEventCount++;
      _eventStreamController.add(
        MeshDataReceived(sourceNodeId, Uint8List.fromList(payload)),
      );
      debugPrint(
          '[MeshEvt] Stored event $evtId (${payload.length} bytes) from $sourceNodeId');
    } catch (e) {
      debugPrint('[MeshEvt] Parse error: $e');
    }
  }

  Future<void> _projectEvent(
    WirePayload decoded,
    List<int> payload,
    String sourceNodeId,
    Database db,
  ) async {
    switch (decoded.eventType) {
      case EventType.resourceRegister:
        await _handleResourceEvent(decoded, payload, sourceNodeId, db);
        return;
      case EventType.requestBroadcast:
        await _handleRequestEvent(decoded, payload, sourceNodeId, db);
        return;
      case EventType.matchIntent:
        await _handleMatchIntentEvent(decoded, payload, db);
        return;
      case EventType.matchConfirm:
        await _handleMatchConfirmEvent(payload);
        return;
      case EventType.matchReject:
        await _handleMatchRejectEvent(payload);
        return;
      case EventType.matchCancel:
        await _handleMatchCancelEvent(payload);
        return;
      case EventType.physicalHandshake:
        await _handlePhysicalHandshakeEvent(payload);
        return;
      case EventType.hazardMarker:
        await _handleHazardEvent(decoded, payload, sourceNodeId, db);
        return;
      case EventType.hazardConfirm:
        await _handleHazardConfirmEvent(decoded, payload, sourceNodeId, db);
        return;
      case EventType.chatMessage:
        await _handleChatEvent(decoded, payload, sourceNodeId, db);
        return;
      case EventType.matchLocationUpdate:
        await _handleMatchLocationUpdateEvent(payload);
        return;
      default:
        return;
    }
  }

  Future<void> _handleResourceEvent(
    WirePayload decoded,
    List<int> payload,
    String sourceNodeId,
    Database db,
  ) async {
    try {
      final data = pb.ResourceData.fromBuffer(payload);
      if (data.resourceId.isEmpty) return;
      final incomingTs = decoded.hlcTimestamp > 0
          ? decoded.hlcTimestamp
          : DateTime.now().millisecondsSinceEpoch;
      final shouldApply = await _isIncomingStateNewer(
        db,
        'Materials_State',
        'resource_id',
        data.resourceId,
        incomingTs,
        decoded.hlcCounter,
      );
      if (!shouldApply) return;
      await db.insert(
        'Materials_State',
        {
          'resource_id': data.resourceId,
          'status': event_mgr.MaterialStatus.available,
          'hlc_timestamp': incomingTs,
          'hlc_counter': decoded.hlcCounter,
          'matched_request_id': null,
          'match_expires_at': null,
          'payload': Uint8List.fromList(payload),
          'provider_pub_key': Uint8List.fromList(decoded.senderPubKey!),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _dlog('RESOURCE_SYNC ${data.resourceId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Resource sync skipped: $e');
    }
  }

  Future<void> _handleRequestEvent(
    WirePayload decoded,
    List<int> payload,
    String sourceNodeId,
    Database db,
  ) async {
    try {
      final data = pb.RequestData.fromBuffer(payload);
      if (data.requestId.isEmpty) return;
      final incomingTs = decoded.hlcTimestamp > 0
          ? decoded.hlcTimestamp
          : DateTime.now().millisecondsSinceEpoch;
      final shouldApply = await _isIncomingStateNewer(
        db,
        'Requests_State',
        'request_id',
        data.requestId,
        incomingTs,
        decoded.hlcCounter,
      );
      if (!shouldApply) return;
      await db.insert(
        'Requests_State',
        {
          'request_id': data.requestId,
          'status': event_mgr.RequestStatus.available,
          'hlc_timestamp': incomingTs,
          'hlc_counter': decoded.hlcCounter,
          'matched_resource_id': null,
          'match_expires_at': null,
          'payload': Uint8List.fromList(payload),
          'requester_pub_key': Uint8List.fromList(decoded.senderPubKey!),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _dlog('REQUEST_SYNC ${data.requestId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Request sync skipped: $e');
    }
  }

  Future<void> _handleMatchIntentEvent(
    WirePayload decoded,
    List<int> payload,
    Database db,
  ) async {
    try {
      final data = pb.MatchIntentData.fromBuffer(payload);
      final myPubKey = await IdentityManager().getPublicKeyBytes();
      if (!_bytesEqual(myPubKey, data.requesterPubKey)) return;
      await event_mgr.EventManager().respondToMatchIntent(data);
      _dlog('MATCH_INTENT ${data.requestId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Match intent handling skipped: $e');
    }
  }

  Future<void> _handleMatchConfirmEvent(List<int> payload) async {
    try {
      final data = pb.MatchConfirmData.fromBuffer(payload);
      await event_mgr.EventManager().handleMatchConfirm(data);
      _dlog('MATCH_CONFIRM ${data.requestId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Match confirm skipped: $e');
    }
  }

  Future<void> _handleMatchRejectEvent(List<int> payload) async {
    try {
      final data = pb.MatchRejectData.fromBuffer(payload);
      await event_mgr.EventManager().handleMatchReject(data);
      _dlog('MATCH_REJECT ${data.requestId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Match reject skipped: $e');
    }
  }

  Future<void> _handleMatchCancelEvent(List<int> payload) async {
    try {
      final data = pb.MatchCancelData.fromBuffer(payload);
      await event_mgr.EventManager().handleMatchCancelEvent(data);
      _dlog('MATCH_CANCEL ${data.requestId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Match cancel skipped: $e');
    }
  }

  Future<void> _handlePhysicalHandshakeEvent(List<int> payload) async {
    try {
      final data = pb.PhysicalHandshakeData.fromBuffer(payload);
      await event_mgr.EventManager().handlePhysicalHandshakeEvent(data);
      _dlog('HANDSHAKE ${data.requestId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Physical handshake skipped: $e');
    }
  }

  Future<void> _handleMatchLocationUpdateEvent(List<int> payload) async {
    try {
      final data = pb.MatchLocationUpdateData.fromBuffer(payload);
      await event_mgr.EventManager().handleRemoteLocationUpdate(data);
      _dlog('MATCH_LOC ${data.requestId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Match location update skipped: $e');
    }
  }

  Future<void> _handleHazardEvent(
    WirePayload decoded,
    List<int> payload,
    String sourceNodeId,
    Database db,
  ) async {
    try {
      final hazard = pb.HazardData.fromBuffer(payload);
      if (hazard.hazardId.isEmpty) return;

      if (hazard.severity == 0 || hazard.radiusMeters <= 0) {
        await db.delete(
          'Hazards_State',
          where: 'hazard_id = ?',
          whereArgs: [hazard.hazardId],
        );
        _dlog('HAZARD_DELETE ${hazard.hazardId.substring(0, 8)}..');
        return;
      }

      final reporterHex = _pubKeyHex(decoded.senderPubKey, sourceNodeId);
      final existing = await db.query(
        'Hazards_State',
        where: 'hazard_id = ?',
        whereArgs: [hazard.hazardId],
        limit: 1,
      );
      final confirmCount = existing.isNotEmpty
          ? (((existing.first['confirm_count'] as int?) ?? 1) < 1
              ? 1
              : (existing.first['confirm_count'] as int?) ?? 1)
          : 1;
      await db.insert(
        'Hazards_State',
        {
          'hazard_id': hazard.hazardId,
          'type': hazard.hazardType,
          'severity': hazard.severity,
          'lat': hazard.centerLat,
          'lng': hazard.centerLng,
          'radius': hazard.radiusMeters > 0 ? hazard.radiusMeters : 200.0,
          'reported_by': reporterHex,
          'created_at': hazard.observedAt.toInt() > 0
              ? hazard.observedAt.toInt()
              : DateTime.now().millisecondsSinceEpoch,
          'confirm_count': confirmCount,
          'description':
              hazard.description.isNotEmpty ? hazard.description : null,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _dlog('HAZARD_SYNC ${hazard.hazardId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Hazard sync skipped: $e');
    }
  }

  Future<void> _handleHazardConfirmEvent(
    WirePayload decoded,
    List<int> payload,
    String sourceNodeId,
    Database db,
  ) async {
    try {
      final hazard = pb.HazardConfirmData.fromBuffer(payload);
      if (hazard.hazardId.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final existing = await db.query(
        'Hazards_State',
        where: 'hazard_id = ?',
        whereArgs: [hazard.hazardId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('Hazards_State', {
          'hazard_id': hazard.hazardId,
          'type': hazard.hazardType,
          'severity': hazard.severity,
          'lat': hazard.centerLat,
          'lng': hazard.centerLng,
          'radius': hazard.radiusMeters > 0 ? hazard.radiusMeters : 200.0,
          'reported_by': _pubKeyHex(decoded.senderPubKey, sourceNodeId),
          'created_at':
              hazard.observedAt.toInt() > 0 ? hazard.observedAt.toInt() : now,
          'confirm_count': 1,
          'description':
              hazard.description.isNotEmpty ? hazard.description : null,
          'updated_at': now,
        });
      } else {
        final confirmCount =
            ((existing.first['confirm_count'] as int?) ?? 1) + 1;
        await db.update(
          'Hazards_State',
          {
            'type': hazard.hazardType,
            'severity': hazard.severity,
            'lat': hazard.centerLat,
            'lng': hazard.centerLng,
            'radius': hazard.radiusMeters > 0 ? hazard.radiusMeters : 200.0,
            'confirm_count': confirmCount,
            'description': hazard.description.isNotEmpty
                ? hazard.description
                : existing.first['description'],
            'updated_at': now,
          },
          where: 'hazard_id = ?',
          whereArgs: [hazard.hazardId],
        );
      }
      _dlog('HAZARD_CONFIRM ${hazard.hazardId.substring(0, 8)}..');
    } catch (e) {
      debugPrint('[MeshEvt] Hazard confirm skipped: $e');
    }
  }

  Future<void> _handleChatEvent(
    WirePayload decoded,
    List<int> payload,
    String sourceNodeId,
    Database db,
  ) async {
    try {
      final jsonStr = utf8.decode(payload);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final roomId = map['room_id'] as String?;
      final content = map['content'] as String?;
      if (roomId == null ||
          roomId.isEmpty ||
          content == null ||
          content.isEmpty) {
        debugPrint('[MeshEvt] Chat event missing room_id or content');
        return;
      }

      final room = await db.query(
        'Chat_Rooms',
        columns: ['room_id'],
        where: 'room_id = ?',
        whereArgs: [roomId],
        limit: 1,
      );
      if (room.isEmpty) {
        _dlog('CHAT_SKIP(not-joined) room=$roomId');
        return;
      }

      final senderPubKey = decoded.senderPubKey != null
          ? Uint8List.fromList(decoded.senderPubKey!)
          : Uint8List.fromList(utf8.encode(sourceNodeId));

      await db.insert(
        'Chat_Messages',
        {
          'event_id': decoded.eventId,
          'room_id': roomId,
          'sender_pub_key': senderPubKey,
          'content': content,
          'reply_to': map['reply_to'] as String?,
          'hlc_timestamp': decoded.hlcTimestamp > 0
              ? decoded.hlcTimestamp
              : DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      _dlog('CHAT_INSERT ${decoded.eventId.substring(0, 8)}.. room=$roomId');
    } catch (e) {
      debugPrint('[MeshEvt] Chat event insert skipped: $e');
    }
  }

  static List<int> encodeWirePayload(
    String eventId,
    List<int> payload, {
    int urgency = 0,
    int eventType = 0,
    List<int>? signature,
    List<int>? senderPubKey,
    int? hlcTimestamp,
    int? hlcCounter,
    int ttl = 10,
    double? lat,
    double? lng,
    double? originLat,
    double? originLng,
  }) {
    final meshEvent = pb.MeshEvent()
      ..eventId = eventId
      ..urgency = pb.UrgencyLevel.valueOf(urgency) ?? pb.UrgencyLevel.INFO
      ..type = pb.EventType.valueOf(eventType) ?? pb.EventType.RESOURCE_REGISTER
      ..payload = payload
      ..ttl = ttl;
    if (signature != null) meshEvent.signature = signature;
    if (senderPubKey != null) meshEvent.senderPubKey = senderPubKey;
    if (hlcTimestamp != null) {
      meshEvent.hlcTimestamp = fixnum.Int64(hlcTimestamp);
    }
    if (hlcCounter != null) {
      meshEvent.hlcCounter = fixnum.Int64(hlcCounter);
    }
    if (lat != null) meshEvent.receivedLat = lat;
    if (lng != null) meshEvent.receivedLng = lng;
    if (originLat != null) meshEvent.originLat = originLat;
    if (originLng != null) meshEvent.originLng = originLng;
    return meshEvent.writeToBuffer();
  }

  static WirePayload? decodeWirePayload(List<int> data) {
    try {
      final meshEvent = pb.MeshEvent.fromBuffer(data);
      if (meshEvent.eventId.isNotEmpty) {
        return WirePayload(
          meshEvent.eventId,
          meshEvent.payload,
          urgency: meshEvent.urgency.value,
          eventType: meshEvent.type.value,
          hlcTimestamp: meshEvent.hlcTimestamp.toInt(),
          hlcCounter: meshEvent.hlcCounter.toInt(),
          ttl: meshEvent.ttl,
          lat: meshEvent.receivedLat,
          lng: meshEvent.receivedLng,
          originLat: meshEvent.originLat != 0 ? meshEvent.originLat : null,
          originLng: meshEvent.originLng != 0 ? meshEvent.originLng : null,
          identityLevel: meshEvent.identityLevel,
          signature: meshEvent.signature,
          senderPubKey: meshEvent.senderPubKey,
        );
      }
    } catch (_) {}

    try {
      final pipeIndex = data.indexOf(0x7C);
      if (pipeIndex < 1) return null;
      final eventId = utf8.decode(data.sublist(0, pipeIndex));
      final payload = data.sublist(pipeIndex + 1);
      return WirePayload(eventId, payload);
    } catch (_) {
      return null;
    }
  }

  static const int kBloomSizeBytes = 2048;
  static const int kBloomHashCount = 7;
  static const List<int> kBloomMagic = [0xFF, 0xBF, 0x02, 0x00];

  static bool _hasBloomMagic(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0xFF &&
        bytes[1] == 0xBF &&
        bytes[2] == 0x02 &&
        bytes[3] == 0x00;
  }

  static int _murmurHash(String s, {required int seed}) {
    int h = seed;
    for (final c in s.codeUnits) {
      int k = c;
      k = (k * 0xcc9e2d51) & 0xFFFFFFFF;
      k = ((k << 15) | (k >> 17)) & 0xFFFFFFFF;
      k = (k * 0x1b873593) & 0xFFFFFFFF;
      h ^= k;
      h = ((h << 13) | (h >> 19)) & 0xFFFFFFFF;
      h = (h * 5 + 0xe6546b64) & 0xFFFFFFFF;
    }
    h ^= s.length;
    h ^= h >> 16;
    h = (h * 0x85ebca6b) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 0xc2b2ae35) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h;
  }

  static Uint8List buildBitVectorBloom(Set<String> eventIds) {
    final bits = Uint8List(kBloomSizeBytes + 4);
    bits[0] = 0xFF;
    bits[1] = 0xBF;
    bits[2] = 0x02;
    bits[3] = 0x00;
    for (final id in eventIds) {
      for (int i = 0; i < kBloomHashCount; i++) {
        final hash = _murmurHash(id, seed: i) % (kBloomSizeBytes * 8);
        bits[4 + (hash >> 3)] |= (1 << (hash & 7));
      }
    }
    return bits;
  }

  static bool bloomMayContain(List<int> bloom, String eventId) {
    final offset = _hasBloomMagic(bloom) ? 4 : 0;
    final size = bloom.length - offset;
    if (size <= 0) return false;
    for (int i = 0; i < kBloomHashCount; i++) {
      final hash = _murmurHash(eventId, seed: i) % (size * 8);
      if ((bloom[offset + (hash >> 3)] & (1 << (hash & 7))) == 0) {
        return false;
      }
    }
    return true;
  }

  static Set<String> parseBloomFilter(List<int> bytes) {
    final result = <String>{};
    if (bytes.isEmpty) return result;
    if (_hasBloomMagic(bytes)) return result;
    try {
      final str = utf8.decode(bytes);
      for (final id in str.split('\n')) {
        final trimmed = id.trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
      }
    } catch (_) {}
    return result;
  }

  static Future<Uint8List> buildLocalBloomFilter({int limit = 500}) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'Event_Logs',
      columns: ['event_id'],
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );
    final ids = rows.map((r) => r['event_id'] as String).toSet();
    return buildBitVectorBloom(ids);
  }

  Future<Set<String>> getLocalEventIds({bool excludeChat = true}) async {
    final db = await DatabaseHelper().database;
    String where = '';
    if (excludeChat) where = 'WHERE event_type != ${EventType.chatMessage}';
    final rows = await db.rawQuery('SELECT event_id FROM Event_Logs $where');
    return rows.map((r) => r['event_id'] as String).toSet();
  }

  Future<List<Map<String, dynamic>>> getEventsByKeyHashes(
      Set<int> keyHashes) async {
    if (keyHashes.isEmpty) return [];
    final db = await DatabaseHelper().database;
    final cutoff24h =
        DateTime.now().millisecondsSinceEpoch - (24 * 3600 * 1000);
    final allEvents = await db.query(
      'Event_Logs',
      columns: [
        'event_id',
        'payload',
        'signature',
        'urgency',
        'event_type',
        'sender_pub_key',
        'hlc_timestamp',
        'hlc_counter',
        'received_lat',
        'received_lng',
        'origin_lat',
        'origin_lng',
      ],
      where: 'hlc_timestamp > ? AND event_type != ${EventType.chatMessage}',
      whereArgs: [cutoff24h],
      orderBy: 'urgency DESC, hlc_timestamp DESC',
    );

    final result = <Map<String, dynamic>>[];
    for (final evt in allEvents) {
      final evtId = evt['event_id'] as String;
      final crc = _crc32EventId(evtId);
      if (keyHashes.contains(crc)) {
        result.add(evt);
      }
    }
    return result;
  }

  static int _crc32EventId(String s) {
    int crc = 0xFFFFFFFF;
    for (final b in s.codeUnits) {
      crc ^= b;
      for (int j = 0; j < 8; j++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return crc ^ 0xFFFFFFFF;
  }

  void dispose() {
    _eventStreamController.close();
  }
}
