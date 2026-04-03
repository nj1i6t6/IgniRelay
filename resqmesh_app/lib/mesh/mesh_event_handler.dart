import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import '../crdt/hlc.dart';
import '../crypto/signer.dart';
import '../db/database_helper.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
import '../crypto/identity_manager.dart';
import '../services/location_service.dart';
import 'mesh_router.dart';
import 'mesh_transport.dart';

/// 待處理的媒合回應（供 EventManager 輪詢）
class PendingMatchAction {
  final String type; // 'CONFIRM' or 'REJECT'
  final String requestId;
  final String resourceId;
  final List<int> requesterPubKey;
  final List<int> providerPubKey;
  final String reason;

  PendingMatchAction({
    required this.type,
    required this.requestId,
    required this.resourceId,
    required this.requesterPubKey,
    required this.providerPubKey,
    this.reason = '',
  });
}

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
  static const int locationUpdate = 14;
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
///
/// 從 BleManager._handleIncomingPayload 抽取而來。
/// 負責：Protobuf 解碼、去重、HLC merge、DB 寫入、Hazard 特殊處理。
/// 兩種 Transport（Bridgefy / NativeBLE）共用同一套處理邏輯。
class MeshEventHandler {
  static final MeshEventHandler _instance = MeshEventHandler._internal();
  factory MeshEventHandler() => _instance;
  MeshEventHandler._internal();

  // 已看過的 event_id（去重）
  final Set<String> _seenEvents = {};

  // (已移除全網聊天限流 — 僅保留前端限流)

  // 接收事件 stream（供上層 UI 監聽）
  final StreamController<MeshDataReceived> _eventStreamController =
      StreamController<MeshDataReceived>.broadcast();
  Stream<MeshDataReceived> get events => _eventStreamController.stream;

  int receivedEventCount = 0;

  // ── Debug Log ──────────────────────────────────────────────────
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

  /// 檢查事件是否已見過（去重查詢）
  bool hasSeen(String eventId) => _seenEvents.contains(eventId);

  /// 手動標記事件為已見過
  void markSeen(String eventId) => _seenEvents.add(eventId);

  /// 已見過事件數量
  int get seenEventsCount => _seenEvents.length;

