// stage2a_smoke_harness.dart
//
// Stage 2A widget smoke tests 共用骨架（非 _test.dart，不會被當測試跑）。
//
// 提供一個 MultiProvider tree，鏡像 main.dart 的 root wiring，讓 4 個 thin shell
// 能 pumpWidget 起來、確認「screen 能在 provider tree 下 build 而不 throw」。
// BLE / handoff 平台路徑用 FakeNativeBridge 替身，避免碰真實 platform channel。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/controllers/ble_scan_controller.dart';
import 'package:ignirelay_app/app/controllers/device_info_controller.dart';
import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/controllers/handoff_controller.dart';
import 'package:ignirelay_app/app/controllers/mesh_runtime_controller.dart';
import 'package:ignirelay_app/app/controllers/tier_manager.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';
import 'package:ignirelay_app/app/services/medical_card_repo.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';
import 'package:ignirelay_app/app/services/negotiation_repo.dart';
import 'package:ignirelay_app/app/services/profile_repo.dart';
import 'package:ignirelay_app/app/services/station_supply_repo.dart';
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';
import 'package:ignirelay_app/platform/mesh_transport.dart';
import 'package:ignirelay_app/ui/theme/app_theme.dart';

/// 不碰平台 channel 的 MeshTransport 替身：所有 stream 為空、stats 為零。
/// 讓 [MeshRuntimeController] 在測試環境下有 transport 可用。
class _FakeMeshTransport implements MeshTransport {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<String> broadcast(Uint8List data) async => 'fake-msg';
  @override
  Future<String> sendToNode(String nodeId, Uint8List data) async => 'fake-msg';
  @override
  Stream<MeshDataReceived> get onDataReceived => const Stream.empty();
  @override
  Stream<String> get onPeerConnected => const Stream.empty();
  @override
  Stream<String> get onPeerDisconnected => const Stream.empty();
  @override
  Stream<TransportState> get onStateChanged => const Stream.empty();
  @override
  bool get isActive => false;
  @override
  TransportStats get stats => const TransportStats();
  @override
  void dispose() {}
}

/// 把 [child] 包進一個鏡像 main.dart root 的 provider tree + MaterialApp。
///
/// 同時對 [MeshRuntimeController] 注入 fake transport，鏡像 main.dart 於
/// `runApp` 前的 `attachTransport()`。
Widget wrapStage2aScreen(Widget child) {
  MeshRuntimeController.instance.attachTransport(_FakeMeshTransport());
  return MultiProvider(
    providers: [
      Provider<EventDecoder>(create: (_) => EventDecoder()),
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
      Provider<NegotiationRepo>(create: (_) => NegotiationRepo()),
      Provider<NegotiationManager>(create: (_) => NegotiationManager()),
      Provider<MatchRepository>(create: (_) => MatchRepository()),
      Provider<IdentityManager>(create: (_) => IdentityManager()),
      Provider<LocationService>(create: (_) => LocationService()),
      Provider<TierManager>(create: (_) => TierManager()),
      Provider<DeviceInfoController>(
        create: (_) => DeviceInfoController.instance,
      ),
      Provider<BleScanController>(create: (_) => BleScanController.instance),
      Provider<MeshRuntimeController>(
        create: (_) => MeshRuntimeController.instance,
      ),
      Provider<HandoffController>(create: (_) => HandoffController.instance),
      Provider<EventStream>(
        create: (context) => EventStream(
          handler: MeshEventHandler(),
          decoder: context.read<EventDecoder>(),
          store: context.read<EventStore>(),
        ),
        dispose: (_, s) => s.dispose(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('zh'),
      supportedLocales: S.supportedLocales,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // MatchScreen 在正式 app 內由主 shell 的 Scaffold 承載（body 不自帶
      // Material）；測試鏡像同一條件，包一層 Scaffold 提供 Material ancestor。
      home: Scaffold(body: child),
    ),
  );
}
