// match_screen_controller_test.dart
//
// Stage 2A：MatchScreenController 單元測試。
//
// 範圍：初始 state + MatchOutcome pattern-match helper。
//   - init / loadAll / action handlers 涉及 NegotiationManager + MatchRepository
//     + EventPublisher 連網路徑，留 widget integration / 實機測。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    FlutterSecureStorage.setMockInitialValues({});
    await IdentityManager().initialize();
  });

  setUp(() async {
    await DatabaseHelper().resetForTest();
    EventManager().resetRateLimit();
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

    test(
        'community action on remote supply creates local request and MATCH_REQUEST negotiation',
        () async {
      final c = _makeController();
      addTearDown(c.dispose);

      const remoteProviderKey = <int>[
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
        7,
      ];
      const item = CommunityItem(
        eventId: 'remote-supply-event',
        isSupply: true,
        resourceId: 'remote-resource-id',
        senderPubKey: remoteProviderKey,
        resourceType: 'WATER/BOTTLED',
        quantity: 5,
        description: '',
        urgency: 1,
        identityLevel: 0,
        timestamp: 1,
      );

      await c.communityAction(
        item,
        2,
        resourceName: 'water',
        communityNote: 'need water',
      );

      final rows =
          await (await DatabaseHelper().database).query('Match_Negotiations');
      expect(rows, hasLength(1));
      final neg = rows.single;
      expect(neg['resource_id'], 'remote-resource-id');
      expect(neg['initiator_role'], 'REQUESTER');
      expect(neg['status'], 'PENDING');
      expect((neg['requested_qty'] as num).toDouble(), 2);
    });

    test(
        'community action on remote request creates local supply and MATCH_OFFER negotiation',
        () async {
      final c = _makeController();
      addTearDown(c.dispose);

      const remoteRequesterKey = <int>[
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
        8,
      ];
      const item = CommunityItem(
        eventId: 'remote-request-event',
        isSupply: false,
        requestId: 'remote-request-id',
        senderPubKey: remoteRequesterKey,
        resourceType: 'WATER/BOTTLED',
        quantity: 3,
        description: '',
        urgency: 1,
        identityLevel: 0,
        timestamp: 1,
      );

      await c.communityAction(
        item,
        2,
        resourceName: 'water',
        communityNote: 'can help',
      );

      final rows =
          await (await DatabaseHelper().database).query('Match_Negotiations');
      expect(rows, hasLength(1));
      final neg = rows.single;
      expect(neg['request_id'], 'remote-request-id');
      expect(neg['initiator_role'], 'PROVIDER');
      expect(neg['status'], 'PENDING');
      expect((neg['offered_qty'] as num).toDouble(), 2);
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
      expect(
          label(const MatchOutcome.communityRequestOk(3, '水')), 'commReq:3:水');
      expect(
          label(const MatchOutcome.communitySupplyOk(5, '米')), 'commSup:5:米');
      expect(label(const MatchOutcome.communityFail('x')), 'commFail:x');
    });
  });
}
