// match_screen_controller_test.dart
//
// Stage 2A：MatchScreenController 單元測試。
//
// 範圍：初始 state + MatchOutcome pattern-match helper。
//   - init / loadAll / action handlers 涉及 NegotiationManager + MatchRepository
//     + EventPublisher 連網路徑，留 widget integration / 實機測。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/location_service.dart';
import 'package:ignirelay_app/app/services/match_repository.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';
import 'package:ignirelay_app/ui/screens/match/match_screen_controller.dart';

MatchScreenController _makeController() {
  final db = DatabaseHelper();
  return MatchScreenController(
    eventPublisher: EventPublisher(eventManager: EventManager()),
    eventStream: EventStream(
      handler: MeshEventHandler(),
      decoder: EventDecoder(),
      store: EventStore(databaseHelper: db),
    ),
    negotiationManager: NegotiationManager(),
    repository: MatchRepository(),
    identity: IdentityManager(),
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

  group('MatchScreenController', () {
    test('初始 state：loading、空清單、無錯誤', () {
      final c = _makeController();
      addTearDown(c.dispose);

      expect(c.loading, isTrue);
      expect(c.mySupplies, isEmpty);
      expect(c.myRequests, isEmpty);
      expect(c.mySupplyPublishes, isEmpty);
      expect(c.activeNegotiations, isEmpty);
      expect(c.communityItems, isEmpty);
      expect(c.error, isNull);
      expect(c.gpsWarning, isNull);
      expect(c.myPubKey, isNull);
    });
  });

  group('whenMatchOutcome pattern-match helper', () {
    String label(MatchOutcome o) => whenMatchOutcome<String>(
          o,
          negotiationAccepted: () => 'negAccepted',
          negotiationDeclined: () => 'negDeclined',
          negotiationCancelled: () => 'negCancelled',
          handoffComplete: () => 'handoffComplete',
          negotiationExpired: () => 'negExpired',
          oversoldDetected: () => 'oversold',
          acceptOk: () => 'acceptOk',
          declineOk: () => 'declineOk',
          cancelSupplyOk: (n) => 'cancelSupply:$n',
          cancelRequestOk: (n) => 'cancelRequest:$n',
          acceptFail: (e) => 'acceptFail:$e',
          declineFail: (e) => 'declineFail:$e',
          cancelFail: (e) => 'cancelFail:$e',
          communityRequestOk: (q, n) => 'commReq:$q:$n',
          communitySupplyOk: (q, n) => 'commSup:$q:$n',
          communityFail: (e) => 'commFail:$e',
        );

    test('無參數 outcome 分支', () {
      expect(label(const MatchOutcome.negotiationAccepted()), 'negAccepted');
      expect(label(const MatchOutcome.handoffComplete()), 'handoffComplete');
      expect(label(const MatchOutcome.acceptOk()), 'acceptOk');
      expect(label(const MatchOutcome.oversoldDetected()), 'oversold');
    });

    test('帶 resourceName / error 的 outcome 分支', () {
      expect(label(const MatchOutcome.cancelSupplyOk('水')), 'cancelSupply:水');
      expect(label(const MatchOutcome.cancelRequestOk('米')), 'cancelRequest:米');
      expect(label(const MatchOutcome.acceptFail('boom')), 'acceptFail:boom');
      expect(label(const MatchOutcome.cancelFail('nope')), 'cancelFail:nope');
    });

    test('帶 qty + resourceName 的 community outcome 分支', () {
      expect(label(const MatchOutcome.communityRequestOk(3, '水')), 'commReq:3:水');
      expect(label(const MatchOutcome.communitySupplyOk(5, '米')), 'commSup:5:米');
      expect(label(const MatchOutcome.communityFail('x')), 'commFail:x');
    });
  });
}
