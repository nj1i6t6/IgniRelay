import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import '../crdt/hlc.dart';
import '../db/database_helper.dart';
import '../proto/mesh_protocol.pb.dart' as pb;
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
      _seenEvents.add(evtId);

      // 合併 HLC（確保時間同步）
      if (decoded.hlcTimestamp > 0) {
        HLC.merge(HLC(decoded.hlcTimestamp, decoded.hlcCounter));
      } else {
        HLC.merge(HLC(DateTime.now().millisecondsSinceEpoch, 0));
      }

      // 存入本地資料庫
      final db = await DatabaseHelper().database;
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
          'node_tier': 2,
          'chunk_index': 0,
          'total_chunks': 1,
          'payload': Uint8List.fromList(payload),
          'signature': decoded.signature != null
              ? Uint8List.fromList(decoded.signature!)
              : Uint8List(0),
          'is_synced': 0,
        });
      } catch (e) {
        // UNIQUE constraint 失敗代表已有此事件，忽略
        debugPrint('[MeshEvt] DB insert skipped (duplicate): $evtId');
      }

      // 如果是危險區域事件，寫入 Hazards_State
      if (decoded.eventType == EventType.hazardMarker && payload.isNotEmpty) {
        await _handleHazardEvent(decoded, payload, sourceNodeId, db);
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
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
        debugPrint(
            '[MeshEvt] Hazard synced to Hazards_State: ${hazard.hazardId}');
      }
    } catch (e) {
      debugPrint('[MeshEvt] Hazard sync skipped: $e');
    }
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

  // ── Bloom Filter 工具 ──────────────────────────────────────────

  /// 將 Bloom Filter bytes 解析為事件 ID 集合
  static Set<String> parseBloomFilter(List<int> bytes) {
    final result = <String>{};
    if (bytes.isEmpty) return result;
    try {
      final str = utf8.decode(bytes);
      for (final id in str.split('\n')) {
        final trimmed = id.trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
      }
    } catch (_) {}
    return result;
  }

  /// 建構本機 Bloom Filter（最近事件 ID 列表）
  static Future<Uint8List> buildLocalBloomFilter({int limit = 50}) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'Event_Logs',
      columns: ['event_id'],
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );
    final ids = rows.map((r) => r['event_id'] as String).join('\n');
    return Uint8List.fromList(utf8.encode(ids));
  }

  void dispose() {
    _eventStreamController.close();
  }
}
