// station_supply_controller_test.dart
//
// Stage 2A：StationSupplyController 單元測試。
//
// 範圍：初始 state + StationMeta 編解碼往返。
//   - checkAccessAndLoad / loadStationItems 涉及 IdentityManager 身分等級與
//     EventStore 查詢，留 widget integration / 實機測。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/station_supply_repo.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_controller.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_models.dart';

StationSupplyController _makeController() {
  final db = DatabaseHelper();
  return StationSupplyController(
    eventStore: EventStore(databaseHelper: db),
    decoder: EventDecoder(),
    repo: StationSupplyRepo(databaseHelper: db),
    publisher: EventPublisher(eventManager: EventManager()),
    identity: IdentityManager(),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    await DatabaseHelper().resetForTest();
  });

  group('StationSupplyController', () {
    test('初始 state：未檢查、loading、空清單', () {
      final c = _makeController();
      addTearDown(c.dispose);

      expect(c.checked, isFalse);
      expect(c.loading, isTrue);
      expect(c.authorized, isFalse);
      expect(c.items, isEmpty);
    });
  });

  group('StationMeta 編解碼', () {
    test('toJson / tryParse 往返保留欄位', () {
      const meta = StationMeta(
        isStation: true,
        perUserCategoryLimit: 5,
        perUserTotalLimit: 10,
        resetIntervalMs: 86400000,
        visibleZones: ['6300100', '6300200'],
      );
      final encoded = 'STATION:${meta.toJson()}';
      final parsed = StationMeta.tryParse(encoded);

      expect(parsed, isNotNull);
      expect(parsed!.isStation, isTrue);
      expect(parsed.perUserCategoryLimit, 5);
      expect(parsed.perUserTotalLimit, 10);
      expect(parsed.resetIntervalMs, 86400000);
      expect(parsed.visibleZones, ['6300100', '6300200']);
      expect(parsed.visibleTownship, isNull);
    });

    test('township 模式往返', () {
      const meta = StationMeta(
        isStation: true,
        perUserCategoryLimit: 3,
        perUserTotalLimit: 8,
        resetIntervalMs: 0,
        visibleTownship: '63000',
      );
      final parsed = StationMeta.tryParse('STATION:${meta.toJson()}');
      expect(parsed!.visibleTownship, '63000');
      expect(parsed.visibleZones, isNull);
      expect(parsed.resetIntervalMs, 0);
    });

    test('非 STATION: 前綴回 null', () {
      expect(StationMeta.tryParse('PICKUP'), isNull);
      expect(StationMeta.tryParse(''), isNull);
    });

    test('STATION: 後接損壞 json 回 null（不丟例外）', () {
      expect(StationMeta.tryParse('STATION:{bad'), isNull);
    });
  });
}