  /// 處理從任何 transport 接收到的 raw bytes
  Future<void> handleIncomingData(
      Uint8List data, String sourceNodeId) async {
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
      // ── DB 層級去重（防重啟後重播攻擊）─────────────────────────
      final db = await DatabaseHelper().database;
      final existingEvt = await db.query('Event_Logs',
          columns: ['event_id'],
          where: 'event_id = ?',
          whereArgs: [evtId],
          limit: 1);
      if (existingEvt.isNotEmpty) {
        _seenEvents.add(evtId); // 補進記憶體快取
        _dlog('RECV SKIP(db-dup) ${evtId.substring(0, 8)}..');
        return;
      }
      // ── Ed25519 簽章驗證 ──────────────────────────────────────
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

      // ── Zone-Based 地理圍欄路由判斷 ─────────────────────────────
      // 僅當封包帶有原始座標時判斷；無座標（舊版或本機事件）直接通過。
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

      // 合併 HLC（確保時間同步）
      if (decoded.hlcTimestamp > 0) {
        HLC.merge(HLC(decoded.hlcTimestamp, decoded.hlcCounter));
      } else {
        HLC.merge(HLC(DateTime.now().millisecondsSinceEpoch, 0));
      }

      // 存入本地資料庫
      try {
        await db.insert('Event_Logs', {
          'event_id': evtId,
          'sender_pub_key': decoded.senderPubKey != null
              ? Uint8List.fromList(decoded.senderPubKey!)
              : Uint8List.fromList(utf8.encode(sourceNodeId)),
          'identity_level': 0,
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
          'signature': decoded.signature != null
              ? Uint8List.fromList(decoded.signature!)
              : Uint8List(0),
          'is_synced': 0,
        });
        // DB insert 成功後才加入去重快取
        _seenEvents.add(evtId);
      } catch (e) {
        // UNIQUE constraint 失敗代表已有此事件，忽略
        _seenEvents.add(evtId); // 既然 DB 有了，也加入快取
        debugPrint('[MeshEvt] DB insert skipped (duplicate): $evtId');
        return; // DB 已有此事件，不需要重複處理
      }

      // 如果是物資登記事件，投影到 Materials_State
      if (decoded.eventType == EventType.resourceRegister && payload.isNotEmpty) {
        await _handleResourceRegisterEvent(decoded, payload, evtId, db);
      }

      // 如果是需求廣播事件，投影到 Requests_State
      if (decoded.eventType == EventType.requestBroadcast && payload.isNotEmpty) {
        await _handleRequestBroadcastEvent(decoded, payload, evtId, db);
      }

      // 如果是危險區域事件，寫入 Hazards_State
      if (decoded.eventType == EventType.hazardMarker && payload.isNotEmpty) {
        await _handleHazardEvent(decoded, payload, sourceNodeId, db);
      }

      // 如果是聊天訊息事件，寫入 Chat_Messages
      if (decoded.eventType == EventType.chatMessage && payload.isNotEmpty) {
        await _handleChatEvent(decoded, payload, sourceNodeId, db);
      }

      // 媒合意向：供給者發起 → 需求者收到
      if (decoded.eventType == EventType.matchIntent && payload.isNotEmpty) {
        await _handleMatchIntentEvent(decoded, payload, db);
      }

      // 媒合確認：需求者確認 → 全網收到
      if (decoded.eventType == EventType.matchConfirm && payload.isNotEmpty) {
        await _handleMatchConfirmEvent(decoded, payload, db);
      }

      // 媒合拒絕：需求者拒絕 → 供給者收到
      if (decoded.eventType == EventType.matchReject && payload.isNotEmpty) {
        await _handleMatchRejectEvent(decoded, payload, db);
      }

      // 取消配對事件：更新本地狀態
      if (decoded.eventType == EventType.matchCancel && payload.isNotEmpty) {
        await _handleMatchCancelEvent(decoded, payload, db);
      }

      // 物理交割事件：標記完成
      if (decoded.eventType == EventType.physicalHandshake && payload.isNotEmpty) {
        await _handlePhysicalHandshakeEvent(decoded, payload, db);
      }

      // 位置更新事件：更新 Match_Sessions
      if (decoded.eventType == EventType.locationUpdate && payload.isNotEmpty) {
        await _handleLocationUpdateEvent(decoded, payload, db);
      }

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

  /// 處理遠端物資登記：投影到 Materials_State
  Future<void> _handleResourceRegisterEvent(
    WirePayload decoded,
    List<int> payload,
    String eventId,
    dynamic db,
  ) async {
    try {
      final rd = pb.ResourceData.fromBuffer(payload);
      if (rd.resourceId.isEmpty) return;
      await db.insert('Materials_State', {
        'resource_id': rd.resourceId,
        'status': 'AVAILABLE',
        'hlc_timestamp': decoded.hlcTimestamp > 0
            ? decoded.hlcTimestamp
            : DateTime.now().millisecondsSinceEpoch,
        'hlc_counter': decoded.hlcCounter,
        'matched_request_id': null,
        'match_expires_at': null,
        'payload': Uint8List.fromList(payload),
      });
      _dlog('SUPPLY_SYNC ${rd.resourceId.substring(0, 8)}.. to Materials_State');
    } catch (e) {
      // UNIQUE constraint = 已有此物資，忽略
      debugPrint('[MeshEvt] Materials_State insert skipped: $e');
    }
  }

  /// 處理遠端需求廣播：投影到 Requests_State
  Future<void> _handleRequestBroadcastEvent(
    WirePayload decoded,
    List<int> payload,
    String eventId,
    dynamic db,
  ) async {
    try {
      final rd = pb.RequestData.fromBuffer(payload);
      if (rd.requestId.isEmpty) return;
      await db.insert('Requests_State', {
        'request_id': rd.requestId,
        'event_id': eventId,
        'sender_pub_key': decoded.senderPubKey != null
            ? Uint8List.fromList(decoded.senderPubKey!)
            : Uint8List(0),
        'status': 'AVAILABLE',
        'hlc_timestamp': decoded.hlcTimestamp > 0
            ? decoded.hlcTimestamp
            : DateTime.now().millisecondsSinceEpoch,
        'hlc_counter': decoded.hlcCounter,
        'matched_resource_id': null,
        'match_expires_at': null,
        'payload': Uint8List.fromList(payload),
      });
      _dlog('REQUEST_SYNC ${rd.requestId.substring(0, 8)}.. to Requests_State');
    } catch (e) {
      debugPrint('[MeshEvt] Requests_State insert skipped: $e');
    }
  }

  /// 處理危險區域事件的特殊邏輯
  Future<void> _handleHazardEvent(
    WirePayload decoded,
    List<int> payload,
    String sourceNodeId,
    dynamic db,
  ) async {
    try {
      final hazard = pb.HazardData.fromBuffer(payload);
      if (hazard.hazardId.isNotEmpty &&
          hazard.centerLat != 0 &&
          hazard.centerLng != 0) {
        final reporterHex = decoded.senderPubKey != null
            ? decoded.senderPubKey!
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join()
            : sourceNodeId;
        // 如果是確認事件（附議），只增加 confirm_count
        if (hazard.isConfirmation) {
          await db.rawUpdate(
            'UPDATE Hazards_State SET confirm_count = confirm_count + 1, '
            'updated_at = ? WHERE hazard_id = ?',
            [DateTime.now().millisecondsSinceEpoch, hazard.hazardId],
          );
          debugPrint('[MeshEvt] Hazard confirmation synced: ${hazard.hazardId}');
          return;
        }

        await db.insert('Hazards_State', {
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
          'confirm_count': 1,
          'description': hazard.description.isNotEmpty ? hazard.description : null,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
        debugPrint(
            '[MeshEvt] Hazard synced to Hazards_State: ${hazard.hazardId}');
      }
    } catch (e) {
      debugPrint('[MeshEvt] Hazard sync skipped: $e');
    }
  }

  /// 處理聊天訊息事件：解碼 JSON payload 並寫入 Chat_Messages
  Future<void> _handleChatEvent(
    WirePayload decoded,
    List<int> payload,
    String sourceNodeId,
    dynamic db,
  ) async {
    try {
      final jsonStr = utf8.decode(payload);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final roomId = map['room_id'] as String?;
      final content = map['content'] as String?;
      if (roomId == null || roomId.isEmpty || content == null || content.isEmpty) {
        debugPrint('[MeshEvt] Chat event missing room_id or content');
        return;
      }

      // 檢查用戶是否已加入此聊天室（避免跨聊天室顯示）
      final room = await db.query('Chat_Rooms',
          columns: ['room_id'],
          where: 'room_id = ?',
          whereArgs: [roomId],
          limit: 1) as List<Map<String, dynamic>>;
      if (room.isEmpty) {
        _dlog('CHAT_SKIP(not-joined) room=$roomId');
        return;
      }

      final senderPubKey = decoded.senderPubKey != null
          ? Uint8List.fromList(decoded.senderPubKey!)
          : Uint8List.fromList(utf8.encode(sourceNodeId));

      await db.insert('Chat_Messages', {
        'event_id': decoded.eventId,
        'room_id': roomId,
        'sender_pub_key': senderPubKey,
        'content': content,
        'reply_to': map['reply_to'] as String?,
        'hlc_timestamp': decoded.hlcTimestamp > 0
            ? decoded.hlcTimestamp
            : DateTime.now().millisecondsSinceEpoch,
      });
      _dlog('CHAT_INSERT ${decoded.eventId.substring(0, 8)}.. room=$roomId');
    } catch (e) {
      debugPrint('[MeshEvt] Chat event insert skipped: $e');
    }
  }

  /// 處理 MATCH_INTENT：供給者發起媒合意向
  /// 需求者收到後，檢查需求是否仍可用，自動回覆 CONFIRM 或 REJECT
  Future<void> _handleMatchIntentEvent(
    WirePayload decoded,
    List<int> payload,
    dynamic db,
  ) async {
    try {
      final intent = pb.MatchIntentData.fromBuffer(payload);
      _dlog('MATCH_INTENT received: resource=${intent.resourceId.substring(0, 8)}.. request=${intent.requestId.substring(0, 8)}..');

      // 檢查這筆需求是否是自己的且仍可用
      final myPubKey = await _getMyPubKeyBytes();
      if (!_bytesEqual(intent.requesterPubKey, myPubKey)) {
        // 不是給我的 intent，忽略（但事件已存入 Event_Logs）
        return;
      }

      // 檢查 Requests_State（如果有的話）
      final reqRows = await db.query('Requests_State',
          where: 'request_id = ?',
          whereArgs: [intent.requestId],
          limit: 1);

      bool isAvailable = true;
      if (reqRows.isNotEmpty) {
        final status = reqRows.first['status'] as String?;
        isAvailable = (status == 'AVAILABLE');
      }

      if (isAvailable) {
        // 鎖定需求
        if (reqRows.isNotEmpty) {
          await db.update(
            'Requests_State',
            {
              'status': 'LOCKED',
              'matched_resource_id': intent.resourceId,
              'match_expires_at': DateTime.now().millisecondsSinceEpoch + (30 * 60 * 1000),
            },
            where: 'request_id = ?',
            whereArgs: [intent.requestId],
          );
        }
        // 通知上層自動發 MATCH_CONFIRM（透過 stream callback）
        _pendingConfirms.add(PendingMatchAction(
          type: 'CONFIRM',
          requestId: intent.requestId,
          resourceId: intent.resourceId,
          requesterPubKey: intent.requesterPubKey,
          providerPubKey: intent.providerPubKey,
        ));
        _dlog('MATCH_INTENT → auto CONFIRM for ${intent.requestId.substring(0, 8)}..');
      } else {
        _pendingConfirms.add(PendingMatchAction(
          type: 'REJECT',
          requestId: intent.requestId,
          resourceId: intent.resourceId,
          requesterPubKey: intent.requesterPubKey,
          providerPubKey: intent.providerPubKey,
          reason: 'ALREADY_LOCKED',
        ));
        _dlog('MATCH_INTENT → auto REJECT for ${intent.requestId.substring(0, 8)}.. (already locked)');
      }
    } catch (e) {
      debugPrint('[MeshEvt] MATCH_INTENT handler error: $e');
    }
  }

  /// 處理 MATCH_CONFIRM：需求者確認媒合
  Future<void> _handleMatchConfirmEvent(
    WirePayload decoded,
    List<int> payload,
    dynamic db,
  ) async {
    try {
      final confirm = pb.MatchConfirmData.fromBuffer(payload);
      _dlog('MATCH_CONFIRM received: resource=${confirm.resourceId.substring(0, 8)}.. request=${confirm.requestId.substring(0, 8)}..');

      // 鎖定供給方 Materials_State
      await db.update(
        'Materials_State',
        {
          'status': 'LOCKED',
          'matched_request_id': confirm.requestId,
          'match_expires_at': DateTime.now().millisecondsSinceEpoch + (4 * 3600 * 1000),
        },
        where: "resource_id = ? AND status IN ('AVAILABLE', 'PENDING')",
        whereArgs: [confirm.resourceId],
      );

      // 建立 Match_Session
      final sessionId = '${confirm.resourceId}_${confirm.requestId}';
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.insert('Match_Sessions', {
          'session_id': sessionId,
          'resource_id': confirm.resourceId,
          'request_id': confirm.requestId,
          'provider_pub_key': Uint8List.fromList(confirm.providerPubKey),
          'requester_pub_key': Uint8List.fromList(confirm.requesterPubKey),
          'status': 'ACTIVE',
          'created_at': now,
          'updated_at': now,
        });
      } catch (_) {
        // session 可能已存在
      }

      _dlog('MATCH_CONFIRM → session created, supply LOCKED');
    } catch (e) {
      debugPrint('[MeshEvt] MATCH_CONFIRM handler error: $e');
    }
  }

  /// 處理 MATCH_REJECT：需求者拒絕媒合
  Future<void> _handleMatchRejectEvent(
    WirePayload decoded,
    List<int> payload,
    dynamic db,
  ) async {
    try {
      final reject = pb.MatchRejectData.fromBuffer(payload);
      _dlog('MATCH_REJECT received: resource=${reject.resourceId.substring(0, 8)}.. reason=${reject.reason}');

      // 釋放供給方 Materials_State 回 AVAILABLE
      await db.update(
        'Materials_State',
        {
          'status': 'AVAILABLE',
          'matched_request_id': null,
          'match_expires_at': null,
        },
        where: "resource_id = ? AND status = 'PENDING'",
        whereArgs: [reject.resourceId],
      );

      _dlog('MATCH_REJECT → supply released back to AVAILABLE');
    } catch (e) {
      debugPrint('[MeshEvt] MATCH_REJECT handler error: $e');
    }
  }

  /// 處理 MATCH_CANCEL：取消配對
  Future<void> _handleMatchCancelEvent(
    WirePayload decoded,
    List<int> payload,
    dynamic db,
  ) async {
    try {
      final cancelStr = utf8.decode(payload);
      // 格式: CANCEL:SUPPLY:eventId 或 CANCEL:REQUEST:eventId
      final parts = cancelStr.split(':');
      if (parts.length >= 3 && parts[0] == 'CANCEL') {
        final cancelType = parts[1]; // SUPPLY or REQUEST
        if (cancelType == 'SUPPLY') {
          // 從 Event_Logs 找到被取消的供給的 payload 並清理 Materials_State
          final evtId = parts[2];
          final events = await db.query('Event_Logs',
              where: 'event_id = ?', whereArgs: [evtId], limit: 1);
          if (events.isNotEmpty) {
            final evtPayload = events.first['payload'] as Uint8List?;
            if (evtPayload != null) {
              try {
                final rd = pb.ResourceData.fromBuffer(evtPayload);
                await db.update(
                  'Materials_State',
                  {'status': 'CONSUMED'},
                  where: 'resource_id = ?',
                  whereArgs: [rd.resourceId],
                );
              } catch (_) {}
            }
          }
        }
        _dlog('MATCH_CANCEL processed: $cancelStr');
      }
    } catch (e) {
      debugPrint('[MeshEvt] MATCH_CANCEL handler error: $e');
    }
  }

  /// 處理 PHYSICAL_HANDSHAKE：物理交割完成
  Future<void> _handlePhysicalHandshakeEvent(
    WirePayload decoded,
    List<int> payload,
    dynamic db,
  ) async {
    try {
      final handshake = pb.PhysicalHandshakeData.fromBuffer(payload);
      _dlog('HANDSHAKE received: resource=${handshake.resourceId.substring(0, 8)}..');

      // 標記物資為 CONSUMED
      await db.update(
        'Materials_State',
        {'status': 'CONSUMED'},
        where: 'resource_id = ?',
        whereArgs: [handshake.resourceId],
      );

      // 標記需求為 CONSUMED
      await db.update(
        'Requests_State',
        {'status': 'CONSUMED'},
        where: "request_id = ?",
        whereArgs: [handshake.requestId],
      );

      // 完成 Match_Session
      final sessionId = '${handshake.resourceId}_${handshake.requestId}';
      await db.update(
        'Match_Sessions',
        {
          'status': 'COMPLETED',
          'completed_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      _dlog('HANDSHAKE → supply CONSUMED, session COMPLETED');
    } catch (e) {
      debugPrint('[MeshEvt] HANDSHAKE handler error: $e');
    }
  }

  /// 處理 LOCATION_UPDATE：更新 Match_Sessions 中的對方位置
  Future<void> _handleLocationUpdateEvent(
    WirePayload decoded,
    List<int> payload,
    dynamic db,
  ) async {
    try {
      final locUpdate = pb.LocationUpdateData.fromBuffer(payload);
      if (locUpdate.sessionId.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final senderPubKey = decoded.senderPubKey != null
          ? Uint8List.fromList(decoded.senderPubKey!)
          : null;
      if (senderPubKey == null) return;

      // 查 session 判斷 sender 是 provider 還是 requester
      final session = await db.query('Match_Sessions',
          where: "session_id = ? AND status = 'ACTIVE'",
          whereArgs: [locUpdate.sessionId],
          limit: 1);
      if (session.isEmpty) return;

      final providerKey = session.first['provider_pub_key'] as Uint8List?;
      if (providerKey != null && _bytesEqual(providerKey, senderPubKey)) {
        await db.update('Match_Sessions', {
          'provider_lat': locUpdate.lat,
          'provider_lng': locUpdate.lng,
          'updated_at': now,
        }, where: 'session_id = ?', whereArgs: [locUpdate.sessionId]);
      } else {
        await db.update('Match_Sessions', {
          'requester_lat': locUpdate.lat,
          'requester_lng': locUpdate.lng,
          'updated_at': now,
        }, where: 'session_id = ?', whereArgs: [locUpdate.sessionId]);
      }

      _dlog('LOC_UPDATE session=${locUpdate.sessionId.substring(0, 8)}.. lat=${locUpdate.lat.toStringAsFixed(5)}');
    } catch (e) {
      debugPrint('[MeshEvt] LOCATION_UPDATE handler error: $e');
    }
  }

  // ── Pending Match Actions（供上層輪詢）──────────────────────────
  final List<PendingMatchAction> _pendingConfirms = [];

  /// 取出並清空 pending match actions（供 EventManager 輪詢使用）
  List<PendingMatchAction> drainPendingMatchActions() {
    final actions = List<PendingMatchAction>.from(_pendingConfirms);
    _pendingConfirms.clear();
    return actions;
  }

  /// 輔助：比較兩組 bytes 是否相等
  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 輔助：取得自己的公鑰 bytes
  Future<List<int>> _getMyPubKeyBytes() async {
    try {
      final identity = (await _getIdentityManager());
      return await identity.getPublicKeyBytes();
    } catch (_) {
      return [];
    }
  }

  dynamic _identityManagerCached;
  Future<dynamic> _getIdentityManager() async {
    _identityManagerCached ??= (await _loadIdentityManager());
    return _identityManagerCached;
  }

  Future<dynamic> _loadIdentityManager() async {
    // 動態取得 IdentityManager 以避免循環依賴
    return IdentityManager();
  }

  // ── Wire Payload 編解碼 ────────────────────────────────────────

  /// 編碼 wire payload：使用 Protobuf MeshEvent 封裝
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
      ..urgency =
          pb.UrgencyLevel.valueOf(urgency) ?? pb.UrgencyLevel.INFO
      ..type = pb.EventType.valueOf(eventType) ??
          pb.EventType.RESOURCE_REGISTER
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

  /// 解碼 wire payload：嘗試 Protobuf MeshEvent，失敗則 fallback 到舊格式
  static WirePayload? decodeWirePayload(List<int> data) {
    // 先嘗試 Protobuf 解碼
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

    // Fallback: 舊版格式 eventId(36) + '|' + payload
    try {
      final pipeIndex = data.indexOf(0x7C); // '|' = 0x7C
      if (pipeIndex < 1) return null;
      final eventId = utf8.decode(data.sublist(0, pipeIndex));
      final payload = data.sublist(pipeIndex + 1);
      return WirePayload(eventId, payload);
    } catch (_) {
      return null;
    }
  }

  // ── Bloom Filter 工具（Bit-Vector）──────────────────────────────

  /// Bloom filter 參數：2048 bytes (16384 bits), 7 hash functions
  static const int kBloomSizeBytes = 2048;
  static const int kBloomHashCount = 7;
  static const List<int> kBloomMagic = [0xFF, 0xBF, 0x02, 0x00];

  /// 檢測 bytes 是否帶有 bit-vector bloom magic header
  static bool _hasBloomMagic(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0xFF && bytes[1] == 0xBF &&
           bytes[2] == 0x02 && bytes[3] == 0x00;
  }

  /// 簡易 MurmurHash3（32-bit）— 與 Kotlin 端完全一致
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

  /// 從事件 ID 集合建構 bit-vector Bloom Filter（含 magic header）
  static Uint8List buildBitVectorBloom(Set<String> eventIds) {
    final bits = Uint8List(kBloomSizeBytes + 4); // +4 for magic header
    bits[0] = 0xFF; bits[1] = 0xBF; bits[2] = 0x02; bits[3] = 0x00;
    for (final id in eventIds) {
      for (int i = 0; i < kBloomHashCount; i++) {
        final hash = _murmurHash(id, seed: i) % (kBloomSizeBytes * 8);
        bits[4 + (hash >> 3)] |= (1 << (hash & 7));
      }
    }
    return bits;
  }

  /// 檢查 bloom filter 是否 **可能** 包含指定 event ID
  static bool bloomMayContain(List<int> bloom, String eventId) {
    final offset = _hasBloomMagic(bloom) ? 4 : 0;
    final size = bloom.length - offset;
    if (size <= 0) return false;
    for (int i = 0; i < kBloomHashCount; i++) {
      final hash = _murmurHash(eventId, seed: i) % (size * 8);
      if ((bloom[offset + (hash >> 3)] & (1 << (hash & 7))) == 0) return false;
    }
    return true;
  }

  /// 將 Bloom Filter bytes 解析為事件 ID 集合
  /// 向下相容：如果帶 magic header 則為 bit-vector 格式（回傳空集合，
  /// 呼叫端應改用 bloomMayContain 逐一比對）；否則 fallback 到舊版文字格式。
  static Set<String> parseBloomFilter(List<int> bytes) {
    final result = <String>{};
    if (bytes.isEmpty) return result;
    // 新格式 bit-vector：不再能還原為 ID 集合，回傳空集合
    if (_hasBloomMagic(bytes)) return result;
    // 舊格式：換行分隔的 event ID 列表
    try {
      final str = utf8.decode(bytes);
      for (final id in str.split('\n')) {
        final trimmed = id.trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
      }
    } catch (_) {}
    return result;
  }

  /// 建構本機 Bloom Filter（bit-vector 格式）
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

  /// 取得本機事件 ID 集合（供 IBLT 同步使用）
  /// [excludeChat] 為 true 時排除聊天訊息事件
  Future<Set<String>> getLocalEventIds({bool excludeChat = true}) async {
    final db = await DatabaseHelper().database;
    String where = '';
    if (excludeChat) where = 'WHERE event_type != ${EventType.chatMessage}';
    final rows = await db.rawQuery('SELECT event_id FROM Event_Logs $where');
    return rows.map((r) => r['event_id'] as String).toSet();
  }

  /// 根據 CRC32 keyHash 集合查詢對應事件的完整資料（供 IBLT Fast Path 使用）
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

    // 過濾出 keyHash 匹配的事件
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

  /// CRC32 — 與 IBLT._crc32 一致
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
