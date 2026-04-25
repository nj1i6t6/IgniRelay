// negotiation_fsm_test.dart
//
// Stage 4c — FSM 防呆專門測試
//   1. 合法/非法轉換矩陣（純靜態 canTransition）
//   2. 非法跳轉「不會回寫錯誤值」— 透過 guardedUpdateStatus 直接觸發，
//      驗證 DB status 欄位維持原值
//   3. onIllegalTransition hook 有被記錄
//   4. 公開 API 的早退層：終態上呼叫不會被誤改

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';

final _providerKey = Uint8List.fromList(List.generate(32, (i) => i));
final _requesterKey = Uint8List.fromList(List.generate(32, (i) => 0xFF - i));

// Stage 5-fix：counter 保證 in-memory DB 高速執行下 uid 仍唯一。
int _seq = 0;
String _uid(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_seq}';

Future<void> _seedMaterial(String resourceId) async {
  final db = await DatabaseHelper().database;
  await db.insert('Materials_State', {
    'resource_id': resourceId,
    'status': 'AVAILABLE',
    'hlc_timestamp': DateTime.now().millisecondsSinceEpoch,
    'hlc_counter': 0,
    'total_qty': 10.0,
    'delivery_mode': 'PICKUP',
  });
}

Future<void> _seedRequest(String requestId) async {
  final db = await DatabaseHelper().database;
  await db.insert('Requests_State', {
    'request_id': requestId,
    'event_id': _uid('ev'),
    'sender_pub_key': _requesterKey,
    'status': 'OPEN',
    'hlc_timestamp': DateTime.now().millisecondsSinceEpoch,
    'hlc_counter': 0,
    'quantity_needed': 5.0,
    'mobility_mode': 'CAN_GO',
    'note': 'test',
  });
}

Future<String> _seedNegotiation({required String status}) async {
  final negId = _uid('neg');
  final resId = _uid('res');
  final reqId = _uid('req');
  await _seedMaterial(resId);
  await _seedRequest(reqId);
  final db = await DatabaseHelper().database;
  await db.insert('Match_Negotiations', {
    'negotiation_id': negId,
    'resource_id': resId,
    'request_id': reqId,
    'initiator_role': 'PROVIDER',
    'provider_pub_key': _providerKey,
    'requester_pub_key': _requesterKey,
    'offered_qty': 5.0,
    'requested_qty': 5.0,
    'status': status,
    'created_at': DateTime.now().millisecondsSinceEpoch,
    'expires_at': DateTime.now().millisecondsSinceEpoch + 2700000,
  });
  return negId;
}

