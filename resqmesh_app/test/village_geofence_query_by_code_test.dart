import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:ignirelay_app/app/geo/village_geofence.dart';

void main() {
  late sql.Database db;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
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
      "CREATE INDEX idx_villages_villcode ON villages(villcode)",
    );
    db.execute(
      '''INSERT INTO villages (villcode, towncode, countyname, townname, villname, villeng, countycode)
         VALUES ('65000050015', '65000050', '新北市', '新莊區', '西盛里', 'Xisheng Vil.', '65000')''',
    );
    db.execute(
      '''INSERT INTO villages (villcode, towncode, countyname, townname, villname, villeng, countycode)
         VALUES ('64000060001', '64000060', '高雄市', '新興區', '大勇里', 'Dayong Vil.', '64000')''',
    );
    VillageGeofence.debugSetDb(db);
  });

  tearDownAll(() {
    VillageGeofence.debugSetDb(null);
    db.dispose();
  });

  group('VillageGeofence.queryByCode', () {
    test('returns VillageInfo for existing villcode', () async {
      final result = await VillageGeofence.queryByCode('65000050015');
      expect(result, isNotNull);
      expect(result!.villcode, '65000050015');
      expect(result.towncode, '65000050');
      expect(result.countyName, '新北市');
      expect(result.townName, '新莊區');
      expect(result.villName, '西盛里');
      expect(result.villEng, 'Xisheng Vil.');
    });

    test('returns null for nonexistent villcode', () async {
      final result = await VillageGeofence.queryByCode('00000000000');
      expect(result, isNull);
    });

    test('returns correct data for second village', () async {
      final result = await VillageGeofence.queryByCode('64000060001');
      expect(result, isNotNull);
      expect(result!.countyName, '高雄市');
      expect(result.townName, '新興區');
      expect(result.villName, '大勇里');
      expect(result.villEng, 'Dayong Vil.');
    });
  });
}
