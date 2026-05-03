import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:ignirelay_app/app/geo/admin_name_resolver.dart';
import 'package:ignirelay_app/app/geo/village_geofence.dart';
import 'package:ignirelay_app/app/services/room_display_name_resolver.dart';

void main() {
  late RoomDisplayNameResolver resolver;
  late sql.Database db;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    AdminNameResolver().debugSetData(
      counties: {
        '65000': (zhHant: '新北市', en: 'New Taipei City'),
        '64000': (zhHant: '高雄市', en: 'Kaohsiung City'),
      },
      towns: {
        '65000050': (zhHant: '新莊區', en: 'Xinzhuang District'),
        '64000060': (zhHant: '新興區', en: 'Xinxing District'),
      },
    );

    db = sql.sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE villages (
        villcode TEXT PRIMARY KEY,
        countyname TEXT, townname TEXT, villname TEXT, villeng TEXT,
        countycode TEXT, towncode TEXT,
        bbox_minx REAL, bbox_miny REAL, bbox_maxx REAL, bbox_maxy REAL,
        rings_json TEXT
      )
    ''');
    db.execute(
      '''INSERT INTO villages (villcode, towncode, countyname, townname, villname, villeng, countycode)
         VALUES ('65000050015', '65000050', '新北市', '新莊區', '西盛里', 'Xisheng Vil.', '65000')''',
    );
    VillageGeofence.debugSetDb(db);
  });

  setUp(() {
    resolver = RoomDisplayNameResolver();
  });

  tearDownAll(() {
    VillageGeofence.debugSetDb(null);
    db.dispose();
  });

  group('nation', () {
    test('zh returns 全國公告', () async {
      final name = await resolver.resolve(
        roomId: 'TW_NATION', roomType: 'nation',
        fallbackRoomName: '全國公告', locale: const Locale('zh'),
      );
      expect(name, '全國公告');
    });

    test('en returns National Announcements', () async {
      final name = await resolver.resolve(
        roomId: 'TW_NATION', roomType: 'nation',
        fallbackRoomName: '全國公告', locale: const Locale('en'),
      );
      expect(name, 'National Announcements');
    });
  });

  group('county', () {
    test('zh returns county name + 公告', () async {
      final name = await resolver.resolve(
        roomId: 'TW_65000', roomType: 'county',
        fallbackRoomName: '新北市 公告', locale: const Locale('zh'),
      );
      expect(name, '新北市 公告');
    });

    test('en returns county name + Announcements', () async {
      final name = await resolver.resolve(
        roomId: 'TW_65000', roomType: 'county',
        fallbackRoomName: '新北市 公告', locale: const Locale('en'),
      );
      expect(name, 'New Taipei City Announcements');
    });

    test('unknown code zh returns generic 縣市公告 (not DB fallback)', () async {
      final name = await resolver.resolve(
        roomId: 'TW_99999', roomType: 'county',
        fallbackRoomName: '舊的中文名', locale: const Locale('zh'),
      );
      expect(name, '縣市公告');
    });

    test('unknown code en returns generic County Announcements (not DB fallback)', () async {
      final name = await resolver.resolve(
        roomId: 'TW_99999', roomType: 'county',
        fallbackRoomName: '舊的中文名', locale: const Locale('en'),
      );
      expect(name, 'County Announcements');
    });
  });

  group('township', () {
    test('zh returns county+town+公告', () async {
      final name = await resolver.resolve(
        roomId: 'TW_65000050', roomType: 'township',
        fallbackRoomName: '新北市新莊區 公告', locale: const Locale('zh'),
      );
      expect(name, '新北市新莊區 公告');
    });

    test('en returns county+town+Announcements', () async {
      final name = await resolver.resolve(
        roomId: 'TW_65000050', roomType: 'township',
        fallbackRoomName: '新北市新莊區 公告', locale: const Locale('en'),
      );
      expect(name, 'New Taipei City Xinzhuang District Announcements');
    });

    test('unknown code zh returns generic 鄉鎮區公告 (not DB fallback)', () async {
      final name = await resolver.resolve(
        roomId: 'TW_99999000', roomType: 'township',
        fallbackRoomName: '舊的中文名', locale: const Locale('zh'),
      );
      expect(name, '鄉鎮區公告');
    });

    test('unknown code en returns generic Township Announcements (not DB fallback)', () async {
      final name = await resolver.resolve(
        roomId: 'TW_99999000', roomType: 'township',
        fallbackRoomName: '舊的中文名', locale: const Locale('en'),
      );
      expect(name, 'Township Announcements');
    });
  });

  group('village', () {
    test('zh returns county+town+village+聊天室', () async {
      final name = await resolver.resolve(
        roomId: '65000050015', roomType: 'village',
        fallbackRoomName: '新北市新莊區西盛里 聊天室', locale: const Locale('zh'),
      );
      expect(name, '新北市新莊區西盛里 聊天室');
    });

    test('en returns county+town+village+Chat', () async {
      final name = await resolver.resolve(
        roomId: '65000050015', roomType: 'village',
        fallbackRoomName: '新北市新莊區西盛里 聊天室', locale: const Locale('en'),
      );
      expect(name, 'New Taipei City Xinzhuang District Xisheng Chat');
    });

    test('unknown villcode zh returns generic 村里聊天室 (not DB fallback)', () async {
      final name = await resolver.resolve(
        roomId: '00000000000', roomType: 'village',
        fallbackRoomName: '舊的中文名', locale: const Locale('zh'),
      );
      expect(name, '村里聊天室');
    });

    test('unknown villcode en returns generic Village Chat (not DB fallback)', () async {
      final name = await resolver.resolve(
        roomId: '00000000000', roomType: 'village',
        fallbackRoomName: '舊的中文名', locale: const Locale('en'),
      );
      expect(name, 'Village Chat');
    });
  });

  group('custom', () {
    test('zh returns fallbackRoomName', () async {
      final name = await resolver.resolve(
        roomId: 'custom-123', roomType: 'custom',
        fallbackRoomName: '我的頻道', locale: const Locale('zh'),
      );
      expect(name, '我的頻道');
    });

    test('en returns fallbackRoomName', () async {
      final name = await resolver.resolve(
        roomId: 'custom-123', roomType: 'custom',
        fallbackRoomName: 'My Channel', locale: const Locale('en'),
      );
      expect(name, 'My Channel');
    });
  });
}
