import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/services/adapter_health_monitor.dart';
import 'package:ignirelay_app/app/services/mesh_trace_writer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
  });

  setUp(() async {
    await DatabaseHelper().resetForTest();
  });

  test('consumes adapter_health_tick stream and flags stale scan+advertise',
      () async {
    DateTime now = DateTime.fromMillisecondsSinceEpoch(1000000);
    final events = StreamController<dynamic>.broadcast();
    final monitor = AdapterHealthMonitor(
      nativeEventStream: events.stream,
      trace: MeshTraceWriter(DatabaseHelper()),
      now: () => now,
    );
    final seen = <AdapterHealthEvent>[];
    final sub = monitor.events.listen(seen.add);
    addTearDown(() async {
      await sub.cancel();
      await monitor.dispose();
      await events.close();
    });

    monitor.start();
    events.add({'type': 'adapter_health_tick', 'kind': 'scan'});
    events.add({'type': 'adapter_health_tick', 'kind': 'advertise'});
    await _drainMicrotasks();

    now = now.add(const Duration(minutes: 6));
    await monitor.debugEvaluateNow();
    await _drainMicrotasks();

    expect(seen.length, 1);
    expect(seen.single, isA<AdapterIdleTooLong>());
    await _expectSystemTrace('adapter_health:adapter_idle_too_long');
  });

  test('stale -> tick within window emits soft recover + trace', () async {
    DateTime now = DateTime.fromMillisecondsSinceEpoch(2000000);
    final monitor = AdapterHealthMonitor(
      nativeEventStream: const Stream<dynamic>.empty(),
      trace: MeshTraceWriter(DatabaseHelper()),
      now: () => now,
    );
    final seen = <AdapterHealthEvent>[];
    final sub = monitor.events.listen(seen.add);
    addTearDown(() async {
      await sub.cancel();
      await monitor.dispose();
    });

    monitor.debugInjectTick(AdapterHealthTick.scan);
    monitor.debugInjectTick(AdapterHealthTick.advertise);
    now = now.add(const Duration(minutes: 6));
    await monitor.debugEvaluateNow();
    now = now.add(const Duration(seconds: 5));
    monitor.debugInjectTick(AdapterHealthTick.scan);
    await _drainMicrotasks();

    expect(seen[0], isA<AdapterIdleTooLong>());
    expect(seen[1], isA<AdapterSoftRecover>());
    await _expectSystemTrace('adapter_health:adapter_soft_recover');
  });

  test('stale -> tick after window emits hard recover + trace', () async {
    DateTime now = DateTime.fromMillisecondsSinceEpoch(3000000);
    final monitor = AdapterHealthMonitor(
      nativeEventStream: const Stream<dynamic>.empty(),
      trace: MeshTraceWriter(DatabaseHelper()),
      now: () => now,
    );
    final seen = <AdapterHealthEvent>[];
    final sub = monitor.events.listen(seen.add);
    addTearDown(() async {
      await sub.cancel();
      await monitor.dispose();
    });

    monitor.debugInjectTick(AdapterHealthTick.scan);
    monitor.debugInjectTick(AdapterHealthTick.advertise);
    now = now.add(const Duration(minutes: 6));
    await monitor.debugEvaluateNow();
    now = now.add(const Duration(seconds: 11));
    monitor.debugInjectTick(AdapterHealthTick.advertise);
    await _drainMicrotasks();

    expect(seen[0], isA<AdapterIdleTooLong>());
    expect(seen[1], isA<AdapterHardRecover>());
    await _expectSystemTrace('adapter_health:adapter_hard_recover');
  });

  test('repeated stale checks escalate to permanent error + trace', () async {
    DateTime now = DateTime.fromMillisecondsSinceEpoch(4000000);
    final monitor = AdapterHealthMonitor(
      nativeEventStream: const Stream<dynamic>.empty(),
      trace: MeshTraceWriter(DatabaseHelper()),
      now: () => now,
    );
    final seen = <AdapterHealthEvent>[];
    final sub = monitor.events.listen(seen.add);
    addTearDown(() async {
      await sub.cancel();
      await monitor.dispose();
    });

    monitor.debugInjectTick(AdapterHealthTick.scan);
    monitor.debugInjectTick(AdapterHealthTick.advertise);
    now = now.add(const Duration(minutes: 6));
    await monitor.debugEvaluateNow(); // idle flag on
    now = now.add(const Duration(seconds: 1));
    await monitor.debugEvaluateNow(); // fail #1
    now = now.add(const Duration(seconds: 1));
    await monitor.debugEvaluateNow(); // fail #2 => permanent
    await _drainMicrotasks();

    expect(seen.whereType<AdapterPermanentError>().length, 1);
    await _expectSystemTrace('adapter_health:adapter_permanent_error');
  });
}

Future<void> _expectSystemTrace(String dropReason) async {
  final db = await DatabaseHelper().database;
  final rows = await db.query(
    'Mesh_Trace_Logs',
    where: 'drop_reason = ?',
    whereArgs: [dropReason],
  );
  expect(rows, isNotEmpty, reason: 'trace should contain $dropReason');
}

Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