Future<String?> _readStatus(String negotiationId) async {
  final db = await DatabaseHelper().database;
  final rows = await db.query(
    'Match_Negotiations',
    columns: ['status'],
    where: 'negotiation_id = ?',
    whereArgs: [negotiationId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return rows.first['status'] as String?;
}

void main() {
  late NegotiationManager nm;

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
    nm = NegotiationManager();
    NegotiationManager.onIllegalTransition = null;
  });

  tearDown(() {
    NegotiationManager.onIllegalTransition = null;
  });

  // ═══════════════════════════════════════════════════════════════════
  // 1. 合法/非法轉換矩陣（純靜態）
  // ═══════════════════════════════════════════════════════════════════

  group('FSM canTransition — 合法矩陣', () {
    test('PENDING → {ACCEPTED, DECLINED, CANCELLED, EXPIRED} 全部合法', () {
      for (final to in ['ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED']) {
        expect(NegotiationManager.canTransition('PENDING', to), isTrue,
            reason: 'PENDING → $to should be legal');
      }
    });

    test('ACCEPTED → {NAVIGATING, COMPLETED, CANCELLED} 全部合法', () {
      for (final to in ['NAVIGATING', 'COMPLETED', 'CANCELLED']) {
        expect(NegotiationManager.canTransition('ACCEPTED', to), isTrue);
      }
    });

    test('NAVIGATING → {COMPLETED, CANCELLED} 全部合法', () {
      for (final to in ['COMPLETED', 'CANCELLED']) {
        expect(NegotiationManager.canTransition('NAVIGATING', to), isTrue);
      }
    });
  });

  group('FSM canTransition — 非法矩陣', () {
    test('終態 COMPLETED / DECLINED / CANCELLED / EXPIRED 無任何出邊', () {
      const terminals = ['COMPLETED', 'DECLINED', 'CANCELLED', 'EXPIRED'];
      const allStates = [
        'PENDING',
        'ACCEPTED',
        'NAVIGATING',
        'COMPLETED',
        'DECLINED',
        'CANCELLED',
        'EXPIRED',
      ];
      for (final from in terminals) {
        for (final to in allStates) {
          expect(NegotiationManager.canTransition(from, to), isFalse,
              reason: 'terminal $from should not transition to $to');
        }
      }
    });

    test('PENDING → {NAVIGATING, COMPLETED} 非法（必須先 ACCEPTED）', () {
      expect(NegotiationManager.canTransition('PENDING', 'NAVIGATING'), isFalse);
      expect(NegotiationManager.canTransition('PENDING', 'COMPLETED'), isFalse);
    });

    test('ACCEPTED / NAVIGATING → PENDING 不可回退', () {
      expect(NegotiationManager.canTransition('ACCEPTED', 'PENDING'), isFalse);
      expect(NegotiationManager.canTransition('NAVIGATING', 'PENDING'), isFalse);
    });

    test('NAVIGATING → {ACCEPTED, DECLINED, EXPIRED} 非法', () {
      for (final to in ['ACCEPTED', 'DECLINED', 'EXPIRED']) {
        expect(NegotiationManager.canTransition('NAVIGATING', to), isFalse);
      }
    });

    test('未知 from 狀態一律視為非法', () {
      expect(NegotiationManager.canTransition('UNKNOWN', 'ACCEPTED'), isFalse);
      expect(NegotiationManager.canTransition('', 'PENDING'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 2. 非法跳轉不回寫錯誤值（防呆重點）
  // ═══════════════════════════════════════════════════════════════════

  group('guardedUpdateStatus — 非法跳轉不回寫 DB', () {
    test('COMPLETED → PENDING：回傳 false，DB status 維持 COMPLETED', () async {
      final negId = await _seedNegotiation(status: 'COMPLETED');
      final ok = await nm.guardedUpdateStatus(negId, 'COMPLETED', 'PENDING');
      expect(ok, isFalse);
      expect(await _readStatus(negId), equals('COMPLETED'));
    });

    test('CANCELLED → ACCEPTED：回傳 false，DB 維持 CANCELLED', () async {
      final negId = await _seedNegotiation(status: 'CANCELLED');
      final ok = await nm.guardedUpdateStatus(negId, 'CANCELLED', 'ACCEPTED');
      expect(ok, isFalse);
      expect(await _readStatus(negId), equals('CANCELLED'));
    });

    test('EXPIRED → COMPLETED：回傳 false，DB 維持 EXPIRED', () async {
      final negId = await _seedNegotiation(status: 'EXPIRED');
      final ok = await nm.guardedUpdateStatus(negId, 'EXPIRED', 'COMPLETED');
      expect(ok, isFalse);
      expect(await _readStatus(negId), equals('EXPIRED'));
    });

    test('合法轉換（PENDING → ACCEPTED）則如實寫入 DB', () async {
      final negId = await _seedNegotiation(status: 'PENDING');
      final ok = await nm.guardedUpdateStatus(negId, 'PENDING', 'ACCEPTED');
      expect(ok, isTrue);
      expect(await _readStatus(negId), equals('ACCEPTED'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 3. onIllegalTransition hook — 非法事件被記錄
  // ═══════════════════════════════════════════════════════════════════

  group('onIllegalTransition hook', () {
    test('非法跳轉觸發 hook，攜帶 (id, from, to)', () async {
      final captured = <List<String>>[];
      NegotiationManager.onIllegalTransition = (id, from, to) {
        captured.add([id, from, to]);
      };

      final negId = await _seedNegotiation(status: 'COMPLETED');
      final ok = await nm.guardedUpdateStatus(negId, 'COMPLETED', 'PENDING');

      expect(ok, isFalse);
      expect(captured, hasLength(1));
      expect(captured.first[0], equals(negId));
      expect(captured.first[1], equals('COMPLETED'));
      expect(captured.first[2], equals('PENDING'));
    });

    test('合法跳轉不觸發 hook', () async {
      final captured = <List<String>>[];
      NegotiationManager.onIllegalTransition = (id, from, to) {
        captured.add([id, from, to]);
      };

      final negId = await _seedNegotiation(status: 'PENDING');
      await nm.guardedUpdateStatus(negId, 'PENDING', 'ACCEPTED');

      expect(captured, isEmpty);
    });

    test('未設定 hook 時非法跳轉不 crash，仍回 false', () async {
      NegotiationManager.onIllegalTransition = null;
      final negId = await _seedNegotiation(status: 'COMPLETED');
      final ok = await nm.guardedUpdateStatus(negId, 'COMPLETED', 'PENDING');
      expect(ok, isFalse);
      expect(await _readStatus(negId), equals('COMPLETED'));
    });

    test('hook 可解除註冊（設回 null）', () async {
      var called = 0;
      NegotiationManager.onIllegalTransition = (_, __, ___) => called++;
      NegotiationManager.onIllegalTransition = null;

      final negId = await _seedNegotiation(status: 'COMPLETED');
      await nm.guardedUpdateStatus(negId, 'COMPLETED', 'PENDING');
      expect(called, equals(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 4. 公開 API 的早退層：終態上呼叫不會被誤改
  // ═══════════════════════════════════════════════════════════════════

  group('公開 API early-return — 終態 neg 不被誤改', () {
    test('COMPLETED 上呼叫 startNavigating：狀態不變', () async {
      final negId = await _seedNegotiation(status: 'COMPLETED');
      await nm.startNavigating(negId);
      expect(await _readStatus(negId), equals('COMPLETED'));
    });

    test('CANCELLED 上呼叫 completeHandshake：狀態不變', () async {
      final negId = await _seedNegotiation(status: 'CANCELLED');
      await nm.completeHandshake(negId, _providerKey, 5.0);
      expect(await _readStatus(negId), equals('CANCELLED'));
    });

    test('DECLINED 上呼叫 cancelNegotiation：狀態不變', () async {
      final negId = await _seedNegotiation(status: 'DECLINED');
      await nm.cancelNegotiation(negId, _providerKey, 'test');
      expect(await _readStatus(negId), equals('DECLINED'));
    });

    test('EXPIRED 上呼叫 declineNegotiation：狀態不變', () async {
      final negId = await _seedNegotiation(status: 'EXPIRED');
      await nm.declineNegotiation(negId, _requesterKey, 'late');
      expect(await _readStatus(negId), equals('EXPIRED'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 5. 早退層也會觸發 onIllegalTransition hook（log sink 一致性）
  //
  //   對應 audit 指出的：public API 早退路徑（acceptNegotiation /
  //   declineNegotiation / cancelNegotiation / startNavigating /
  //   completeHandshake）必須與 guardedUpdateStatus 走同一條 log/hook。
  // ═══════════════════════════════════════════════════════════════════

  group('早退層觸發 onIllegalTransition', () {
    test('accept 一個已 COMPLETED 的 neg：hook 收到 COMPLETED→ACCEPTED', () async {
      final captured = <List<String>>[];
      NegotiationManager.onIllegalTransition =
          (id, from, to) => captured.add([id, from, to]);

      final negId = await _seedNegotiation(status: 'COMPLETED');
      final ok = await nm.acceptNegotiation(negId, _requesterKey);

      expect(ok, isFalse);
      expect(captured, hasLength(1));
      expect(captured.first[1], equals('COMPLETED'));
      expect(captured.first[2], equals('ACCEPTED'));
      expect(await _readStatus(negId), equals('COMPLETED'));
    });

    test('decline 一個已 ACCEPTED 的 neg：hook 收到 ACCEPTED→DECLINED', () async {
      final captured = <List<String>>[];
      NegotiationManager.onIllegalTransition =
          (id, from, to) => captured.add([id, from, to]);

      final negId = await _seedNegotiation(status: 'ACCEPTED');
      await nm.declineNegotiation(negId, _requesterKey, 'x');

      expect(captured, hasLength(1));
      expect(captured.first[1], equals('ACCEPTED'));
      expect(captured.first[2], equals('DECLINED'));
      expect(await _readStatus(negId), equals('ACCEPTED'));
    });

    test('cancel 一個 COMPLETED 的 neg：hook 收到 COMPLETED→CANCELLED', () async {
      final captured = <List<String>>[];
      NegotiationManager.onIllegalTransition =
          (id, from, to) => captured.add([id, from, to]);

      final negId = await _seedNegotiation(status: 'COMPLETED');
      await nm.cancelNegotiation(negId, _providerKey, 'x');

      expect(captured, hasLength(1));
      expect(captured.first[1], equals('COMPLETED'));
      expect(captured.first[2], equals('CANCELLED'));
      expect(await _readStatus(negId), equals('COMPLETED'));
    });

    test('startNavigating 一個 PENDING 的 neg：hook 收到 PENDING→NAVIGATING', () async {
      final captured = <List<String>>[];
      NegotiationManager.onIllegalTransition =
          (id, from, to) => captured.add([id, from, to]);

      final negId = await _seedNegotiation(status: 'PENDING');
      await nm.startNavigating(negId);

      expect(captured, hasLength(1));
      expect(captured.first[1], equals('PENDING'));
      expect(captured.first[2], equals('NAVIGATING'));
      expect(await _readStatus(negId), equals('PENDING'));
    });

    test('completeHandshake 一個 PENDING 的 neg：hook 收到 PENDING→COMPLETED', () async {
      final captured = <List<String>>[];
      NegotiationManager.onIllegalTransition =
          (id, from, to) => captured.add([id, from, to]);

      final negId = await _seedNegotiation(status: 'PENDING');
      await nm.completeHandshake(negId, _providerKey, 5.0);

      expect(captured, hasLength(1));
      expect(captured.first[1], equals('PENDING'));
      expect(captured.first[2], equals('COMPLETED'));
      expect(await _readStatus(negId), equals('PENDING'));
    });
  });
}
