import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:ignirelay_app/app/crdt/hlc.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/crypto/signer.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/geo/village_geofence.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/services/event_publisher_v2_facade.dart';
import 'package:ignirelay_app/app/services/location_service.dart';

/// Chat service handling room management, message CRUD, and rate limiting.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();
  EventPublisherV2Facade? _v2Facade;

  // ── Rate Limiting ──
  final Map<String, int> _lastSendTime = {}; // roomId → epoch ms
  static const int defaultRateLimitSeconds = 180;

  /// Attach the v0.3 envelope publisher. Chat UI intentionally keeps using
  /// ChatService as its single entry point; the service mirrors each send to
  /// the v2 mesh path so chat can traverse the chunked BLE bridge.
  void attachV2Facade(EventPublisherV2Facade facade) {
    _v2Facade = facade;
  }

  @visibleForTesting
  void clearV2FacadeForTest() {
    _v2Facade = null;
  }

  /// Check if user can send message in this room
  bool canSendMessage(String roomId, {int? rateLimitSeconds}) {
    final limit = rateLimitSeconds ?? defaultRateLimitSeconds;
    final lastTime = _lastSendTime[roomId];
    if (lastTime == null) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastTime;
    return elapsed >= limit * 1000;
  }

  /// Get remaining cooldown seconds
  int getRemainingCooldown(String roomId, {int? rateLimitSeconds}) {
    final limit = rateLimitSeconds ?? defaultRateLimitSeconds;
    final lastTime = _lastSendTime[roomId];
    if (lastTime == null) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastTime;
    final remaining = (limit * 1000 - elapsed) ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }

  /// Send a chat message
  Future<bool> sendMessage({
    required String roomId,
    required String roomType,
    required String content,
    String? replyTo,
  }) async {
    if (!canSendMessage(roomId)) return false;
    if (content.trim().isEmpty) return false;
    if (content.trim().length > 1000) return false; // 防止超大 payload 經 mesh 擴散

    try {
      final trimmed = content.trim();
      final eventId = _uuid.v4();
      final hlc = HLC.now();
      final identity = IdentityManager();
      final pubKeyBytes = await identity.getPublicKeyBytes();

      // Build payload: JSON with room info + content
      final payloadMap = {
        'room_id': roomId,
        'room_type': roomType,
        'content': trimmed,
        if (replyTo != null) 'reply_to': replyTo,
      };
      final payload = Uint8List.fromList(utf8.encode(jsonEncode(payloadMap)));
      final signature = await Signer.signEvent(
        eventId: eventId,
        eventType: EventType.chatMessage,
        payload: payload,
      );

      final loc = LocationService().currentLocation;

      final db = await _dbHelper.database;

      // Insert into Event_Logs for mesh broadcast
      await db.insert('Event_Logs', {
        'event_id': eventId,
        'sender_pub_key': Uint8List.fromList(pubKeyBytes),
        'identity_level': identity.getIdentityLevel(),
        'event_type': EventType.chatMessage,
        'urgency': 0, // INFO level
        'hlc_timestamp': hlc.timestamp,
        'hlc_counter': hlc.counter,
        'ttl': 5,
        'received_lat': loc?.latitude,
        'received_lng': loc?.longitude,
        'origin_lat': loc?.latitude,
        'origin_lng': loc?.longitude,
        'node_tier': 1,
        'chunk_index': 0,
        'total_chunks': 1,
        'payload': payload,
        'signature': Uint8List.fromList(signature),
        'is_synced': 0,
      });

      // Insert into Chat_Messages for local display
      await db.insert('Chat_Messages', {
        'event_id': eventId,
        'room_id': roomId,
        'sender_pub_key': Uint8List.fromList(pubKeyBytes),
        'content': trimmed,
        'reply_to': replyTo,
        'hlc_timestamp': hlc.timestamp,
      });

      // CHAT_MESSAGE is v2-only: it travels exclusively over the v0.3 chunked
      // BLE bridge via the v2 facade. We deliberately do NOT enqueue a v1
      // MeshTask here, and the v1 outbound/Bloom/IBLT/DB-sync queries exclude
      // EventType.chatMessage, so chat never crosses on the legacy wire (which
      // would otherwise double-display on the receiver). The Event_Logs row is
      // still written above for local event-sourcing + EventStream emission.
      final v2 = _v2Facade;
      if (v2 != null) {
        unawaited(_publishV2Chat(v2, payload));
      }

      _lastSendTime[roomId] = DateTime.now().millisecondsSinceEpoch;

      // Bug 12 Fix: 自己發的訊息立即標記已讀，避免自己產生未讀紅點
      await markAsRead(roomId);

      return true;
    } catch (e) {
      debugPrint('[ChatService] Send failed: $e');
      return false;
    }
  }

  Future<void> _publishV2Chat(
      EventPublisherV2Facade facade, Uint8List payload) async {
    try {
      await facade.publishChatMessage(payload: payload);
    } catch (e, st) {
      debugPrint('[ChatService] v2 publishChatMessage failed: $e\n$st');
    }
  }

  // ── Room Management ──

  /// Get all joined chat rooms
  Future<List<Map<String, dynamic>>> getJoinedRooms() async {
    final db = await _dbHelper.database;
    return db.query('Chat_Rooms', orderBy: 'joined_at DESC');
  }

  /// Get messages for a room
  Future<List<Map<String, dynamic>>> getMessages(String roomId,
      {int limit = 100, int? beforeHlc}) async {
    final db = await _dbHelper.database;
    String where = 'room_id = ?';
    List<dynamic> whereArgs = [roomId];
    if (beforeHlc != null) {
      where += ' AND hlc_timestamp < ?';
      whereArgs.add(beforeHlc);
    }
    return db.query('Chat_Messages',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'hlc_timestamp DESC',
        limit: limit);
  }

  /// Get unread count for a room
  Future<int> getUnreadCount(String roomId) async {
    final db = await _dbHelper.database;
    final room =
        await db.query('Chat_Rooms', where: 'room_id = ?', whereArgs: [roomId]);
    if (room.isEmpty) return 0;
    final lastReadHlc = room.first['last_read_hlc'] as int? ?? 0;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM Chat_Messages WHERE room_id = ? AND hlc_timestamp > ?',
        [roomId, lastReadHlc]);
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Mark room as read
  Future<void> markAsRead(String roomId) async {
    final db = await _dbHelper.database;
    final latest = await db.query('Chat_Messages',
        columns: ['hlc_timestamp'],
        where: 'room_id = ?',
        whereArgs: [roomId],
        orderBy: 'hlc_timestamp DESC',
        limit: 1);
    if (latest.isNotEmpty) {
      await db.update(
          'Chat_Rooms', {'last_read_hlc': latest.first['hlc_timestamp']},
          where: 'room_id = ?', whereArgs: [roomId]);
    }
  }

  /// Join a room (create local record)
  Future<void> joinRoom({
    required String roomId,
    required String roomName,
    required String roomType,
    int rateLimitSeconds = 180,
    bool adminOnly = false,
    String? joinTokenHash,
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
        'Chat_Rooms',
        {
          'room_id': roomId,
          'room_name': roomName,
          'room_type': roomType,
          'rate_limit_seconds': rateLimitSeconds,
          'admin_only': adminOnly ? 1 : 0,
          'join_token_hash': joinTokenHash,
          'joined_at': DateTime.now().millisecondsSinceEpoch,
          'last_read_hlc': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Leave a room
  Future<void> leaveRoom(String roomId) async {
    final db = await _dbHelper.database;
    await db.delete('Chat_Rooms', where: 'room_id = ?', whereArgs: [roomId]);
    await db.delete('Chat_Messages', where: 'room_id = ?', whereArgs: [roomId]);
    // 清掉 rate-limit 紀錄，避免 Map 在頻繁進出聊天室時無限累積
    _lastSendTime.remove(roomId);
  }

  /// Auto-join all level rooms (nation/county/township/village) based on GPS
  Future<String?> autoJoinVillageRoom() async {
    try {
      final loc = LocationService().currentLocation;
      if (loc == null) return null;

      final villages = await VillageGeofence.query(loc.latitude, loc.longitude);
      if (villages.isEmpty) return null;

      final village = villages.first;
      final villageCode = village.villcode;

      // 先離開舊的地區聊天室，避免跨里/區重複顯示
      await _leaveLocationRooms();

      await _joinAllLevelRooms(
        villageCode: villageCode,
        countyName: village.countyName,
        townName: village.townName,
        villName: village.villName,
      );
      return villageCode;
    } catch (e) {
      debugPrint('[ChatService] Auto-join rooms failed: $e');
      return null;
    }
  }

  /// 加入全部 4 層聊天室（全國 / 縣市 / 鄉鎮區 / 里）
  Future<void> _joinAllLevelRooms({
    required String villageCode,
    required String countyName,
    required String townName,
    required String villName,
  }) async {
    // 全國公告頻道
    await joinRoom(
      roomId: 'TW_NATION',
      roomName: '全國公告',
      roomType: 'nation',
      rateLimitSeconds: 0,
      adminOnly: true,
    );

    // 縣市公告頻道（villcode 前 5 碼 = 縣市碼）
    if (villageCode.length >= 5) {
      final countyCode = villageCode.substring(0, 5);
      await joinRoom(
        roomId: 'TW_$countyCode',
        roomName: '$countyName 公告',
        roomType: 'county',
        rateLimitSeconds: 0,
        adminOnly: true,
      );
    }

    // 鄉鎮區公告頻道（villcode 前 8 碼 = 鄉鎮碼）
    if (villageCode.length >= 8) {
      final townCode = villageCode.substring(0, 8);
      await joinRoom(
        roomId: 'TW_$townCode',
        roomName: '$countyName$townName 公告',
        roomType: 'township',
        rateLimitSeconds: 0,
        adminOnly: true,
      );
    }

    // 里聊天室（一般用戶可發言）
    await joinRoom(
      roomId: villageCode,
      roomName: '$countyName$townName$villName 聊天室',
      roomType: 'village',
      rateLimitSeconds: 180,
    );
  }

  /// 離開所有地區聊天室（village / township / county），保留 nation 和自訂頻道
  Future<void> _leaveLocationRooms() async {
    final rooms = await getJoinedRooms();
    for (final room in rooms) {
      final type = room['room_type'] as String? ?? '';
      if (type == 'village' || type == 'township' || type == 'county') {
        await leaveRoom(room['room_id'] as String);
      }
    }
  }

  /// 手動變更所在里（離開舊里相關頻道，加入新里相關頻道）
  Future<String?> changeVillageRoom({
    required String newVillageCode,
    required String countyName,
    required String townName,
    required String villName,
  }) async {
    try {
      await _leaveLocationRooms();

      await _joinAllLevelRooms(
        villageCode: newVillageCode,
        countyName: countyName,
        townName: townName,
        villName: villName,
      );
      return newVillageCode;
    } catch (e) {
      debugPrint('[ChatService] Change village failed: $e');
      return null;
    }
  }

  /// Purge expired chat messages (48-hour TTL)
  Future<int> purgeExpiredMessages() async {
    final db = await _dbHelper.database;
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - (48 * 60 * 60 * 1000);
    return db.delete('Chat_Messages',
        where: 'hlc_timestamp < ?', whereArgs: [cutoff]);
  }

  /// Get the most recent message preview for a room (content + hlc ms).
  /// Returns null when the room has no messages.
  Future<({String content, int hlcTimestamp})?> getLastMessage(
      String roomId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'Chat_Messages',
      columns: ['content', 'hlc_timestamp'],
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'hlc_timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (
      content: (rows.first['content'] as String?) ?? '',
      hlcTimestamp: (rows.first['hlc_timestamp'] as int?) ?? 0,
    );
  }

  /// Get total unread count across all rooms
  Future<int> getTotalUnreadCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(cnt) as total FROM (
        SELECT COUNT(*) as cnt FROM Chat_Messages cm
        INNER JOIN Chat_Rooms cr ON cm.room_id = cr.room_id
        WHERE cm.hlc_timestamp > cr.last_read_hlc
        GROUP BY cm.room_id
      )
    ''');
    return (result.first['total'] as int?) ?? 0;
  }
}
