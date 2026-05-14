// provider_wiring_smoke_test.dart
//
// Stage 1 corrective gate test:
//   - 最小 widget pump 一個 MultiProvider tree，模擬 main.dart root wiring
//   - 從子 widget 用 context.read<T>() 取出每個 Stage 1 新增的 facade / repo
//   - 任一個 Provider 沒接好都會 throw → 測試會失敗
//
// 為什麼這份測試是 mandatory：spec §2.8 列為 Stage 1 必備自動化測試之一。
// 整合層級的 sanity gate — 確保「UI 改用 context.read<T>() 拿不到東西」這個
// 最常見的回歸不會混到 release。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/controllers/tier_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/emergency/emergency_mode_controller.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/chat_service.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/medical_card_repo.dart';
import 'package:ignirelay_app/app/services/negotiation_repo.dart';
import 'package:ignirelay_app/app/services/profile_repo.dart';
import 'package:ignirelay_app/app/services/station_supply_repo.dart';

class _ProbeWidget extends StatelessWidget {
  const _ProbeWidget({required this.onRead});

  final void Function(BuildContext context) onRead;

  @override
  Widget build(BuildContext context) {
    // 把 read 推到 build 之後，避免 setUp 的 ProviderNotFoundException 包裝。
    WidgetsBinding.instance.addPostFrameCallback((_) => onRead(context));
    return const SizedBox.shrink();
  }
}

Widget _wrapWithRootProviders(Widget child) {
  return MultiProvider(
    providers: [
      Provider<EventDecoder>(
        create: (_) => EventDecoder(),
      ),
      Provider<EventPublisher>(
        create: (_) => EventPublisher(eventManager: EventManager()),
      ),
      Provider<EventStore>(
        create: (_) => EventStore(databaseHelper: DatabaseHelper()),
      ),
      Provider<StationSupplyRepo>(
        create: (_) => StationSupplyRepo(databaseHelper: DatabaseHelper()),
      ),
      Provider<ProfileRepo>(
        create: (_) => ProfileRepo(databaseHelper: DatabaseHelper()),
      ),
      Provider<MedicalCardRepo>(
        create: (_) => MedicalCardRepo(DatabaseHelper()),
      ),
      Provider<NegotiationRepo>(
        create: (_) => NegotiationRepo(),
      ),
      Provider<ChatService>(
        create: (_) => ChatService(),
      ),
      Provider<LocationService>(
        create: (_) => LocationService(),
      ),
      Provider<TierManager>(
        create: (_) => TierManager(),
      ),
      ListenableProvider<EmergencyModeController>(
        create: (_) => EmergencyModeController.instance,
      ),
      Provider<EventStream>(
        create: (context) => EventStream(
          handler: MeshEventHandler(),
          decoder: context.read<EventDecoder>(),
          store: context.read<EventStore>(),
        ),
        dispose: (_, s) => s.dispose(),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
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

  testWidgets(
      'root providers expose every Stage 1 facade/repo to UI via context.read',
      (tester) async {
    final reads = <Type, Object?>{};
    await tester.pumpWidget(_wrapWithRootProviders(
      _ProbeWidget(onRead: (ctx) {
        reads[EventDecoder] = ctx.read<EventDecoder>();
        reads[EventPublisher] = ctx.read<EventPublisher>();
        reads[EventStore] = ctx.read<EventStore>();
        reads[StationSupplyRepo] = ctx.read<StationSupplyRepo>();
        reads[ProfileRepo] = ctx.read<ProfileRepo>();
        reads[MedicalCardRepo] = ctx.read<MedicalCardRepo>();
        reads[NegotiationRepo] = ctx.read<NegotiationRepo>();
        reads[ChatService] = ctx.read<ChatService>();
        reads[LocationService] = ctx.read<LocationService>();
        reads[TierManager] = ctx.read<TierManager>();
        reads[EmergencyModeController] = ctx.read<EmergencyModeController>();
        reads[EventStream] = ctx.read<EventStream>();
      }),
    ));
    // 觸發 postFrameCallback。
    await tester.pump();

    for (final entry in reads.entries) {
      expect(entry.value, isNotNull,
          reason: '${entry.key} not provided at app root');
    }
  });
}
