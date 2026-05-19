// EventEnvelope v2 storage facade (v0.3 Stage 0c).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §10, §12, §13.
//
// Wraps the `Envelopes_V2` / `Lww_Index_V2` / `Tombstones_V2` /
// `Official_Sources_V2` tables. UI / app code never touches the raw rows;
// the dispatcher (EnvelopeDispatcherV2) calls into this facade.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/priority_matrix_v2.dart';

/// Tri-state result of `tryStore` so callers can record the right trace.
enum StoreOutcome {
  inserted,
  duplicate,
  tombstoned,
}

class StoreResult {
  final StoreOutcome outcome;
  final EventEnvelopeV2 envelope;
  final SourceTrust sourceTrust;
  final bool isLwwWinner;

  const StoreResult({
    required this.outcome,
    required this.envelope,
    required this.sourceTrust,
    required this.isLwwWinner,
  });
}

class EnvelopeStoreV2 {
  final DatabaseHelper _db;

  EnvelopeStoreV2(this._db);

  /// Insert an envelope and (where applicable) update the LWW winner. Returns
  /// `duplicate` when the envelope_id is already known (live OR tombstoned).
  /// Idempotent: feeding the same envelope twice never creates two rows.
  Future<StoreResult> tryStore({
    required EventEnvelopeV2 envelope,
    required int signatureStatus, // 0=VALID etc. per envelope_v2_spec §3.3
    String? firstSeenVia,
  }) async {
    final db = await _db.database;
    final id = envelope.envelopeId;

    // 1) Tombstone hit — peer pushed an envelope we already expired & GC'd.
    final tomb = await db.query(
      'Tombstones_V2',
      where: 'envelope_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (tomb.isNotEmpty) {
      return StoreResult(
        outcome: StoreOutcome.tombstoned,
        envelope: envelope,
        sourceTrust: SourceTrust.unverified,
        isLwwWinner: false,
      );
    }

    // 2) Live row — dedupe.
    final existing = await db.query(
      'Envelopes_V2',
      columns: const ['envelope_id'],
      where: 'envelope_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final sourceTrust = await _resolveSourceTrust(envelope.authorKey, envelope.eventType);
    if (existing.isNotEmpty) {
      return StoreResult(
        outcome: StoreOutcome.duplicate,
        envelope: envelope,
        sourceTrust: sourceTrust,
        isLwwWinner: false,
      );
    }

    // 3) Insert.
    await db.insert('Envelopes_V2', {
      'envelope_id': id,
      'protocol_version': envelope.protocolVersion,
      'event_type': envelope.eventType,
      'priority': envelope.priority,
      'created_at_hlc_ms': envelope.createdAtHlc.msSinceEpoch,
      'created_at_hlc_ctr': envelope.createdAtHlc.counter,
      'expires_at_hlc_ms': envelope.expiresAtHlc.msSinceEpoch,
      'expires_at_hlc_ctr': envelope.expiresAtHlc.counter,
      'max_hops': envelope.maxHops,
      'hop_count_seen': 0,
      'author_key': envelope.authorKey,
      'sig_algo': envelope.sigAlgo,
      'signature': envelope.signature,
      'payload': envelope.payload,
      'signature_status': signatureStatus,
      'source_trust': _sourceTrustToInt(sourceTrust),
      'last_relay_id': envelope.lastRelayId.isEmpty ? null : envelope.lastRelayId,
      'is_experimental': envelope.isExperimental ? 1 : 0,
      'relay_attempt_count': 0,
      'is_tombstoned': 0,
      'was_surfaced_in_ui': 0,
      'received_at_ms': DateTime.now().millisecondsSinceEpoch,
      'first_seen_via': firstSeenVia,
    });

    // 4) LWW maintenance for snapshot-typed events.
    final isWinner = await _maybeUpdateLwwIndex(envelope);

    return StoreResult(
      outcome: StoreOutcome.inserted,
      envelope: envelope,
      sourceTrust: sourceTrust,
      isLwwWinner: isWinner,
    );
  }

  /// Mark an envelope as tombstoned and clear its `payload`. Inserts the
  /// tombstone row that participates in IBLT/Bloom membership (§13.5).
  Future<void> tombstone({
    required Uint8List envelopeId,
    required int eventType,
    required int gracePeriodMs,
    DateTime? at,
  }) async {
    final db = await _db.database;
    final now = (at ?? DateTime.now()).millisecondsSinceEpoch;
    await db.update(
      'Envelopes_V2',
      {
        'is_tombstoned': 1,
        'payload': Uint8List(0),
      },
      where: 'envelope_id = ?',
      whereArgs: [envelopeId],
    );
    await db.insert(
      'Tombstones_V2',
      {
        'envelope_id': envelopeId,
        'event_type': eventType,
        'expired_at_ms': now,
        'tombstone_until_ms': now + 7 * 24 * 60 * 60 * 1000, // §13.4 TOMBSTONE_TTL = 7d
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Whether the envelope_id is already known locally (live OR tombstoned).
  /// Used by Reassembler to suppress chunk-for-dispatched.
  Future<bool> isKnownEnvelopeId(Uint8List envelopeId) async {
    final db = await _db.database;
    final live = await db.query('Envelopes_V2',
        columns: const ['envelope_id'],
        where: 'envelope_id = ?',
        whereArgs: [envelopeId],
        limit: 1);
    if (live.isNotEmpty) return true;
    final tomb = await db.query('Tombstones_V2',
        columns: const ['envelope_id'],
        where: 'envelope_id = ?',
        whereArgs: [envelopeId],
        limit: 1);
    return tomb.isNotEmpty;
  }

  /// Stage 0c wave 3E — whether the envelope_id is already in the LIVE
  /// envelopes table (but NOT yet tombstoned). Used by EnvelopeDispatcherV2
  /// to surface `dedupe-hit` as an explicit DROP outcome (spec §7.5 #9)
  /// instead of letting tryStore silently return `StoreOutcome.duplicate`
  /// and accept-as-not-LWW-winner.
  Future<bool> isLiveEnvelopeId(Uint8List envelopeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'Envelopes_V2',
      columns: const ['envelope_id'],
      where: 'envelope_id = ? AND is_tombstoned = 0',
      whereArgs: [envelopeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Whether the envelope_id is in the tombstone table.
  Future<bool> isTombstoned(Uint8List envelopeId) async {
    final db = await _db.database;
    final tomb = await db.query('Tombstones_V2',
        columns: const ['envelope_id'],
        where: 'envelope_id = ?',
        whereArgs: [envelopeId],
        limit: 1);
    return tomb.isNotEmpty;
  }

  /// Look up the current LWW winner for a given (event_type, lww_key
  /// component) pair. Returns null when no winner is recorded yet.
  Future<Uint8List?> currentLwwWinner({
    required int eventType,
    required Uint8List lwwKeyComponent,
  }) async {
    final db = await _db.database;
    final hash = await _lwwKeyHash(eventType, lwwKeyComponent);
    final rows = await db.query(
      'Lww_Index_V2',
      columns: const ['winning_envelope_id'],
      where: 'lww_key_hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['winning_envelope_id'] as Uint8List;
  }

  // ────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────

  /// Update Lww_Index_V2 if [envelope] is the new latest for its LWW key.
  /// Returns true when this envelope became (or remained) the LWW winner.
  Future<bool> _maybeUpdateLwwIndex(EventEnvelopeV2 envelope) async {
    final lwwComponent = _lwwKeyComponentFor(envelope);
    if (lwwComponent == null) return false; // not LWW-tracked

    final db = await _db.database;
    final hash = await _lwwKeyHash(envelope.eventType, lwwComponent);
    final rows = await db.query('Lww_Index_V2',
        where: 'lww_key_hash = ?', whereArgs: [hash], limit: 1);
    final newer = rows.isEmpty ||
        _hlcGreaterThan(envelope.createdAtHlc.msSinceEpoch,
            envelope.createdAtHlc.counter,
            rows.first['winning_hlc_ms'] as int,
            rows.first['winning_hlc_ctr'] as int);
    if (!newer) return false;
    await db.insert(
      'Lww_Index_V2',
      {
        'lww_key_hash': hash,
        'event_type': envelope.eventType,
        'winning_envelope_id': envelope.envelopeId,
        'winning_hlc_ms': envelope.createdAtHlc.msSinceEpoch,
        'winning_hlc_ctr': envelope.createdAtHlc.counter,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  /// Per envelope_v2_spec §10.2, returns the LWW key component for an
  /// envelope, or null when this event_type is NOT LWW-tracked.
  ///
  /// Stage 0c wave 3E — payload-driven keys now use minimal payload decoders
  /// from event_envelope_v2.dart (ShelterStatusData / OfficialAlertCapData /
  /// OfficialAlertSummaryData / ProtocolNoticeData). When the payload key
  /// field is empty or the decode throws, we fall back to author_key so the
  /// row still ends up in some LWW bucket (correctness-preserving — narrows
  /// the LWW namespace per-author rather than per-shelter/cap/notice). The
  /// fallback also surfaces in trace logs because dispatcher records the
  /// envelope as accepted-not-LWW-winner when this returns a different key
  /// than the live winner.
  Uint8List? _lwwKeyComponentFor(EventEnvelopeV2 envelope) {
    switch (envelope.eventType) {
      case EventTypeV2.statusUpdate:
      case EventTypeV2.batteryStatus:
      case EventTypeV2.heartbeat:
        return envelope.authorKey; // (author_key, event_type)
      case EventTypeV2.shelterStatus:
        return _payloadKeyOrAuthorFallback(
          envelope: envelope,
          decode: ShelterStatusData.decode,
          extract: (d) => d.shelterId,
        );
      case EventTypeV2.officialAlertCap:
        return _payloadKeyOrAuthorFallback(
          envelope: envelope,
          decode: OfficialAlertCapData.decode,
          extract: (d) => d.capIdentifier,
        );
      case EventTypeV2.officialAlertSummary:
        return _payloadKeyOrAuthorFallback(
          envelope: envelope,
          decode: OfficialAlertSummaryData.decode,
          extract: (d) => d.capIdentifier,
        );
      case EventTypeV2.protocolNotice:
        return _payloadKeyOrAuthorFallback(
          envelope: envelope,
          decode: ProtocolNoticeData.decode,
          extract: (d) => d.noticeId,
        );
      default:
        return null;
    }
  }

  /// Decode the payload via [decode], extract the LWW key component via
  /// [extract], and return its UTF-8 bytes. On any decode error or empty
  /// string, fall back to `envelope.authorKey`.
  ///
  /// The fallback path is deliberately silent (no exception, no log) because
  /// the dispatcher has already accepted this envelope at signature-verify
  /// time; a malformed payload here is a UI surface concern, not a security
  /// boundary. If the QA wants to observe these fallbacks, the trace row
  /// emitted by the dispatcher carries enough context (`event_type`,
  /// `author_key` hash, `dedupe_outcome`) to flag them.
  Uint8List _payloadKeyOrAuthorFallback<T>({
    required EventEnvelopeV2 envelope,
    required T Function(Uint8List) decode,
    required String Function(T) extract,
  }) {
    try {
      final data = decode(envelope.payload);
      final id = extract(data);
      if (id.isEmpty) return envelope.authorKey;
      return Uint8List.fromList(utf8.encode(id));
    } catch (_) {
      return envelope.authorKey;
    }
  }

  /// SHA-256(<event_type:u32_le> || lwwKeyComponent) — spec §12.3.
  Future<Uint8List> _lwwKeyHash(int eventType, Uint8List component) async {
    final input = Uint8List(4 + component.length);
    final view = ByteData.sublistView(input);
    view.setUint32(0, eventType, Endian.little);
    input.setRange(4, 4 + component.length, component);
    final digest = await Sha256().hash(input);
    return Uint8List.fromList(digest.bytes);
  }

  bool _hlcGreaterThan(int newMs, int newCtr, int oldMs, int oldCtr) {
    if (newMs != oldMs) return newMs > oldMs;
    return newCtr > oldCtr;
  }

  /// Look up the source trust label for an author + event type (spec §6.2).
  /// `OFFICIAL_VERIFIED` is granted only when the author_key is in
  /// `Official_Sources_V2` AND the event_type is OFFICIAL_ALERT_*.
  Future<SourceTrust> resolveSourceTrust(Uint8List authorKey, int eventType) =>
      _resolveSourceTrust(authorKey, eventType);

  Future<SourceTrust> _resolveSourceTrust(Uint8List authorKey, int eventType) async {
    if (eventType == EventTypeV2.officialAlertCap ||
        eventType == EventTypeV2.officialAlertSummary) {
      final db = await _db.database;
      final rows = await db.query(
        'Official_Sources_V2',
        columns: const ['author_key'],
        where: 'author_key = ?',
        whereArgs: [authorKey],
        limit: 1,
      );
      if (rows.isNotEmpty) return SourceTrust.officialVerified;
    }
    return SourceTrust.unverified;
  }

  static int _sourceTrustToInt(SourceTrust t) {
    switch (t) {
      case SourceTrust.self:
        return 0;
      case SourceTrust.paired:
        return 1;
      case SourceTrust.seenBefore:
        return 2;
      case SourceTrust.unverified:
        return 3;
      case SourceTrust.officialVerified:
        return 4;
    }
  }
}

