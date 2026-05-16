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

  /// SHA-256(author_key)[:8] — privacy filter mandated by spec §15.4.
  static Future<Uint8List> _shortAuthorHash(Uint8List key) async {
    final digest = await Sha256().hash(key);
    return Uint8List.fromList(digest.bytes.take(8).toList());
  }
}
