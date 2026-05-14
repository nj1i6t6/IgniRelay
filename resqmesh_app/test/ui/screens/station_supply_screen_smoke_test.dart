// station_supply_screen_smoke_test.dart
//
// Stage 2A widget smoke test：StationSupplyScreen thin shell。
//
// 範圍：確認 thin shell 能在鏡像 main.dart 的 provider tree 下 pumpWidget 起來、
//   建出 StationSupplyController、不丟例外。完整領取流程（建站 / 改額度 / 重設）
//   留 manual smoke / 實機測。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/platform/native_bridge_facade.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_screen.dart';

import '../../fakes/fake_native_bridge.dart';
import 'stage2a_smoke_harness.dart';

void main() {
  late FakeNativeBridge fakeBridge;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    await DatabaseHelper().resetForTest();
    fakeBridge = FakeNativeBridge();
    NativeBridgeFacade.instance = fakeBridge;
  });

  tearDown(() {
    fakeBridge.dispose();
    NativeBridgeFacade.resetToReal();
  });

  testWidgets('StationSupplyScreen pumps with root providers', (tester) async {
    await tester.pumpWidget(wrapStage2aScreen(const StationSupplyScreen()));
    await tester.pump();

    expect(find.byType(StationSupplyScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
