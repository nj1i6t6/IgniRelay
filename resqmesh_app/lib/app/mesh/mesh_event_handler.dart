import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:ignirelay_app/app/crdt/hlc.dart';
import 'package:ignirelay_app/app/crypto/signer.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';

import 'package:ignirelay_app/app/mesh/mesh_router.dart';
import 'package:ignirelay_app/platform/mesh_transport.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';

// Re-export so UI 層可以只 import 本檔（app layer）即可取用 MeshDataReceived 型別，
// 不需要觸碰 platform/ 以符合 Stage 4b 分層規則。
export 'package:ignirelay_app/platform/mesh_transport.dart' show MeshDataReceived;

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
/// NativeBLE Transport 的事件處理邏輯。
class MeshEventHandler {
  static final MeshEventHandler _instance = MeshEventHandler._internal();
  factory MeshEventHandler() => _instance;
  MeshEventHandler._internal();

  final NegotiationManager _negotiationManager = NegotiationManager();

  /// v0.3 Stage 0c — `V2InboundProjector` 寫進 `Event_Logs` 的投影列一律以此
  /// 為 event_id 前綴。這些列**只是 read-model**（給 EventStream/UI 看），它們
  /// 沒有合法 v1 簽章，**絕不可進入 v1 wire 送出/同步路徑**（直送 outbox、
  /// bloom 廣告、IBLT 對帳），否則對端會 no-sig/sig-fail 拒收、污染 log、浪費
  /// BLE 流量、並讓 0D 判讀困難。所有 v1 對外查詢都以 `NOT LIKE '$v2ProjectionIdPrefix%'` 排除。
  static const String v2ProjectionIdPrefix = 'v2-';

  // 已看過的 event_id（去重，上限 10000 條 LRU）
  static const int _maxSeenEvents = 10000;
  final LinkedHashSet<String> _seenEvents = LinkedHashSet<String>();

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
  void markSeen(String eventId) {
    _seenEvents.add(eventId);
    while (_seenEvents.length > _maxSeenEvents) {
      _seenEvents.remove(_seenEvents.first);
    }
  }

  /// 已見過事件數量
  int get seenEventsCount => _seenEvents.length;

