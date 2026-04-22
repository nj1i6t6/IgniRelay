// negotiation_manager_test.dart
//
// 測試 NegotiationManager 狀態機 — CAS、角色授權、PENDING 限制、
// orphan 事件、超時清理、oversold 偵測、reconcile 邏輯
//
// 使用 sqflite_common_ffi (in-memory SQLite) + mocked SharedPreferences。

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/services/negotiation_manager.dart';
import 'package:ignirelay_app/app/services/negotiation_events.dart';

String _uid(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

final _providerKey = Uint8List.fromList(List.generate(32, (i) => i));
final _requesterKey = Uint8List.fromList(List.generate(32, (i) => 0xFF - i));
final _unknownKey = Uint8List.fromList(List.generate(32, (i) => 0x80));

Future<String> _seedMaterial(String resourceId,
    {double totalQty = 10.0, String deliveryMode = 'PICKUP'}) async {
  final db = await DatabaseHelper().database;
  await db.insert('Materials_State', {
    'resource_id': resourceId,
    'status': 'AVAILABLE',
    'hlc_timestamp': DateTime.now().millisecondsSinceEpoch,
    'hlc_counter': 0,
    'total_qty': totalQty,
    'delivery_mode': deliveryMode,
  });
  return resourceId;
}

Future<String> _seedRequest(String requestId,
    {double quantityNeeded = 5.0}) async {
  final db = await DatabaseHelper().database;
  await db.insert('Requests_State', {
    'request_id': requestId,
    'event_id': _uid('ev'),
    'sender_pub_key': _requesterKey,
    'status': 'OPEN',
    'hlc_timestamp': DateTime.now().millisecondsSinceEpoch,
    'hlc_counter': 0,
    'quantity_needed': quantityNeeded,
    'mobility_mode': 'CAN_GO',
    'note': 'test',
  });
  return requestId;
}

Future<String> _createNeg(NegotiationManager nm,
    {String? resourceId,
    String? requestId,
    double offeredQty = 5.0,
    double requestedQty = 5.0,
    String initiatorRole = 'PROVIDER'}) async {
  final negId = _uid('neg');
  final rId = resourceId ?? _uid('res');
  final qId = requestId ?? _uid('req');
  if (resourceId == null) await _seedMaterial(rId, totalQty: 10.0);
  if (requestId == null) await _seedRequest(qId, quantityNeeded: 10.0);

  await nm.createNegotiation(
    negotiationId: negId,
    resourceId: rId,
    requestId: qId,
    initiatorRole: initiatorRole,
    providerPubKey: _providerKey,
    requesterPubKey: _requesterKey,
    offeredQty: offeredQty,
    requestedQty: requestedQty,
    expiresAt: DateTime.now().millisecondsSinceEpoch + 2700000,
  );
  return negId;
}

void main() {
  late NegotiationManager nm;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await IdentityManager().initialize();
  });

  setUp(() {
    nm = NegotiationManager();
  });

  // ═══════════════════════════════════════════════════════════════════
  // createNegotiation
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — createNegotiation', () {
    test('creates negotiation successfully', () async {
      final negId = _uid('neg');
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));

      final ok = await nm.createNegotiation(
        negotiationId: negId,
        resourceId: resId,
        requestId: reqId,
        initiatorRole: 'PROVIDER',
        providerPubKey: _providerKey,
        requesterPubKey: _requesterKey,
        offeredQty: 5.0,
        requestedQty: 3.0,
        expiresAt: DateTime.now().millisecondsSinceEpoch + 2700000,
      );
      expect(ok, isTrue);

      final neg = await nm.getNegotiation(negId);
      expect(neg, isNotNull);
      expect(neg!['status'], equals('PENDING'));
    });

    test('emits NegotiationCreated event', () async {
      final events = <NegotiationEvent>[];
      final sub = nm.events.listen(events.add);

      await _createNeg(nm);
      await Future.delayed(Duration.zero);

      expect(events.any((e) => e is NegotiationCreated), isTrue);
      await sub.cancel();
    });

    test('Rule 6: max 3 PENDING per request', () async {
      final resId1 = await _seedMaterial(_uid('res'));
      final resId2 = await _seedMaterial(_uid('res'));
      final resId3 = await _seedMaterial(_uid('res'));
      final resId4 = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));

      // Use different resource IDs to avoid partial unique index conflict
      final ok1 = await nm.createNegotiation(
        negotiationId: _uid('neg'),
        resourceId: resId1,
        requestId: reqId,
        initiatorRole: 'PROVIDER',
        providerPubKey: _providerKey,
        requesterPubKey: _requesterKey,
        offeredQty: 1,
        requestedQty: 1,
        expiresAt: DateTime.now().millisecondsSinceEpoch + 2700000,
      );
      final ok2 = await nm.createNegotiation(
        negotiationId: _uid('neg'),
        resourceId: resId2,
        requestId: reqId,
        initiatorRole: 'PROVIDER',
        providerPubKey: _providerKey,
        requesterPubKey: _requesterKey,
        offeredQty: 1,
        requestedQty: 1,
        expiresAt: DateTime.now().millisecondsSinceEpoch + 2700000,
      );
      final ok3 = await nm.createNegotiation(
        negotiationId: _uid('neg'),
        resourceId: resId3,
        requestId: reqId,
        initiatorRole: 'PROVIDER',
        providerPubKey: _providerKey,
        requesterPubKey: _requesterKey,
        offeredQty: 1,
        requestedQty: 1,
        expiresAt: DateTime.now().millisecondsSinceEpoch + 2700000,
      );
      // 4th should fail
      final ok4 = await nm.createNegotiation(
        negotiationId: _uid('neg'),
        resourceId: resId4,
        requestId: reqId,
        initiatorRole: 'PROVIDER',
        providerPubKey: _providerKey,
        requesterPubKey: _requesterKey,
        offeredQty: 1,
        requestedQty: 1,
        expiresAt: DateTime.now().millisecondsSinceEpoch + 2700000,
      );

      expect(ok1, isTrue);
      expect(ok2, isTrue);
      expect(ok3, isTrue);
      expect(ok4, isFalse, reason: 'Rule 6: max 3 PENDING per request');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // acceptNegotiation — CAS + role auth
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — acceptNegotiation', () {
    test('accept by responder succeeds (PROVIDER initiated → requester responds)',
        () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      final ok = await nm.acceptNegotiation(negId, _requesterKey);
      expect(ok, isTrue);

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('ACCEPTED'));
    });

    test('accept by initiator fails (role auth — not responder)', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      // Provider initiated, so provider cannot accept
      final ok = await nm.acceptNegotiation(negId, _providerKey);
      expect(ok, isFalse);

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('PENDING'));
    });

    test('accept by unknown key fails', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      final ok = await nm.acceptNegotiation(negId, _unknownKey);
      expect(ok, isFalse);
    });

    test('accept on non-PENDING negotiation fails', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      // Accept once
      await nm.acceptNegotiation(negId, _requesterKey);
      // Try accept again
      final ok = await nm.acceptNegotiation(negId, _requesterKey);
      expect(ok, isFalse);
    });

    test('emits NegotiationAccepted event', () async {
      final events = <NegotiationEvent>[];
      final sub = nm.events.listen(events.add);

      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);
      await nm.acceptNegotiation(negId, _requesterKey);
      await Future.delayed(Duration.zero);

      expect(events.whereType<NegotiationAccepted>().any(
            (e) => e.negotiationId == negId,
          ), isTrue);
      await sub.cancel();
    });

    test('CAS: inventory check — agreed qty limited by available', () async {
      final resId = await _seedMaterial(_uid('res'), totalQty: 3.0);
      final reqId = await _seedRequest(_uid('req'), quantityNeeded: 10.0);
      final negId = await _createNeg(nm,
          resourceId: resId,
          requestId: reqId,
          offeredQty: 10.0,
          requestedQty: 10.0);

      await nm.acceptNegotiation(negId, _requesterKey);

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('ACCEPTED'));
      // agreed_qty should be capped at available (3.0)
      expect((neg['agreed_qty'] as num).toDouble(), closeTo(3.0, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // declineNegotiation
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — declineNegotiation', () {
    test('decline by responder succeeds', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.declineNegotiation(negId, _requesterKey, 'TOO_FAR');

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('DECLINED'));
    });

    test('decline by non-responder is ignored', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      // Provider can't decline their own offer
      await nm.declineNegotiation(negId, _providerKey, 'NO');

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('PENDING'));
    });

    test('emits NegotiationDeclined event', () async {
      final events = <NegotiationEvent>[];
      final sub = nm.events.listen(events.add);

      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);
      await nm.declineNegotiation(negId, _requesterKey, 'REASON');
      await Future.delayed(Duration.zero);

      expect(events.whereType<NegotiationDeclined>().isNotEmpty, isTrue);
      await sub.cancel();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // cancelNegotiation
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — cancelNegotiation', () {
    test('provider can cancel PENDING negotiation', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.cancelNegotiation(negId, _providerKey, 'USER_CANCEL');

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('CANCELLED'));
    });

    test('requester can cancel PENDING negotiation', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.cancelNegotiation(negId, _requesterKey, 'USER_CANCEL');

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('CANCELLED'));
    });

    test('unknown key cannot cancel', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.cancelNegotiation(negId, _unknownKey, 'ATTACKER');

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('PENDING'));
    });

    test('cancel on COMPLETED negotiation is no-op', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.acceptNegotiation(negId, _requesterKey);
      await nm.completeHandshake(negId, _providerKey, 3.0);

      final statusBefore = (await nm.getNegotiation(negId))!['status'];
      expect(statusBefore, equals('COMPLETED'));

      await nm.cancelNegotiation(negId, _providerKey, 'TRY_CANCEL');

      final statusAfter = (await nm.getNegotiation(negId))!['status'];
      expect(statusAfter, equals('COMPLETED'));
    });

    test('cancel ACCEPTED negotiation reconciles material status back', () async {
      final resId = await _seedMaterial(_uid('res'), totalQty: 5.0);
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm,
          resourceId: resId, requestId: reqId, offeredQty: 5.0, requestedQty: 5.0);

      await nm.acceptNegotiation(negId, _requesterKey);
      // After accept, material should be DEPLETED
      final db = await DatabaseHelper().database;
      var mat = await db.query('Materials_State',
          where: 'resource_id = ?', whereArgs: [resId]);
      expect(mat.first['status'], equals('DEPLETED'));

      // Cancel restores it
      await nm.cancelNegotiation(negId, _providerKey, 'CANCEL');
      mat = await db.query('Materials_State',
          where: 'resource_id = ?', whereArgs: [resId]);
      expect(mat.first['status'], equals('AVAILABLE'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // startNavigating + completeHandshake
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — navigation & handshake', () {
    test('startNavigating transitions ACCEPTED → NAVIGATING', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.acceptNegotiation(negId, _requesterKey);
      await nm.startNavigating(negId);

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('NAVIGATING'));
    });

    test('startNavigating on PENDING is no-op', () async {
      final negId = await _createNeg(nm);
      await nm.startNavigating(negId);

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('PENDING'));
    });

    test('completeHandshake transitions to COMPLETED', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.acceptNegotiation(negId, _requesterKey);
      await nm.completeHandshake(negId, _providerKey, 4.0);

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('COMPLETED'));
      expect((neg['actual_delivered_qty'] as num).toDouble(), closeTo(4.0, 0.01));
    });

    test('completeHandshake by non-participant is rejected', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.acceptNegotiation(negId, _requesterKey);
      await nm.completeHandshake(negId, _unknownKey, 4.0);

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('ACCEPTED')); // not completed
    });

    test('emits NegotiationNavigating and NegotiationCompleted events',
        () async {
      final events = <NegotiationEvent>[];
      final sub = nm.events.listen(events.add);

      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);
      await nm.acceptNegotiation(negId, _requesterKey);
      await nm.startNavigating(negId);
      await nm.completeHandshake(negId, _providerKey, 3.0);
      await Future.delayed(Duration.zero);

      expect(events.whereType<NegotiationNavigating>().isNotEmpty, isTrue);
      expect(events.whereType<NegotiationCompleted>().isNotEmpty, isTrue);
      await sub.cancel();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Location updates
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — updateLocation', () {
    test('provider location update writes provider_lat/lng', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.acceptNegotiation(negId, _requesterKey);
      await nm.updateLocation(negId, _providerKey, 25.034, 121.564);

      final neg = await nm.getNegotiation(negId);
      expect((neg!['provider_lat'] as num).toDouble(), closeTo(25.034, 0.001));
    });

    test('requester location update writes requester_lat/lng', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.acceptNegotiation(negId, _requesterKey);
      await nm.updateLocation(negId, _requesterKey, 24.999, 121.555);

      final neg = await nm.getNegotiation(negId);
      expect((neg!['requester_lat'] as num).toDouble(), closeTo(24.999, 0.001));
    });

    test('unknown key location update is rejected', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);

      await nm.updateLocation(negId, _unknownKey, 25.0, 121.0);

      final neg = await nm.getNegotiation(negId);
      expect(neg!['provider_lat'], isNull);
    });

    test('emits LocationUpdated event', () async {
      final events = <NegotiationEvent>[];
      final sub = nm.events.listen(events.add);

      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm, resourceId: resId, requestId: reqId);
      await nm.acceptNegotiation(negId, _requesterKey);
      await nm.updateLocation(negId, _providerKey, 25.0, 121.0);
      await Future.delayed(Duration.zero);

      final locEvents = events.whereType<LocationUpdated>().toList();
      expect(locEvents.isNotEmpty, isTrue);
      expect(locEvents.first.isProvider, isTrue);
      await sub.cancel();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // expireStaleNegotiations
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — expireStaleNegotiations', () {
    test('expired PENDING negotiation transitions to EXPIRED', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));

      // Create with already-expired timestamp
      final negId = _uid('neg');
      await nm.createNegotiation(
        negotiationId: negId,
        resourceId: resId,
        requestId: reqId,
        initiatorRole: 'PROVIDER',
        providerPubKey: _providerKey,
        requesterPubKey: _requesterKey,
        offeredQty: 5.0,
        requestedQty: 5.0,
        expiresAt: DateTime.now().millisecondsSinceEpoch - 1000,
      );

      await nm.expireStaleNegotiations();

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('EXPIRED'));
    });

    test('non-expired PENDING negotiation stays PENDING', () async {
      final negId = await _createNeg(nm);
      await nm.expireStaleNegotiations();

      final neg = await nm.getNegotiation(negId);
      expect(neg!['status'], equals('PENDING'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Oversold detection
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — checkOversold', () {
    test('normal inventory does not trigger OversoldDetected', () async {
      final events = <NegotiationEvent>[];
      final sub = nm.events.listen(events.add);

      final resId = await _seedMaterial(_uid('res'), totalQty: 10.0);
      await nm.checkOversold(resId);
      await Future.delayed(Duration.zero);

      expect(events.whereType<OversoldDetected>().isEmpty, isTrue);
      await sub.cancel();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Query helpers
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — query helpers', () {
    test('getAvailableQty returns correct water-level', () async {
      final resId = await _seedMaterial(_uid('res'), totalQty: 10.0);
      final reqId = await _seedRequest(_uid('req'));
      final negId = await _createNeg(nm,
          resourceId: resId, requestId: reqId, offeredQty: 3.0, requestedQty: 3.0);

      // Before accept: full inventory
      var avail = await nm.getAvailableQty(resId);
      expect(avail, closeTo(10.0, 0.01));

      // After accept: reduced
      await nm.acceptNegotiation(negId, _requesterKey);
      avail = await nm.getAvailableQty(resId);
      expect(avail, closeTo(7.0, 0.01));
    });

    test('getRemainingNeed returns correct value', () async {
      final resId = await _seedMaterial(_uid('res'), totalQty: 10.0);
      final reqId = await _seedRequest(_uid('req'), quantityNeeded: 8.0);
      final negId = await _createNeg(nm,
          resourceId: resId, requestId: reqId, offeredQty: 3.0, requestedQty: 3.0);

      // Before accept: full need
      var remaining = await nm.getRemainingNeed(reqId);
      expect(remaining, closeTo(8.0, 0.01));

      // After accept: reduced
      await nm.acceptNegotiation(negId, _requesterKey);
      remaining = await nm.getRemainingNeed(reqId);
      expect(remaining, closeTo(5.0, 0.01));
    });

    test('getActiveNegotiations returns active items', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));
      await _createNeg(nm, resourceId: resId, requestId: reqId);

      final active = await nm.getActiveNegotiations();
      expect(active.isNotEmpty, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Full protocol flow: create → accept → navigate → complete
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — full protocol flow', () {
    test('PENDING → ACCEPTED → NAVIGATING → COMPLETED', () async {
      final events = <NegotiationEvent>[];
      final sub = nm.events.listen(events.add);

      final resId = await _seedMaterial(_uid('res'), totalQty: 10.0);
      final reqId = await _seedRequest(_uid('req'), quantityNeeded: 5.0);
      final negId = await _createNeg(nm,
          resourceId: resId, requestId: reqId, offeredQty: 5.0, requestedQty: 5.0);

      // Step 1: Accept
      final accepted = await nm.acceptNegotiation(negId, _requesterKey);
      expect(accepted, isTrue);
      expect((await nm.getNegotiation(negId))!['status'], equals('ACCEPTED'));

      // Step 2: Navigate
      await nm.startNavigating(negId);
      expect((await nm.getNegotiation(negId))!['status'], equals('NAVIGATING'));

      // Step 3: Complete
      await nm.completeHandshake(negId, _providerKey, 5.0);
      expect((await nm.getNegotiation(negId))!['status'], equals('COMPLETED'));

      await Future.delayed(Duration.zero);

      // Verify event sequence
      expect(events.whereType<NegotiationCreated>().isNotEmpty, isTrue);
      expect(events.whereType<NegotiationAccepted>().isNotEmpty, isTrue);
      expect(events.whereType<NegotiationNavigating>().isNotEmpty, isTrue);
      expect(events.whereType<NegotiationCompleted>().isNotEmpty, isTrue);

      await sub.cancel();
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // REQUESTER-initiated negotiation (bidirectional matching)
  // ═══════════════════════════════════════════════════════════════════

  group('NegotiationManager — requester-initiated flow', () {
    test('REQUESTER initiator: provider is the responder', () async {
      final resId = await _seedMaterial(_uid('res'));
      final reqId = await _seedRequest(_uid('req'));

      final negId = _uid('neg');
      await nm.createNegotiation(
        negotiationId: negId,
        resourceId: resId,
        requestId: reqId,
        initiatorRole: 'REQUESTER',
        providerPubKey: _providerKey,
        requesterPubKey: _requesterKey,
        offeredQty: 0,
        requestedQty: 3.0,
        expiresAt: DateTime.now().millisecondsSinceEpoch + 2700000,
      );

      // Provider is responder — should succeed
      final ok = await nm.acceptNegotiation(negId, _providerKey);
      expect(ok, isTrue);

      // Requester is initiator — cannot accept their own request
      final resId2 = await _seedMaterial(_uid('res'));
      final reqId2 = await _seedRequest(_uid('req'));
      final negId2 = _uid('neg');
      await nm.createNegotiation(
        negotiationId: negId2,
        resourceId: resId2,
        requestId: reqId2,
        initiatorRole: 'REQUESTER',
        providerPubKey: _providerKey,
        requesterPubKey: _requesterKey,
        offeredQty: 0,
        requestedQty: 3.0,
        expiresAt: DateTime.now().millisecondsSinceEpoch + 2700000,
      );
      final ok2 = await nm.acceptNegotiation(negId2, _requesterKey);
      expect(ok2, isFalse);
    });
  });
}
