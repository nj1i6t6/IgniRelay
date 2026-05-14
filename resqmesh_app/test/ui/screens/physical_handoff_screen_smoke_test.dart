// physical_handoff_screen_smoke_test.dart
//
// Stage 2A widget smoke test：PhysicalHandoffScreen thin shell。
//
// 範圍：確認 thin shell 能在鏡像 main.dart 的 provider tree 下 pumpWidget 起來、
//   依 role × method 挑出對應 step view（handoff_pin_views / handoff_dropoff_views）
//   而不丟例外。完整 PIN / BLE / drop-off 交接流程留 manual smoke / 實機測。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/platform/native_bridge_facade.dart';
import 'package:ignirelay_app/ui/secondary/handoff_dropoff_views.dart';
import 'package:ignirelay_app/ui/secondary/handoff_pin_views.dart';
import 'package:ignirelay_app/ui/secondary/physical_handoff.dart';

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

  testWidgets('PhysicalHandoffScreen requester PIN view pumps', (tester) async {
    await tester.pumpWidget(wrapStage2aScreen(
      const PhysicalHandoffScreen(
        role: HandoffRole.requester,
        resourceId: 'res-1',
        resourceType: 'WATER',
        negotiationId: 'neg-1',
        method: 'PIN_4DIGIT',
        requestId: 'req-1',
      ),
    ));
    await tester.pump();

    expect(find.byType(PhysicalHandoffScreen), findsOneWidget);
    expect(find.byType(HandoffRequesterPinView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PhysicalHandoffScreen provider DROP_OFF view pumps',
      (tester) async {
    await tester.pumpWidget(wrapStage2aScreen(
      const PhysicalHandoffScreen(
        role: HandoffRole.provider,
        resourceId: 'res-2',
        resourceType: 'FOOD',
        negotiationId: 'neg-2',
        method: 'DROP_OFF',
      ),
    ));
    await tester.pump();

    expect(find.byType(HandoffDropOffProviderView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