  /// 處理從任何 transport 接收到的 raw bytes
  Future<void> handleIncomingData(
      Uint8List data, String sourceNodeId) async {
    try {
      // 拒絕超大封包（>64KB），防止惡意節點 DoS
      if (data.length > 65536) {
        debugPrint('[MeshEvt] Oversized payload (${data.length}B) from $sourceNodeId');
        return;
      }
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
        markSeen(evtId); // 補進記憶體快取
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
      final verified = await Signer.verifyEvent(
        eventId: evtId,
        eventType: decoded.eventType,
        payload: decoded.payload,
        signatureBytes: decoded.signature!,
        publicKeyBytes: decoded.senderPubKey!,
      );
      if (!verified) {
        _dlog('RECV REJECT(sig-fail) ${evtId.substring(0, 8)}..');
        return;
      }

      // ── Hop-limit（TTL）─────────────────────────────────────────
      // ttl<=0 代表已耗盡 hop budget：直接 drop，不落庫、不投影、不轉發。
      // 送出端（DB-sync / outbox / IBLT fast-path）也會過濾 ttl<=0，正常不會
      // 收到；此處為防呆，並避免「ttl 用盡後又被存活」。
      if (decoded.ttl <= 0) {
        _dlog('RECV TTL_EXPIRED ${evtId.substring(0, 8)}.. ttl=${decoded.ttl}');
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

      // 落庫 + 投影 + 發訊號（與 v2 收進來共用同一條 ingest）
      await ingestVerifiedEvent(
        eventId: evtId,
        eventType: decoded.eventType,
        urgency: decoded.urgency,
        payload: payload,
        senderPubKey: decoded.senderPubKey,
        hlcTimestamp: decoded.hlcTimestamp,
        hlcCounter: decoded.hlcCounter,
        ttl: decoded.ttl,
        lat: decoded.lat,
        lng: decoded.lng,
        originLat: decoded.originLat,
        originLng: decoded.originLng,
        signature: decoded.signature,
        sourceNodeId: sourceNodeId,
      );
    } catch (e) {
      debugPrint('[MeshEvt] Parse error: $e');
    }
  }

  /// 共用 ingest：把「已驗證、已解碼」的事件落庫、投影到業務表、emit UI 訊號。
  ///
  /// v1 收進來路徑 ([handleIncomingData]) 在 wire 解碼 + 簽章驗證 + 地理圍欄
  /// 路由判斷之後呼叫本方法；v2 收進來路徑 (`V2InboundProjector`) 在 envelope
  /// dispatcher 接受後，把 v2 payload 翻成 v1 格式再呼叫本方法。兩條路因此共用
  /// 同一個「事件 → Event_Logs → 投影 → EventStream」出口，避免 read-model 分裂。
  ///
  /// 呼叫端必須保證事件已通過簽章/信任驗證；本方法只負責去重、落庫、投影、發訊號。
  Future<void> ingestVerifiedEvent({
    required String eventId,
    required int eventType,
    required int urgency,
    required List<int> payload,
    List<int>? senderPubKey,
    int hlcTimestamp = 0,
    int hlcCounter = 0,
    int ttl = 10,
    double? lat,
    double? lng,
    double? originLat,
    double? originLng,
    List<int>? signature,
    String sourceNodeId = 'v2',
  }) async {
    if (_seenEvents.contains(eventId)) return;
    final db = await DatabaseHelper().database;
    final existingEvt = await db.query('Event_Logs',
        columns: ['event_id'],
        where: 'event_id = ?',
        whereArgs: [eventId],
        limit: 1);
    if (existingEvt.isNotEmpty) {
      markSeen(eventId);
      return;
    }

    // 合併 HLC（確保時間同步）
    if (hlcTimestamp > 0) {
      HLC.merge(HLC(hlcTimestamp, hlcCounter));
    } else {
      HLC.merge(HLC(DateTime.now().millisecondsSinceEpoch, 0));
    }

    final decoded = WirePayload(
      eventId,
      payload,
      urgency: urgency,
      eventType: eventType,
      hlcTimestamp: hlcTimestamp,
      hlcCounter: hlcCounter,
      ttl: ttl,
      lat: lat,
      lng: lng,
      originLat: originLat,
      originLng: originLng,
      signature: signature,
      senderPubKey: senderPubKey,
    );

    // 存入本地資料庫
    try {
      await db.insert('Event_Logs', {
        'event_id': eventId,
        'sender_pub_key': senderPubKey != null
            ? Uint8List.fromList(senderPubKey)
            : Uint8List.fromList(utf8.encode(sourceNodeId)),
        'identity_level': 0,
        'event_type': eventType,
        'urgency': urgency,
        'hlc_timestamp':
            hlcTimestamp > 0 ? hlcTimestamp : DateTime.now().millisecondsSinceEpoch,
        'hlc_counter': hlcCounter,
        // ttl-1（消耗一跳）。收件端已在 handleIncomingData drop 掉 ttl<=0，
        // 故此處 ttl 必 >0；保留 :0 floor 給 v2 投影路徑（maxHops 可能為 0），
        // 不再復活成 9。
        'ttl': ttl > 0 ? ttl - 1 : 0,
        'received_lat': lat,
        'received_lng': lng,
        'origin_lat': originLat,
        'origin_lng': originLng,
        'node_tier': 2,
        'chunk_index': 0,
        'total_chunks': 1,
        'payload': Uint8List.fromList(payload),
        'signature':
            signature != null ? Uint8List.fromList(signature) : Uint8List(0),
        'is_synced': 0,
      });
      // DB insert 成功後才加入去重快取
      markSeen(eventId);
    } catch (e) {
      // UNIQUE constraint 失敗代表已有此事件，忽略
      markSeen(eventId); // 既然 DB 有了，也加入快取
      debugPrint('[MeshEvt] DB insert skipped (duplicate): $eventId');
      return; // DB 已有此事件，不需要重複處理
    }

    // ── Event dispatch ─────────────────────────────────────────
    final senderPubKeyList = senderPubKey ?? <int>[];
    final payloadBytes = Uint8List.fromList(payload);

    switch (eventType) {
      // ── Infrastructure events → handle locally ──
      case EventType.resourceRegister:
        if (payload.isNotEmpty) {
          await _handleResourceRegisterEvent(decoded, payload, eventId, db);
        }
        break;
      case EventType.requestBroadcast:
        if (payload.isNotEmpty) {
          await _handleRequestBroadcastEvent(decoded, payload, eventId, db);
        }
        break;
      case EventType.physicalHandshake:
        // Slot 3 kept for backward compat
        if (payload.isNotEmpty) {
          await _handlePhysicalHandshakeEvent({'raw': payload});
        }
        break;
      case EventType.hazardMarker:
        if (payload.isNotEmpty) {
          await _handleHazardEvent(decoded, payload, sourceNodeId, db);
        }
        break;
      case EventType.quarantineVote:
        // existing quarantine vote handling (no-op in current codebase)
        break;
      case EventType.fireAlarmRf:
        // existing fire alarm RF handling (no-op in current codebase)
        break;
      case EventType.chatMessage:
        if (payload.isNotEmpty) {
          await _handleChatEvent(decoded, payload, sourceNodeId, db);
        }
        break;

      // ── Deprecated slots → silently ignore ──
      case EventType.matchInquiry:  // 10
      case EventType.matchAvailable: // 11
      case EventType.matchGone:      // 12
        break;

      // ── Negotiation events → delegate to Application Layer ──
      case EventType.matchIntent:       // 2 (matchOffer)
      case EventType.matchRequest:      // 15
      case EventType.matchConfirm:      // 8 (matchAccept)
      case EventType.matchReject:       // 9 (matchDecline)
      case EventType.matchCancel:       // 6
      case EventType.handshakeComplete: // 16
        await _negotiationManager.handleRemoteEvent(
          eventType, payloadBytes, senderPubKeyList);
        break;

      case EventType.locationUpdate: // 14 — negotiation-related
        await _negotiationManager.handleRemoteEvent(
          eventType, payloadBytes, senderPubKeyList);
        break;

      default:
        _dlog('RECV unknown eventType=$eventType');
        break;
    }

    receivedEventCount++;
    _eventStreamController.add(
      MeshDataReceived(sourceNodeId, payloadBytes),
    );
    debugPrint(
        '[MeshEvt] Stored event $eventId (${payload.length} bytes) from $sourceNodeId');
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

      String deliveryMode = rd.deliveryMode;
      if (deliveryMode.isEmpty) {
        // Fallback: description field might hold delivery mode
        deliveryMode = (rd.description == 'DELIVER' || rd.description == 'PICKUP' || rd.description == 'DROP_OFF')
            ? rd.description : 'PICKUP';
      }

      await db.insert('Materials_State', {
        'resource_id': rd.resourceId,
        'status': 'AVAILABLE',
        'hlc_timestamp': decoded.hlcTimestamp > 0
            ? decoded.hlcTimestamp
            : DateTime.now().millisecondsSinceEpoch,
        'hlc_counter': decoded.hlcCounter,
        'matched_request_id': null,
        'match_expires_at': null,
        'total_qty': rd.quantity,
        'delivery_mode': deliveryMode,
        'payload': Uint8List.fromList(payload),
      });
      _dlog('SUPPLY_SYNC ${rd.resourceId.substring(0, 8)}.. to Materials_State');
      // 亂序保險:若先前有 bystander 寫過 COMPLETED Match_Negotiations
      // (handshakeComplete 比 supply 先到),這裡 reconcile 讓 Materials_State
      // 立刻轉 CONSUMED,避免社區頁仍顯示已交接物資。
      await _negotiationManager.reconcileMaterialStatus(rd.resourceId);
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

      // Extract new fields (with fallback to description parsing for old events)
      String mobilityMode = rd.mobilityMode;
      String note = rd.note;
      if (mobilityMode.isEmpty && rd.description.isNotEmpty) {
        final parts = rd.description.split('|');
        mobilityMode = parts.isNotEmpty ? parts[0] : 'CAN_GO';
        note = parts.length > 1 ? parts.sublist(1).join('|') : '';
      }
      if (mobilityMode.isEmpty) mobilityMode = 'CAN_GO';

      await db.insert('Requests_State', {
        'request_id': rd.requestId,
        'event_id': eventId,
        'sender_pub_key': decoded.senderPubKey != null
            ? Uint8List.fromList(decoded.senderPubKey!)
            : Uint8List(0),
        'status': 'OPEN',
        'hlc_timestamp': decoded.hlcTimestamp > 0
            ? decoded.hlcTimestamp
            : DateTime.now().millisecondsSinceEpoch,
        'hlc_counter': decoded.hlcCounter,
        'matched_resource_id': null,
        'match_expires_at': null,
        'quantity_needed': rd.quantityNeeded,
        'mobility_mode': mobilityMode,
        'note': note,
        'payload': Uint8List.fromList(payload),
      });
      _dlog('REQUEST_SYNC ${rd.requestId.substring(0, 8)}.. to Requests_State');
      // 亂序保險:同 Materials_State 對稱處理。
      await _negotiationManager.reconcileRequestStatus(rd.requestId);
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

  Future<void> _handlePhysicalHandshakeEvent(Map<String, dynamic> row) async {
    // Slot 3 preserved for backward compatibility
    // New handshake flow uses slot 16 (handshakeComplete) via NegotiationManager
    // Just log that we received it; don't process
    debugPrint('[MeshEventHandler] Received legacy physicalHandshake, ignoring');
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
          lat: meshEvent.hasReceivedLat() ? meshEvent.receivedLat : null,
          lng: meshEvent.hasReceivedLng() ? meshEvent.receivedLng : null,
          originLat: meshEvent.hasOriginLat() ? meshEvent.originLat : null,
          originLng: meshEvent.hasOriginLng() ? meshEvent.originLng : null,
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
      // 排除 v2 投影列：它們無 v1 簽章，不可進 v1 wire 廣告/同步。
      // 排除 CHAT_MESSAGE：聊天已遷移成 v2-only，不參與 v1 Bloom 對帳
      // （IBLT getLocalEventIds / getEventsByKeyHashes 也同樣排除）。
      where: 'event_id NOT LIKE ? AND event_type != ?',
      whereArgs: ['$v2ProjectionIdPrefix%', EventType.chatMessage],
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
    // 排除 v2 投影列（無 v1 簽章，不可進 IBLT 對帳/送出）。
    final clauses = <String>["event_id NOT LIKE '$v2ProjectionIdPrefix%'"];
    if (excludeChat) clauses.add('event_type != ${EventType.chatMessage}');
    final where = 'WHERE ${clauses.join(' AND ')}';
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
        'ttl',
      ],
      // 排除 v2 投影列（無 v1 簽章，不可被 IBLT fast-path 當原始事件送出）。
      // 排除 ttl<=0：已耗盡 hop budget 的事件不再被 fast-path 當原始事件送出。
      where: 'hlc_timestamp > ? AND ttl > 0 '
          'AND event_type != ${EventType.chatMessage} '
          "AND event_id NOT LIKE '$v2ProjectionIdPrefix%'",
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
