// Mesh_Trace_Logs writer (v0.3 Stage 0c).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §15.
//
// Structured trace log per envelope action. NEVER stores `payload` bytes;
// `author_key` is hashed (SHA-256[:8]) before insertion.

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

class TraceAction {
  static const int sent = 0;
  static const int received = 1;
  static const int dropped = 2;
  static const int relayed = 3;
}

class TraceDedupe {
  static const int miss = 0;
  static const int hit = 1;
}

class MeshTraceWriter {
  final DatabaseHelper _db;

  MeshTraceWriter(this._db);

  /// Write one row to `Mesh_Trace_Logs`. All `*_hash`/privacy-sensitive
  /// transforms happen here so callers cannot accidentally leak raw
  /// `author_key` bytes into the log table.
  Future<void> write({
    required Uint8List envelopeId,
    required int eventType,
    required int priority,
    required Uint8List authorKey,
    String? lastRelayId,
    required int createdAtHlcMs,
    required int expiresAtHlcMs,
    required int action,
    String? dropReason,
    int? dedupeOutcome,
    int? signatureStatus,
    int? sourceTrust,
    int? hopCountSeen,
    int? relayAttemptCount,
    String? peerId,
    DateTime? at,
  }) async {
    final db = await _db.database;
    final hash = await _shortAuthorHash(authorKey);
    await db.insert('Mesh_Trace_Logs', {
      'ts_ms': (at ?? DateTime.now()).millisecondsSinceEpoch,
      'envelope_id': envelopeId,
      'event_type': eventType,
      'priority': priority,
      'author_key_hash': hash,
      'last_relay_id': lastRelayId,
      'created_at_hlc_ms': createdAtHlcMs,
      'expires_at_hlc_ms': expiresAtHlcMs,
      'action': action,
      'drop_reason': dropReason,
      'dedupe_outcome': dedupeOutcome,
      'signature_status': signatureStatus,
      'source_trust': sourceTrust,
      'hop_count_seen': hopCountSeen,
      'relay_attempt_count': relayAttemptCount,
      'peer_id': peerId,
    });
  }

  /// Stage 0c wave 3E — write a non-envelope system event (e.g. adapter
  /// health transitions, debug-hook toggles) to the same Mesh_Trace_Logs
  /// table so the dev-mode trace screen + 0d gate test runner can observe
  /// adapter state changes alongside envelope flow.
  ///
  /// System events use a synthetic envelope_id (16 zero bytes + ASCII
  /// `'SYS'` overlay) so they sort distinctively from real UUIDv7
  /// envelope_ids. The drop_reason column carries a `<category>:<action>`
  /// string (e.g. `adapter_health:adapter_soft_recover`) for indexable
  /// querying; the `last_relay_id` column carries the freeform `detail`
  /// because Mesh_Trace_Logs has no generic 'note' field and adding one
  /// is a v0.4 schema concern.
  Future<void> writeSystemEvent({
    required String category,
    required String action,
    String? detail,
    DateTime? at,
  }) async {
    final db = await _db.database;
    final syntheticId = Uint8List(16);
    // ASCII 'SYS' = 0x53 0x59 0x53 — placed at offsets 0..2 so the row is
    // easy to spot in a hex dump. Bytes 3..15 stay 0x00.
    syntheticId[0] = 0x53; syntheticId[1] = 0x59; syntheticId[2] = 0x53;
    await db.insert('Mesh_Trace_Logs', {
      'ts_ms': (at ?? DateTime.now()).millisecondsSinceEpoch,
      'envelope_id': syntheticId,
      'event_type': 0,
      'priority': 0,
      'author_key_hash': Uint8List(8),
      'last_relay_id': detail,
      'created_at_hlc_ms': 0,
      'expires_at_hlc_ms': 0,
      'action': TraceAction.dropped, // closest existing action; reused for system events
      'drop_reason': '$category:$action',
      'dedupe_outcome': null,
      'signature_status': null,
      'source_trust': null,
      'hop_count_seen': null,
      'relay_attempt_count': null,
      'peer_id': null,
    });
  }

  /// SHA-256(author_key)[:8] — privacy filter mandated by spec §15.4.
  static Future<Uint8List> _shortAuthorHash(Uint8List key) async {
    final digest = await Sha256().hash(key);
    return Uint8List.fromList(digest.bytes.take(8).toList());
  }
}
