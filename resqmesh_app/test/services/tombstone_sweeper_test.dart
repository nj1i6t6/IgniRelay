// v0.3 Stage 0c — TombstoneSweeper: expired→tombstone + GC + trace pruning.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/tombstone_sweeper.dart';
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

  Future<void> _insertEnvelope(int eventType, int expiresAtMs,
      {int idByte = 1}) async {
    final db = await DatabaseHelper().database;
    await db.insert('Envelopes_V2', {
      'envelope_id': Uint8List.fromList(List.filled(16, idByte)),
      'protocol_version': 2,
      'event_type': eventType,
      'priority': PriorityV2.status,
      'created_at_hlc_ms': 1,
      'created_at_hlc_ctr': 0,
      'expires_at_hlc_ms': expiresAtMs,
      'expires_at_hlc_ctr': 0,
      'max_hops': 6,
      'hop_count_seen': 0,
      'author_key': Uint8List(32),
      'sig_algo': 1,
      'signature': Uint8List(64),
      'payload': Uint8List.fromList([1, 2, 3]),
      'signature_status': 0,
      'source_trust': 3,
      'is_experimental': 0,
      'relay_attempt_count': 0,
      'is_tombstoned': 0,
      'was_surfaced_in_ui': 0,
      'received_at_ms': 1,
    });
  }

  test('expired envelope past grace becomes tombstone with payload cleared', () async {
    final db = await DatabaseHelper().database;
    final now = DateTime.fromMillisecondsSinceEpoch(10000000000);
    // chat_message uses 5min grace; insert with expires=now-1h so it's deep past grace.
    await _insertEnvelope(
      EventTypeV2.chatMessage,
      now.millisecondsSinceEpoch - Duration(hours: 1).inMilliseconds,
    );
    final stats = await TombstoneSweeper(DatabaseHelper()).sweep(now: now);
    expect(stats.convertedToTombstone, 1);

    final rows = await db.query('Envelopes_V2');
    expect(rows.first['is_tombstoned'], 1);
    expect((rows.first['payload'] as Uint8List).length, 0);

    final tomb = await db.query('Tombstones_V2');
    expect(tomb.length, 1);
  });

  test('SOS-class grace is longer (still alive after 1 h past expiry)', () async {
    final db = await DatabaseHelper().database;
    final now = DateTime.fromMillisecondsSinceEpoch(20000000000);
    // statusUpdate uses 6h grace; expires=now-1h is INSIDE grace.
    await _insertEnvelope(
      EventTypeV2.statusUpdate,
      now.millisecondsSinceEpoch - Duration(hours: 1).inMilliseconds,
    );
    final stats = await TombstoneSweeper(DatabaseHelper()).sweep(now: now);
    expect(stats.convertedToTombstone, 0);
    final rows = await db.query('Envelopes_V2');
    expect(rows.first['is_tombstoned'], 0,
        reason: 'SOS grace is 6h; should not yet tombstone');
  });

  test('tombstone past TOMBSTONE_TTL is GC-deleted', () async {
    final db = await DatabaseHelper().database;
    final now = DateTime.fromMillisecondsSinceEpoch(50000000000);
    // Insert tombstone with tombstone_until_ms in the past.
    await db.insert('Tombstones_V2', {
      'envelope_id': Uint8List.fromList(List.filled(16, 9)),
      'event_type': EventTypeV2.statusUpdate,
      'expired_at_ms': now.millisecondsSinceEpoch - Duration(days: 30).inMilliseconds,
      'tombstone_until_ms': now.millisecondsSinceEpoch - 1,
    });
    final stats = await TombstoneSweeper(DatabaseHelper()).sweep(now: now);
    expect(stats.deletedExpiredTombstones, 1);
    final rows = await db.query('Tombstones_V2');
    expect(rows.length, 0);
  });

  test('mesh trace logs older than 24 h are pruned', () async {
    final db = await DatabaseHelper().database;
    final now = DateTime.fromMillisecondsSinceEpoch(60000000000);
    final old = now.millisecondsSinceEpoch - Duration(days: 2).inMilliseconds;
    final fresh = now.millisecondsSinceEpoch - Duration(hours: 1).inMilliseconds;
    for (final ts in [old, old, fresh]) {
      await db.insert('Mesh_Trace_Logs', {
        'ts_ms': ts,
        'envelope_id': Uint8List(16),
        'event_type': 1,
        'priority': 1,
        'author_key_hash': Uint8List(8),
        'created_at_hlc_ms': 1,
        'expires_at_hlc_ms': 2,
        'action': 1,
      });
    }
    final stats = await TombstoneSweeper(DatabaseHelper()).sweep(now: now);
    expect(stats.deletedOldTraces, 2);
    final remaining = await db.query('Mesh_Trace_Logs');
    expect(remaining.length, 1);
  });

  test('exposes spec constants for tombstone TTL', () {
    // sanity: kTombstoneTtlMs == 7 days
    expect(kTombstoneTtlMs, 7 * 24 * 60 * 60 * 1000);
  });
}
// ignore_for_file: prefer_const_constructors, no_leading_underscores_for_local_identifiers
