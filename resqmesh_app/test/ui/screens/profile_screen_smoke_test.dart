// profile_screen_smoke_test.dart
//
// Stage 2B widget smoke test：IgniProfileScreen thin shell。
//
// 範圍：確認 thin shell 能在鏡像 main.dart 的 provider tree 下 pumpWidget 起來、
//   完成 _load()（身分 / 暱稱 / 是否有醫療卡）、渲染身分卡 / 信任等級 / 設定
//   三個 section 而不丟例外。升級 / 編輯暱稱等互動留 manual smoke / 實機測。

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/platform/native_bridge_facade.dart';
import 'package:ignirelay_app/ui/screens/me/profile_identity_section.dart';
import 'package:ignirelay_app/ui/screens/me/profile_screen.dart';
import 'package:ignirelay_app/ui/screens/me/profile_settings_section.dart';
import 'package:ignirelay_app/ui/screens/me/profile_tier_section.dart';

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

  testWidgets('IgniProfileScreen pumps and loads sections', (tester) async {
    // 放大 surface 讓整條 ListView 一次 layout，section 才都會 build。
    await tester.binding.setSurfaceSize(const Size(1200, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrapStage2aScreen(const IgniProfileScreen()));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(IgniProfileScreen), findsOneWidget);
    expect(find.byType(ProfileIdentityCard), findsOneWidget);
    expect(find.byType(ProfileTierList), findsOneWidget);
    expect(find.byType(ProfileSettingsCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
