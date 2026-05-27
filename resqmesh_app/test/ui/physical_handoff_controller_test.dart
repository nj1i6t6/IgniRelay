// physical_handoff_controller_test.dart
//
// Stage 2A：PhysicalHandoffController PIN FSM 單元測試。
//
// 範圍：requester 角色的 PIN 錯誤 / lockout state machine。
//   - requester + method != DROP_OFF 時 start() 為 no-op，不碰 BLE。
//   - providerDeviceId 缺失時 submitPin 走純本地 _handleWrongPin 路徑。
//   - 連網路徑（6 次錯誤觸發 publishMatchCancel）留 widget integration 測。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/handoff_controller.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/services/negotiation_repo.dart';
import 'package:ignirelay_app/ui/secondary/physical_handoff_controller.dart';

PhysicalHandoffController _makeRequester() {
  return PhysicalHandoffController(
    role: HandoffRole.requester,
    resourceId: 'res-1',
    resourceType: 'WATER',
    negotiationId: 'neg-1',
    method: 'PIN_4DIGIT',
    requestId: 'req-1',
    urgency: 1,
    providerDeviceId: null,
    eventPublisher: EventPublisher(eventManager: EventManager()),
    handoffController: HandoffController.instance,
    negotiationRepo: NegotiationRepo(),
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

  group('PhysicalHandoffController PIN FSM', () {
    test('初始 state 為 idle，pin 為 4 位數', () {
      final c = _makeRequester();
      addTearDown(c.dispose);

      expect(c.state, HandoffFsm.idle);
      expect(c.handoffComplete, isFalse);
      expect(c.handoffCancelled, isFalse);
      expect(c.pin.length, 4);
      expect(int.tryParse(c.pin), isNotNull);
    });

    test('requester + PIN_4DIGIT 的 start() 不改變 state', () {
      final c = _makeRequester();
      addTearDown(c.dispose);
      c.start();
      expect(c.state, HandoffFsm.idle);
    });

    test('providerDeviceId 缺失時 submitPin 回 wrong 並累加錯誤次數', () async {
      final c = _makeRequester();
      addTearDown(c.dispose);

      final r1 = await c.submitPin('1234');
      expect(r1, PinSubmitResult.wrong);
      expect(c.wrongAttempts, 1);
      expect(c.totalWrongAttempts, 1);
      expect(c.isLockedOut, isFalse);

      final r2 = await c.submitPin('5678');
      expect(r2, PinSubmitResult.wrong);
      expect(c.wrongAttempts, 2);
      expect(c.totalWrongAttempts, 2);
    });

    test('連續 3 次錯誤觸發 30 秒 lockout，wrongAttempts 歸零', () async {
      final c = _makeRequester();
      addTearDown(c.dispose);

      await c.submitPin('0000');
      await c.submitPin('0000');
      await c.submitPin('0000');

      expect(c.isLockedOut, isTrue);
      expect(c.lockoutSeconds, 30);
      expect(c.wrongAttempts, 0); // lockout 後歸零
      expect(c.totalWrongAttempts, 3); // total 不歸零
    });

    test('lockout 中 submitPin 回 lockedOut 且不累加 total', () async {
      final c = _makeRequester();
      addTearDown(c.dispose);

      await c.submitPin('0000');
      await c.submitPin('0000');
      await c.submitPin('0000');
      expect(c.isLockedOut, isTrue);

      final r = await c.submitPin('0000');
      expect(r, PinSubmitResult.lockedOut);
      expect(c.totalWrongAttempts, 3);
    });

    test('notifyListeners 在 submitPin 後 fire', () async {
      final c = _makeRequester();
      addTearDown(c.dispose);

      var fired = 0;
      c.addListener(() => fired++);
      await c.submitPin('1111');
      expect(fired, greaterThanOrEqualTo(1));
    });

    test('pendingTimeout 隨 urgency 變化', () {
      final low = _makeRequester();
      addTearDown(low.dispose);
      expect(low.pendingTimeout, const Duration(hours: 4));

      final high = PhysicalHandoffController(
        role: HandoffRole.requester,
        resourceId: 'r',
        resourceType: 'WATER',
        negotiationId: 'n',
        method: 'PIN_4DIGIT',
        requestId: 'q',
        urgency: 3,
        providerDeviceId: null,
        eventPublisher: EventPublisher(eventManager: EventManager()),
        handoffController: HandoffController.instance,
        negotiationRepo: NegotiationRepo(),
      );
      addTearDown(high.dispose);
      expect(high.pendingTimeout, const Duration(minutes: 30));
    });
  });

  // Bug #2 迴歸：交接角色必須由「身分」判定，不可由 deliveryMode 判定。
  // 過去用 deliveryMode（開導航時被塞空字串）→ 雙方都變 requester、沒人顯示 PIN。
  group('handoffRoleForIdentity（Bug #2 角色判定）', () {
    final myKey = List<int>.generate(32, (i) => i);
    final otherKey = List<int>.generate(32, (i) => 100 + i);

    test('本機 pubkey == provider pubkey → provider', () {
      expect(
        handoffRoleForIdentity(myPubKey: myKey, providerPubKey: myKey),
        HandoffRole.provider,
      );
    });

    test('本機 pubkey != provider pubkey → requester', () {
      expect(
        handoffRoleForIdentity(myPubKey: myKey, providerPubKey: otherKey),
        HandoffRole.requester,
      );
    });

    test('providerPubKey 為 null → requester（保守 fallback）', () {
      expect(
        handoffRoleForIdentity(myPubKey: myKey, providerPubKey: null),
        HandoffRole.requester,
      );
    });

    test('兩者皆空 list → requester（空不算 provider）', () {
      expect(
        handoffRoleForIdentity(myPubKey: const [], providerPubKey: const []),
        HandoffRole.requester,
      );
    });

    test('長度不同 → requester', () {
      expect(
        handoffRoleForIdentity(
            myPubKey: myKey, providerPubKey: myKey.sublist(0, 16)),
        HandoffRole.requester,
      );
    });
  });
}
