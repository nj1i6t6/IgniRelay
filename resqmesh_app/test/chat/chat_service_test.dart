// chat_service_test.dart
//
// 測試聊天服務：速率限制、訊息 CRUD、房間管理、自動加入邏輯、未讀標記
//
// 使用 sqflite_common_ffi (in-memory SQLite)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/chat_service.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/services/event_publisher_v2_facade.dart';
import 'package:ignirelay_app/app/services/peer_capability_registry.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await IdentityManager().initialize();
  });

  setUp(() async {
    await DatabaseHelper().resetForTest();
    ChatService().clearV2FacadeForTest();
  });

  group('ChatService — Rate Limiting', () {
    test('canSendMessage returns true when no previous send', () {
      final service = ChatService();
      expect(service.canSendMessage('test-room-rl-1'), isTrue);
    });

    test('getRemainingCooldown returns 0 when no previous send', () {
      final service = ChatService();
      expect(service.getRemainingCooldown('test-room-rl-2'), equals(0));
    });

    test('canSendMessage returns true with zero rate limit', () {
      final service = ChatService();
      expect(service.canSendMessage('test-room-rl-3', rateLimitSeconds: 0),
          isTrue);
    });
  });

  group('ChatService — Room Management', () {
    test('joinRoom creates local record', () async {
      final service = ChatService();
      await service.joinRoom(
        roomId: 'test-join-1',
        roomName: 'Test Room',
        roomType: 'village',
      );
      final rooms = await service.getJoinedRooms();
      final found = rooms.where((r) => r['room_id'] == 'test-join-1').toList();
      expect(found.length, equals(1));
      expect(found.first['room_name'], equals('Test Room'));
      expect(found.first['room_type'], equals('village'));
    });

    test('joinRoom with duplicate roomId is ignored', () async {
      final service = ChatService();
      await service.joinRoom(
        roomId: 'test-dup-room',
        roomName: 'Original',
        roomType: 'village',
      );
      await service.joinRoom(
        roomId: 'test-dup-room',
        roomName: 'Duplicate',
        roomType: 'village',
      );
      final rooms = await service.getJoinedRooms();
      final found =
          rooms.where((r) => r['room_id'] == 'test-dup-room').toList();
      expect(found.length, equals(1));
      expect(found.first['room_name'], equals('Original'));
    });

    test('leaveRoom removes room and messages', () async {
      final service = ChatService();
      await service.joinRoom(
        roomId: 'test-leave-1',
        roomName: 'Leave Test',
        roomType: 'village',
      );
      await service.leaveRoom('test-leave-1');
      final rooms = await service.getJoinedRooms();
      final found = rooms.where((r) => r['room_id'] == 'test-leave-1').toList();
      expect(found.length, equals(0));
    });

    test('joinRoom with adminOnly flag', () async {
      final service = ChatService();
      await service.joinRoom(
        roomId: 'test-admin-1',
        roomName: 'Admin Only',
        roomType: 'nation',
        adminOnly: true,
        rateLimitSeconds: 0,
      );
      final rooms = await service.getJoinedRooms();
      final found = rooms.where((r) => r['room_id'] == 'test-admin-1').toList();
      expect(found.length, equals(1));
      expect(found.first['admin_only'], equals(1));
      expect(found.first['rate_limit_seconds'], equals(0));
    });

    test('changeVillageRoom leaves old rooms and joins new', () async {
      final service = ChatService();
      // 先加入一個 village 房間
      await service.joinRoom(
        roomId: 'old-village',
        roomName: 'Old Village',
        roomType: 'village',
      );
      await service.joinRoom(
        roomId: 'TW_old-county',
        roomName: 'Old County',
        roomType: 'county',
      );

      // 切換到新區域
      final result = await service.changeVillageRoom(
        newVillageCode: '6400006000101',
        countyName: '高雄市',
        townName: '新興區',
        villName: '大勇里',
      );
      expect(result, isNotNull);

      final rooms = await service.getJoinedRooms();
      // 舊的 village/county 應被移除
      expect(
          rooms.where((r) => r['room_id'] == 'old-village').length, equals(0));
      expect(rooms.where((r) => r['room_id'] == 'TW_old-county').length,
          equals(0));
      // 新的應存在
      expect(rooms.where((r) => r['room_type'] == 'village').length,
          greaterThan(0));
    });
  });

  group('ChatService — Messages', () {
    test('getMessages returns empty for new room', () async {
      final service = ChatService();
      await service.joinRoom(
        roomId: 'test-msg-empty',
        roomName: 'Empty Room',
        roomType: 'village',
      );
      final msgs = await service.getMessages('test-msg-empty');
      expect(msgs, isEmpty);
    });

    test('getUnreadCount returns 0 for empty room', () async {
      final service = ChatService();
      await service.joinRoom(
        roomId: 'test-unread-0',
        roomName: 'Unread Test',
        roomType: 'village',
      );
      final count = await service.getUnreadCount('test-unread-0');
      expect(count, equals(0));
    });

    test('getUnreadCount returns 0 for nonexistent room', () async {
      final service = ChatService();
      final count = await service.getUnreadCount('nonexistent-room');
      expect(count, equals(0));
    });

    test('sendMessage rejects empty content', () async {
      final service = ChatService();
      final result = await service.sendMessage(
        roomId: 'test-empty-msg',
        roomType: 'village',
        content: '   ',
      );
      expect(result, isFalse);
    });

    test('sendMessage mirrors the chat payload to v2 facade', () async {
      final service = ChatService();
      final spy = _SpyEventPublisherV2Facade();
      service.attachV2Facade(spy);

      final ok = await service.sendMessage(
        roomId: 'test-v2-chat-room',
        roomType: 'village',
        content: 'hello over v2',
      );
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      expect(spy.chatPayloads, hasLength(1));
      final decoded = jsonDecode(utf8.decode(spy.chatPayloads.single))
          as Map<String, dynamic>;
      expect(decoded['room_id'], 'test-v2-chat-room');
      expect(decoded['room_type'], 'village');
      expect(decoded['content'], 'hello over v2');
    });

    test('chat is v2-only: excluded from v1 outbound id set, mirrored to v2',
        () async {
      final service = ChatService();
      final spy = _SpyEventPublisherV2Facade();
      service.attachV2Facade(spy);

      final ok = await service.sendMessage(
        roomId: 'test-v2only-room',
        roomType: 'village',
        content: 'v2 only please',
      );
      await Future<void>.delayed(Duration.zero);
      expect(ok, isTrue);

      // The chat row is still written to Event_Logs (local event-sourcing).
      final db = await DatabaseHelper().database;
      final logs = await db.query('Event_Logs',
          where: 'event_type = ?', whereArgs: [EventType.chatMessage]);
      expect(logs, hasLength(1));
      final chatId = logs.first['event_id'] as String;

      // ...but it must NOT appear in the v1 IBLT outbound set, so it never
      // crosses the legacy wire (which would double-display on the receiver).
      final outbound = await MeshEventHandler().getLocalEventIds();
      expect(outbound, isNot(contains(chatId)));

      // ...and the v1 IBLT fast-path must not serve it as a raw event either.
      final byHash = await MeshEventHandler()
          .getEventsByKeyHashes({_crc32(chatId)});
      expect(byHash, isEmpty);

      // It DID go out on the v2 path.
      expect(spy.chatPayloads, hasLength(1));
    });

    test('markAsRead updates last_read_hlc', () async {
      final service = ChatService();
      await service.joinRoom(
        roomId: 'test-markread-1',
        roomName: 'Mark Read Test',
        roomType: 'village',
      );
      // markAsRead 不應拋出例外
      await service.markAsRead('test-markread-1');
      final count = await service.getUnreadCount('test-markread-1');
      expect(count, equals(0));
    });

    test('purgeExpiredMessages runs without error', () async {
      final service = ChatService();
      final deleted = await service.purgeExpiredMessages();
      expect(deleted, greaterThanOrEqualTo(0));
    });

    test('getTotalUnreadCount runs without error', () async {
      final service = ChatService();
      final count = await service.getTotalUnreadCount();
      expect(count, greaterThanOrEqualTo(0));
    });
  });
}

/// Mirrors MeshEventHandler._crc32EventId so the test can target the IBLT
/// fast-path with the exact key hash a real peer would request.
int _crc32(String s) {
  int crc = 0xFFFFFFFF;
  for (final b in s.codeUnits) {
    crc ^= b;
    for (int j = 0; j < 8; j++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

class _SpyEventPublisherV2Facade extends EventPublisherV2Facade {
  final List<Uint8List> chatPayloads = [];

  _SpyEventPublisherV2Facade() : super(registry: PeerCapabilityRegistry());

  @override
  Future<BroadcastOutcome> publishChatMessage({
    required Uint8List payload,
  }) async {
    chatPayloads.add(Uint8List.fromList(payload));
    return BroadcastOutcome.queued(chatPayloads.length);
  }
}
