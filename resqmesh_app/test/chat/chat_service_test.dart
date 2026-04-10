// chat_service_test.dart
//
// 測試聊天服務：速率限制、訊息 CRUD、房間管理、自動加入邏輯、未讀標記
//
// 使用 sqflite_common_ffi (in-memory SQLite)

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ignirelay_app/services/chat_service.dart';
import 'package:ignirelay_app/db/database_helper.dart';
import 'package:ignirelay_app/crypto/identity_manager.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await IdentityManager().initialize();
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
      final found =
          rooms.where((r) => r['room_id'] == 'test-join-1').toList();
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
      final found =
          rooms.where((r) => r['room_id'] == 'test-leave-1').toList();
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
      final found =
          rooms.where((r) => r['room_id'] == 'test-admin-1').toList();
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
      expect(rooms.where((r) => r['room_id'] == 'old-village').length, equals(0));
      expect(rooms.where((r) => r['room_id'] == 'TW_old-county').length, equals(0));
      // 新的應存在
      expect(rooms.where((r) => r['room_type'] == 'village').length, greaterThan(0));
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
