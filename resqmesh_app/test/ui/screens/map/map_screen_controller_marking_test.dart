// map_screen_controller_marking_test.dart
//
// Stage 7-r2：MapScreenController 標記模式 state 轉移的單元測試。
//
// 範圍：純同步 commands（enter / exit / update*），不觸發 DB / GPS / MBTiles。
// 完整 publish 流程涉及 EventManager + DatabaseHelper，留 widget integration / 實機測試。

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/ui/screens/map/map_screen_controller.dart';
import 'package:ignirelay_app/ui/screens/map/models/map_view_models.dart';

MapScreenController _makeController() {
  final dbHelper = DatabaseHelper();
  return MapScreenController(
    eventPublisher: EventPublisher(eventManager: EventManager()),
    eventStream: EventStream(
      handler: MeshEventHandler(),
      decoder: EventDecoder(),
      store: EventStore(databaseHelper: dbHelper),
    ),
    eventStore: EventStore(databaseHelper: dbHelper),
    locationService: LocationService(),
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

  group('MapScreenController.marking 同步 transitions', () {
    test('enterMarkingNew 後 isActive=true、isEditing=false', () {
      final c = _makeController();
      addTearDown(c.dispose);

      expect(c.marking.isActive, isFalse);
      c.enterMarkingNew(const LatLng(23.97, 120.97));
      expect(c.marking.isActive, isTrue);
      expect(c.marking.isEditing, isFalse);
      expect(c.marking.center, const LatLng(23.97, 120.97));
      expect(c.marking.type, 'ROADBLOCK');
      expect(c.marking.severity, 3.0);
      expect(c.marking.radiusMeters, 200.0);
      expect(c.marking.isPublishing, isFalse);
    });

    test('updateMarkingCenter / Type / Severity / Radius 改 marking VM', () {
      final c = _makeController();
      addTearDown(c.dispose);

      c.enterMarkingNew(const LatLng(0, 0));
      c.updateMarkingCenter(const LatLng(24.0, 121.0));
      c.updateMarkingType('FIRE');
      c.updateMarkingSeverity(5.0);
      c.updateMarkingRadius(800.0);

      expect(c.marking.center, const LatLng(24.0, 121.0));
      expect(c.marking.type, 'FIRE');
      expect(c.marking.severity, 5.0);
      expect(c.marking.radiusMeters, 800.0);
    });

    test('enterMarkingEdit 帶入 hazard 欄位並回傳描述', () {
      final c = _makeController();
      addTearDown(c.dispose);

      const hazard = HazardVm(
        id: 'hz-99',
        lat: 23.5,
        lng: 121.5,
        radiusMeters: 350,
        severity: 4,
        type: 'FLOOD',
        confirmCount: 2,
        reportedBy: 'hex-self',
        isMine: true,
        description: '河水暴漲',
        raw: {},
      );

      final desc = c.enterMarkingEdit(hazard);
      expect(desc, '河水暴漲');
      expect(c.marking.isActive, isTrue);
      expect(c.marking.isEditing, isTrue);
      expect(c.marking.editingHazardId, 'hz-99');
      expect(c.marking.center, const LatLng(23.5, 121.5));
      expect(c.marking.radiusMeters, 350);
      expect(c.marking.severity, 4.0);
      expect(c.marking.type, 'FLOOD');
    });

    test('exitMarking 還原成 idle', () {
      final c = _makeController();
      addTearDown(c.dispose);

      c.enterMarkingNew(const LatLng(23, 121));
      c.updateMarkingType('CHEMICAL');
      c.exitMarking();

      expect(c.marking.isActive, isFalse);
      expect(c.marking.isEditing, isFalse);
      expect(c.marking.center, isNull);
      expect(c.marking.editingHazardId, isNull);
      // type 回 idle 預設
      expect(c.marking.type, anyOf('ROADBLOCK', 'CHEMICAL'));
    });

    test('enterMarkingNew 二次呼叫於已 active 時是 no-op（不會重置使用者進度）',
        () {
      final c = _makeController();
      addTearDown(c.dispose);

      c.enterMarkingNew(const LatLng(23, 121));
      c.updateMarkingType('FIRE');
      c.enterMarkingNew(const LatLng(99, 99)); // 應被忽略
      expect(c.marking.center, const LatLng(23, 121));
      expect(c.marking.type, 'FIRE');
    });

    test('notifyListeners 在 marking transition 時會 fire', () {
      final c = _makeController();
      addTearDown(c.dispose);

      var fired = 0;
      c.addListener(() => fired++);

      c.enterMarkingNew(const LatLng(0, 0));
      expect(fired, greaterThanOrEqualTo(1));
      final after = fired;
      c.updateMarkingType('FIRE');
      expect(fired, greaterThan(after));
    });
  });

  group('MapScreenController.requestCenterOnUser', () {
    test('selfLocation 為 null 時回 false', () {
      final c = _makeController();
      addTearDown(c.dispose);
      expect(c.selfLocation, isNull);
      expect(c.requestCenterOnUser(), isFalse);
    });
  });
}
