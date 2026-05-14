// match_screen_smoke_test.dart
//
// Stage 2A widget smoke test：MatchScreen thin shell。
//
// 範圍：確認 4-tab thin shell 能在鏡像 main.dart 的 provider tree 下 pumpWidget
//   起來、建出 MatchScreenController（含 NegotiationManager / MatchRepository /
//   IdentityManager 都改為 context.read 注入）、不丟例外。完整媒合流程留 manual
//   smoke / 實機測。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/platform/native_bridge_facade.dart';
import 'package:ignirelay_app/ui/screens/match/match_screen.dart';

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

  testWidgets('MatchScreen pumps with root providers', (tester) async {
    await tester.pumpWidget(wrapStage2aScreen(const MatchScreen()));
    await tester.pump();

    expect(find.byType(MatchScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
