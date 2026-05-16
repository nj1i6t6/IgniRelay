// Periodic tombstone GC + envelope expiry sweeper (v0.3 Stage 0c).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §13.6, §13.7, §15.3.
//
// Runs three jobs in one transaction per tick:
//   1. Convert expired envelopes (now > expires_at_hlc + grace) to tombstones.
//   2. Delete tombstones whose `tombstone_until_ms < now`.
//   3. Cap-evict oldest tombstones when count > MAX_TOMBSTONE_ROWS, and trim
//      Mesh_Trace_Logs older than 24h or above MAX_TRACE_ROWS.

import 'dart:async';
import 'dart:typed_data';

import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';

class SweepStats {
  final int convertedToTombstone;
  final int deletedExpiredTombstones;
  final int capEvictedTombstones;
  final int deletedOldTraces;

  const SweepStats({
    required this.convertedToTombstone,
    required this.deletedExpiredTombstones,
    required this.capEvictedTombstones,
    required this.deletedOldTraces,
  });

  @override
  String toString() => 'SweepStats(toTombstone=$convertedToTombstone '
      'expiredDeleted=$deletedExpiredTombstones '
      'capEvicted=$capEvictedTombstones '
      'tracesPruned=$deletedOldTraces)';
}

class TombstoneSweeper {
  final DatabaseHelper _db;
  Timer? _timer;

  TombstoneSweeper(this._db);

  /// Start periodic sweeps. Default interval = 60 minutes per spec §13.6.
  void start({Duration interval = const Duration(minutes: 60)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => sweep());
  }

  /// Stop the timer (cleanup or test teardown).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Run one sweep tick. Returns counts so the caller can log.
  Future<SweepStats> sweep({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final nowMs = clock.millisecondsSinceEpoch;
    final db = await _db.database;

    return await db.transaction((txn) async {
      // 1) Expired envelopes → tombstones (per-event-type grace period).
      var converted = 0;
      final expiringRows = await txn.query(
        'Envelopes_V2',
        columns: const ['envelope_id', 'event_type', 'expires_at_hlc_ms'],
        where: 'is_tombstoned = 0',
      );
      for (final row in expiringRows) {
        final eventType = row['event_type'] as int;
        final expiresAt = row['expires_at_hlc_ms'] as int;
        final grace = _gracePeriodFor(eventType);
        if (expiresAt + grace <= nowMs) {
          final id = row['envelope_id'] as Uint8List;
          await txn.update(
            'Envelopes_V2',
            {'is_tombstoned': 1, 'payload': Uint8List(0)},
            where: 'envelope_id = ?',
            whereArgs: [id],
          );
          await txn.rawInsert(
            'INSERT OR REPLACE INTO Tombstones_V2 '
            '(envelope_id, event_type, expired_at_ms, tombstone_until_ms) '
            'VALUES (?, ?, ?, ?)',
            [id, eventType, expiresAt, expiresAt + kTombstoneTtlMs],
          );
          converted++;
        }
      }

      // 2) Tombstones past their TTL → delete from both tables.
      final expiredCount = await txn.rawDelete(
        'DELETE FROM Tombstones_V2 WHERE tombstone_until_ms < ?',
        [nowMs],
      );
      await txn.rawDelete(
        'DELETE FROM Envelopes_V2 WHERE is_tombstoned = 1 AND envelope_id NOT IN '
        '(SELECT envelope_id FROM Tombstones_V2)',
      );

      // 3) Cap-evict tombstones above MAX_TOMBSTONE_ROWS.
      var capEvicted = 0;
      final tombCountRow = await txn.rawQuery('SELECT COUNT(*) AS n FROM Tombstones_V2');
      final tombCount = (tombCountRow.first['n'] as int?) ?? 0;
      if (tombCount > kMaxTombstoneRows) {
        final overflow = tombCount - kMaxTombstoneRows;
        capEvicted = await txn.rawDelete(
          'DELETE FROM Tombstones_V2 WHERE envelope_id IN '
          '(SELECT envelope_id FROM Tombstones_V2 ORDER BY tombstone_until_ms ASC LIMIT ?)',
          [overflow],
        );
      }

      // 4) Mesh_Trace_Logs retention: 24h TTL + MAX_TRACE_ROWS hard cap.
      final cutoff = nowMs - kMeshTraceRetentionMs;
      final pruned = await txn.rawDelete(
        'DELETE FROM Mesh_Trace_Logs WHERE ts_ms < ?',
        [cutoff],
      );
      final traceCountRow = await txn.rawQuery('SELECT COUNT(*) AS n FROM Mesh_Trace_Logs');
      final traceCount = (traceCountRow.first['n'] as int?) ?? 0;
      var prunedExtra = 0;
      if (traceCount > kMaxTraceRows) {
        final overflow = traceCount - kMaxTraceRows;
        prunedExtra = await txn.rawDelete(
          'DELETE FROM Mesh_Trace_Logs WHERE id IN '
          '(SELECT id FROM Mesh_Trace_Logs ORDER BY ts_ms ASC LIMIT ?)',
          [overflow],
        );
      }

      return SweepStats(
        convertedToTombstone: converted,
        deletedExpiredTombstones: expiredCount,
        capEvictedTombstones: capEvicted,
        deletedOldTraces: pruned + prunedExtra,
      );
    });
  }

  /// Spec §13.4 — per-event-class grace period.
  static int _gracePeriodFor(int eventType) {
    if (eventType == EventTypeV2.chatMessage) {
      return kTombstoneGracePeriodChatMs;
    }
    // SOS-class envelopes (statusUpdate carrying SOS, plus dedicated SOS-style
    // payloads in the future) — keep around for diagnostic. For now we treat
    // statusUpdate as carrying SOS state and inherit the SOS grace window.
    if (eventType == EventTypeV2.statusUpdate) {
      return kTombstoneGracePeriodSosMs;
    }
    return kTombstoneGracePeriodDefaultMs;
  }
}
