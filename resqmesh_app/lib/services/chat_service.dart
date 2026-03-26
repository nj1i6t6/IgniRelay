import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../crdt/hlc.dart';
import '../crypto/identity_manager.dart';
import '../crypto/signer.dart';
import '../db/database_helper.dart';
import '../geo/village_geofence.dart';
import '../mesh/event_manager.dart';
import '../mesh/triage_queue.dart';
import '../services/location_service.dart';

/// Chat service handling room management, message CRUD, and rate limiting.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  // ── Rate Limiting ──
  final Map<String, int> _lastSendTime = {}; // roomId → epoch ms
  static const int defaultRateLimitSeconds = 180;

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
      final signature = await Signer.signPayload(payload);

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

      // Enqueue for mesh broadcast
      EventManager().queue.enqueue(
        MeshTask(eventId, 0, payload, eventType: EventType.chatMessage),
      );

      _lastSendTime[roomId] = DateTime.now().millisecondsSinceEpoch;
      return true;
    } catch (e) {
      debugPrint('[ChatService] Send failed: $e');
      return false;
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
    await db
        .delete('Chat_Messages', where: 'room_id = ?', whereArgs: [roomId]);
  }

  /// Auto-join village room based on GPS
  Future<String?> autoJoinVillageRoom() async {
    try {
      final loc = LocationService().currentLocation;
      if (loc == null) return null;

      final villages =
          await VillageGeofence.query(loc.latitude, loc.longitude);
      if (villages.isEmpty) return null;

      final village = villages.first;
      final villageCode = village.villcode;
      final villageName = village.fullName;

      await joinRoom(
        roomId: villageCode,
        roomName: '$villageName 聊天室',
        roomType: 'village',
        rateLimitSeconds: 180,
      );
      return villageCode;
    } catch (e) {
      debugPrint('[ChatService] Auto-join village failed: $e');
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
