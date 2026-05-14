// survival_mode_controller_test.dart
//
// Stage 2A：SurvivalModeController 單元測試。
//
// 範圍：初始 state + BleToggleOutcome pattern-match helper。
//   - init / toggleBle / toggleDataMule / exportLogs 涉及 MeshRuntimeController
//     與平台 channel，留 widget integration / 實機測。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/controllers/ble_scan_controller.dart';
import 'package:ignirelay_app/app/controllers/device_info_controller.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/controllers/mesh_runtime_controller.dart';
import 'package:ignirelay_app/app/controllers/tier_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/profile_repo.dart';
import 'package:ignirelay_app/ui/secondary/survival_mode_controller.dart';

SurvivalModeController _makeController() {
  final db = DatabaseHelper();
  return SurvivalModeController(
    mesh: MeshRuntimeController.instance,
    deviceInfo: DeviceInfoController.instance,
    tierManager: TierManager(),
    eventStream: EventStream(
      handler: MeshEventHandler(),
      decoder: EventDecoder(),
      store: EventStore(databaseHelper: db),
    ),
    bleScanController: BleScanController.instance,
    eventStore: EventStore(databaseHelper: db),
    profileRepo: ProfileRepo(databaseHelper: db),
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

  group('SurvivalModeController', () {
    test('初始 state：未啟用、batteryLevel=-1、空統計', () {
      final c = _makeController();
      addTearDown(c.dispose);

      expect(c.isDataMule, isFalse);
      expect(c.isBleActive, isFalse);
      expect(c.batteryLevel, -1);
      expect(c.totalEventCount, 0);
      expect(c.bleConnectedCount, 0);
      expect(c.recentEvents, isEmpty);
      expect(c.gattServerLogs, isEmpty);
    });

    test('recentEvents / gattServerLogs getter 回不可變 view', () {
      final c = _makeController();
      addTearDown(c.dispose);

      expect(() => c.recentEvents.add('x'), throwsUnsupportedError);
      expect(() => c.gattServerLogs.add('x'), throwsUnsupportedError);
    });
  });

  group('whenBleOutcome pattern-match helper', () {
    test('started / stopped / permissionDenied 分支', () {
      expect(
        whenBleOutcome<String>(
          BleToggleOutcome.started,
          started: () => 'started',
          stopped: () => 'stopped',
          permissionDenied: () => 'denied',
          startFailed: (m) => 'fail:$m',
        ),
        'started',
      );
      expect(
        whenBleOutcome<String>(
          BleToggleOutcome.stopped,
          started: () => 'started',
          stopped: () => 'stopped',
          permissionDenied: () => 'denied',
          startFailed: (m) => 'fail:$m',
        ),
        'stopped',
      );
      expect(
        whenBleOutcome<String>(
          BleToggleOutcome.permissionDenied,
          started: () => 'started',
          stopped: () => 'stopped',
          permissionDenied: () => 'denied',
          startFailed: (m) => 'fail:$m',
        ),
        'denied',
      );
    });

    test('startFailed 帶 message', () {
      expect(
        whenBleOutcome<String>(
          BleToggleOutcome.startFailed('boom'),
          started: () => 'started',
          stopped: () => 'stopped',
          permissionDenied: () => 'denied',
          startFailed: (m) => 'fail:$m',
        ),
        'fail:boom',
      );
    });
  });
}
