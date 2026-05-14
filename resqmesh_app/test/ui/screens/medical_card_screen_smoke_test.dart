// medical_card_screen_smoke_test.dart
//
// Stage 2B widget smoke test：MedicalCardScreen thin shell。
//
// 範圍：確認 thin shell 能在鏡像 main.dart 的 provider tree 下 pumpWidget 起來、
//   建出 MedicalCardController 並完成 load()、渲染三個 section 而不丟例外。
//   Health Connect 匯入 / 實際存檔流程留 manual smoke / 實機測。

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/platform/native_bridge_facade.dart';
import 'package:ignirelay_app/ui/secondary/medical_basic_section.dart';
import 'package:ignirelay_app/ui/secondary/medical_card_screen.dart';

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
    FlutterSecureStorage.setMockInitialValues({});
    await IdentityManager().initialize();
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

  testWidgets('MedicalCardScreen pumps and loads sections', (tester) async {
    await tester.pumpWidget(wrapStage2aScreen(const MedicalCardScreen()));
    // load() 是 async：pump 一次觸發 build，再 settle 等 controller 載完。
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(MedicalCardScreen), findsOneWidget);
    expect(find.byType(MedicalBasicSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
