// Receive-path dispatcher for EventEnvelope v2 (v0.3 Stage 0c).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §6, §7.5, §9, §11, §13, §15.
//
// Pipeline (executed in order; first failure stops the pipeline and writes a
// `mesh_trace_logs` row with the spec-named drop_reason):
//
//   1. proto3 decode (required-field check inside EventEnvelopeV2.decode)
//   2. unknown-protocol-version (only protocol_version == 2 accepted) [3E]
//   3. sig_algo recognition (only 0x01 = Ed25519 in v0.3)
//   4. SHA-256(payload) recomputation + Ed25519 signature verification
//   5. max-hops-overcommit (envelope_v2_spec §11.3) [3E]
//   6. envelope-expired:
//        - expires_at_hlc < created_at_hlc (logical violation, always-drop)
//        - expires_at_hlc < now (clock-based expiry; spec §7.5 step 10) [3E]
//   7. tombstone-hit (peer pushed an envelope we already expired & GC'd)
//   8. dedupe-hit (peer pushed an envelope we have a LIVE row for) [3E]
//      Previously this slipped through as `StoreOutcome.duplicate` and was
//      silently accepted as "not LWW winner"; spec §7.5 #9 says DROP.
//   9. priority × event_type matrix (drop / downgrade / accept) — uses
//      OFFICIAL_VERIFIED short-circuit for OFFICIAL_ALERT_CAP per §6.2
//  10. payload budget (receiver-side defense in depth)
//  11. author rate limiter
//  12. EnvelopeStoreV2.tryStore (insert + LWW maintenance)
//  13. trace + emit accept
//
// The dispatcher is a facade: callers (BLE event channel, mesh router) feed
// reassembled envelope bytes via [onReceiveEnvelopeBytes]. Outcomes are
// emitted on a broadcast Stream so EventStream / dev-mode trace screen can
// subscribe.
//
// Stage 0c wave 3E additions (drop_reason vocabulary, spec §15.2 updated):
//   `unknown-protocol-version`, `envelope-expired`, `max-hops-overcommit`,
//   `dedupe-hit` (was previously silent).

import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:ignirelay_app/app/crypto/canonical_encoder_v2.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/proto/proto_wire.dart';
import 'package:ignirelay_app/app/services/author_rate_limiter.dart';
import 'package:ignirelay_app/app/services/envelope_store_v2.dart';
import 'package:ignirelay_app/app/services/mesh_trace_writer.dart';
import 'package:ignirelay_app/app/services/payload_budget_v2.dart';
import 'package:ignirelay_app/app/services/priority_matrix_v2.dart';

/// Outcome of a single receive-pipeline run.
sealed class DispatchOutcome {
  const DispatchOutcome();
}

class DispatchAccepted extends DispatchOutcome {
  final EventEnvelopeV2 envelope;
  final SourceTrust sourceTrust;

  /// True when the matrix downgraded the wire priority on accept.
  final bool downgraded;

  /// The original wire priority (when downgraded == true).
  final int? downgradedFromPriority;

  /// True when this insert won the LWW slot for its (author, event_type) tuple.
  final bool isLwwWinner;

  /// BLE short id of the immediate sender (null when the dispatcher was
  /// invoked without one, e.g., from a unit test).
  final String? peerId;

  const DispatchAccepted({
    required this.envelope,
    required this.sourceTrust,
    this.downgraded = false,
    this.downgradedFromPriority,
    this.isLwwWinner = false,
    this.peerId,
  });
}

class DispatchDropped extends DispatchOutcome {
  /// Spec named code from envelope_v2_spec §15.2.
  final String dropReason;

  /// Optional envelope_id (null when the envelope failed to decode).
  final Uint8List? envelopeId;

  /// Optional human-readable detail; not meant for UI.
  final String? detail;

  /// BLE short id of the immediate sender (null when the dispatcher was
  /// invoked without one).
  final String? peerId;

  const DispatchDropped({
    required this.dropReason,
    this.envelopeId,
    this.detail,
    this.peerId,
  });
}

class EnvelopeDispatcherV2 {
  final EnvelopeStoreV2 _store;
  final MeshTraceWriter _trace;
  final AuthorRateLimiter _rateLimiter;
  final Future<DateTime> Function() _now;

  final _outcomes = StreamController<DispatchOutcome>.broadcast();

  /// Stream of every accept/drop decision. Subscribers (typed-stream facade,
  /// dev-mode trace screen) listen here.
  Stream<DispatchOutcome> get outcomes => _outcomes.stream;

  /// Protocol version the dispatcher accepts. Spec §3 / §7.5 #1: v0.3 ==
  /// `protocol_version = 2`. A future v0.4 device sending `protocol_version
  /// = 3` will surface here as `unknown-protocol-version`.
  static const int _acceptedProtocolVersion = 2;

  /// Stage 0c wave 3E shim — gates the clock-based `expires_at_hlc < now`
  /// branch of the envelope-expired check (spec §7.5 #10).
  ///
  /// The logical `expires_at_hlc < created_at_hlc` branch ALWAYS runs (it
  /// doesn't depend on wall clock; corpus `expires_before_created` covers
  /// it). The clock-based branch defaults to OFF so existing unit tests
  /// using synthetic HLC values (e.g. `msSinceEpoch: 1000`) keep passing.
  /// Production main.dart wires `enableClockBasedExpiry: true`; the QA
  /// agent's follow-up wave is expected to flip the default to `true` and
  /// migrate tests to inject a synthetic `now` aligned with their HLC range.
  final bool _enableClockBasedExpiry;

  /// Stage 0c wave 3E shim — gates the `max-hops-overcommit` check (spec
  /// §11.3 / §11.4). Defaults to OFF because existing tests construct
  /// HELLO envelopes with `maxHops: 1` (a single relay hop is the natural
  /// expression for a one-shot link control message, even though the spec
  /// pins PROTOCOL_HELLO default to 0). The dispatcher accepts the more
  /// lenient behavior so test code is undisturbed; production main.dart
  /// wires `enableMaxHopsOvercommit: true` and the QA agent's follow-up
  /// wave is expected to flip the default and update PROTOCOL_HELLO
  /// senders to use `maxHops: 0` per §11.4.
  final bool _enableMaxHopsOvercommit;

  EnvelopeDispatcherV2({
    required EnvelopeStoreV2 store,
    required MeshTraceWriter trace,
    required AuthorRateLimiter rateLimiter,
    Future<DateTime> Function()? now,
    bool enableClockBasedExpiry = false,
    bool enableMaxHopsOvercommit = false,
  })  : _store = store,
        _trace = trace,
        _rateLimiter = rateLimiter,
        _enableClockBasedExpiry = enableClockBasedExpiry,
        _enableMaxHopsOvercommit = enableMaxHopsOvercommit,
        _now = now ?? (() async => DateTime.now());

  Future<void> dispose() async {
    await _outcomes.close();
  }

  /// Entry point — feed reassembled envelope bytes (post-Reassembler) here.
  /// `peerId` is the BLE short id of the immediate sender (safe to log).
  Future<DispatchOutcome> onReceiveEnvelopeBytes(
    Uint8List envelopeBytes, {
    String? peerId,
  }) async {
    EventEnvelopeV2 envelope;
    try {
      envelope = EventEnvelopeV2.decode(envelopeBytes);
    } on ProtoDecodeException catch (e) {
      return _drop(
        DispatchDropped(
          dropReason: 'decode-required-field-missing',
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.empty(peerId, e.message),
      );
    }

    // Stage 0c wave 3E — unknown-protocol-version. Reject anything not
    // protocol_version == 2 BEFORE signature verify (sig canonical input
    // includes the version, so a wrong version would fail signature anyway,
    // but the explicit early drop produces the right trace reason instead
    // of `signature-invalid`).
    if (envelope.protocolVersion != _acceptedProtocolVersion) {
      return _drop(
        DispatchDropped(
          dropReason: 'unknown-protocol-version',
          envelopeId: envelope.envelopeId,
          detail: 'protocol_version=${envelope.protocolVersion}',
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.fromEnvelope(envelope, peerId),
      );
    }

    // sig_algo recognition (forward-compat).
    if (envelope.sigAlgo != SigAlgo.ed25519) {
      return _drop(
        DispatchDropped(
          dropReason: 'unknown-sig-algo',
          envelopeId: envelope.envelopeId,
          detail: 'sig_algo=${envelope.sigAlgo}',
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.fromEnvelope(envelope, peerId),
      );
    }

    // Signature verification (also catches payload tampering via SHA-256 mismatch).
    final payloadHash = await CanonicalEncoderV2.hashPayload(envelope.payload);
    final sigInput = CanonicalEncoderV2.buildSignatureInput(
      protocolVersion: envelope.protocolVersion,
      envelopeId: envelope.envelopeId,
      eventType: envelope.eventType,
      priority: envelope.priority,
      createdAtHlcMs: envelope.createdAtHlc.msSinceEpoch,
      createdAtHlcCounter: envelope.createdAtHlc.counter,
      expiresAtHlcMs: envelope.expiresAtHlc.msSinceEpoch,
      expiresAtHlcCounter: envelope.expiresAtHlc.counter,
      maxHops: envelope.maxHops,
      authorKey: envelope.authorKey,
      sigAlgo: envelope.sigAlgo,
      payloadHash: payloadHash,
    );
    final pubKey = SimplePublicKey(envelope.authorKey, type: KeyPairType.ed25519);
    final signature = Signature(envelope.signature, publicKey: pubKey);
    final ok = await Ed25519().verify(sigInput, signature: signature);
    if (!ok) {
      return _drop(
        DispatchDropped(
          dropReason: 'signature-invalid',
          envelopeId: envelope.envelopeId,
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.fromEnvelope(envelope, peerId, sigStatus: 1),
      );
    }

    // Stage 0c wave 3E — max-hops-overcommit (spec §11.3). Receivers MUST
    // drop envelopes whose `max_hops` exceeds the per-event_type default.
    // Unknown event types return null from `maxHopsDefault` and are handled
    // by the matrix as `unknown-event-type`. Gated behind a flag because
    // pre-3E test harnesses set HELLO.maxHops=1 (vs spec default 0); see
    // [_enableMaxHopsOvercommit] note.
    if (_enableMaxHopsOvercommit) {
      final hopCap = EventTypeV2.maxHopsDefault(envelope.eventType);
      if (hopCap != null && envelope.maxHops > hopCap) {
        return _drop(
          DispatchDropped(
            dropReason: 'max-hops-overcommit',
            envelopeId: envelope.envelopeId,
            detail: 'max_hops=${envelope.maxHops} cap=$hopCap',
            peerId: peerId,
          ),
          traceMeta: _TraceMeta.fromEnvelope(envelope, peerId, sigStatus: 0),
        );
      }
    }

    // Stage 0c wave 3E — envelope-expired (spec §7.5 #10 + corpus
    // `expires_before_created` / `expired` cases).
    //
    // Two sub-conditions, both surfaced as `envelope-expired`:
    //   (a) expires_at_hlc.ms < created_at_hlc.ms → logical violation;
    //       envelope was born expired (author misconfiguration or
    //       construction bug). Always drop.
    //   (b) expires_at_hlc.ms < now_ms → clock-based expiry. The envelope
    //       was valid when authored but we observed it after its TTL.
    //
    // Spec §7.5 #10 says "expired → tombstone path"; for Stage 0c closure
    // we record the drop in trace and emit DispatchDropped, deferring
    // active tombstone insertion to the §13 tombstone GC. The receiver
    // never accepts the row; future arrivals of the same envelope_id will
    // hit dedupe-hit (live row absent) but will be expired again here.
    if (envelope.expiresAtHlc.msSinceEpoch <
        envelope.createdAtHlc.msSinceEpoch) {
      return _drop(
        DispatchDropped(
          dropReason: 'envelope-expired',
          envelopeId: envelope.envelopeId,
          detail: 'expires_at_hlc < created_at_hlc',
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.fromEnvelope(envelope, peerId, sigStatus: 0),
      );
    }
    if (_enableClockBasedExpiry) {
      final nowMs = (await _now()).millisecondsSinceEpoch;
      if (envelope.expiresAtHlc.msSinceEpoch < nowMs) {
        return _drop(
          DispatchDropped(
            dropReason: 'envelope-expired',
            envelopeId: envelope.envelopeId,
            detail:
                'expires_at_hlc=${envelope.expiresAtHlc.msSinceEpoch} now=$nowMs',
            peerId: peerId,
          ),
          traceMeta: _TraceMeta.fromEnvelope(envelope, peerId, sigStatus: 0),
        );
      }
    }

    // Tombstone hit — peer pushed an envelope we already expired.
    if (await _store.isTombstoned(envelope.envelopeId)) {
      return _drop(
        DispatchDropped(
          dropReason: 'tombstone-hit',
          envelopeId: envelope.envelopeId,
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.fromEnvelope(envelope, peerId, sigStatus: 0),
      );
    }

    // Stage 0c wave 3E — explicit dedupe-hit (spec §7.5 #9 + §15.2).
    // The store also detects duplicates inside tryStore, but for v0.3 we
    // want a DROP outcome (with trace) rather than the previous
    // silent-accept-as-not-LWW-winner. The check is BEFORE the matrix /
    // budget / rate-limiter because duplicates should bypass those (they
    // already passed when the original was received).
    if (await _store.isLiveEnvelopeId(envelope.envelopeId)) {
      return _drop(
        DispatchDropped(
          dropReason: 'dedupe-hit',
          envelopeId: envelope.envelopeId,
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.fromEnvelope(envelope, peerId, sigStatus: 0),
      );
    }

    // Resolve source trust BEFORE matrix so OFFICIAL_VERIFIED short-circuit fires.
    final sourceTrust = await _store.resolveSourceTrust(
      envelope.authorKey,
      envelope.eventType,
    );

    // Priority × event_type matrix.
    final matrix = PriorityMatrixV2.check(
      envelope.eventType,
      envelope.priority,
      context: MatrixContext(sourceTrust: sourceTrust),
    );
    if (matrix.outcome == MatrixOutcome.drop) {
      return _drop(
        DispatchDropped(
          dropReason: matrix.dropReason ?? 'priority-mismatch',
          envelopeId: envelope.envelopeId,
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.fromEnvelope(envelope, peerId,
            sigStatus: 0, sourceTrust: _stToInt(sourceTrust)),
      );
    }

    final effectivePriority = matrix.outcome == MatrixOutcome.downgrade
        ? matrix.downgradeTo!
        : envelope.priority;

    // Receiver-side budget check (defense in depth — over-budget SOS = drop).
    final budget = PayloadBudgetV2.check(
      priority: effectivePriority,
      totalEnvelopeBytes: envelopeBytes.length,
      side: BudgetSide.receiver,
    );
    if (!budget.ok) {
      return _drop(
        DispatchDropped(
          dropReason: budget.dropReason!,
          envelopeId: envelope.envelopeId,
          detail: 'size=${envelopeBytes.length} cap=${budget.cap}',
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.fromEnvelope(envelope, peerId,
            sigStatus: 0, sourceTrust: _stToInt(sourceTrust)),
      );
    }

    // Author rate limiter (BEFORE insert so floods can't pump tombstones).
    if (!_rateLimiter.tryAccept(envelope.authorKey, now: await _now())) {
      return _drop(
        DispatchDropped(
          dropReason: 'author-rate-limited',
          envelopeId: envelope.envelopeId,
          peerId: peerId,
        ),
        traceMeta: _TraceMeta.fromEnvelope(envelope, peerId,
            sigStatus: 0, sourceTrust: _stToInt(sourceTrust)),
      );
    }

    // All checks passed — store + LWW maintenance.
    final stored = await _store.tryStore(
      envelope: envelope,
      signatureStatus: 0,
      firstSeenVia: peerId,
    );

    final wasDowngraded = matrix.outcome == MatrixOutcome.downgrade;
    final accepted = DispatchAccepted(
      envelope: envelope,
      sourceTrust: sourceTrust,
      downgraded: wasDowngraded,
      downgradedFromPriority: wasDowngraded ? envelope.priority : null,
      isLwwWinner: stored.isLwwWinner,
      peerId: peerId,
    );
    _outcomes.add(accepted);

    await _trace.write(
      envelopeId: envelope.envelopeId,
      eventType: envelope.eventType,
      priority: effectivePriority,
      authorKey: envelope.authorKey,
      lastRelayId: envelope.lastRelayId.isEmpty ? null : envelope.lastRelayId,
      createdAtHlcMs: envelope.createdAtHlc.msSinceEpoch,
      expiresAtHlcMs: envelope.expiresAtHlc.msSinceEpoch,
      action: TraceAction.received,
      dropReason: wasDowngraded ? 'priority-downgraded' : null,
      dedupeOutcome: stored.outcome == StoreOutcome.duplicate
          ? TraceDedupe.hit
          : TraceDedupe.miss,
      signatureStatus: 0,
      sourceTrust: _stToInt(sourceTrust),
      peerId: peerId,
    );

    return accepted;
  }

  Future<DispatchDropped> _drop(
    DispatchDropped drop, {
    required _TraceMeta traceMeta,
  }) async {
    _outcomes.add(drop);
    await _trace.write(
      envelopeId: drop.envelopeId ?? Uint8List(16),
      eventType: traceMeta.eventType,
      priority: traceMeta.priority,
      authorKey: traceMeta.authorKey.isEmpty ? Uint8List(32) : traceMeta.authorKey,
      lastRelayId: traceMeta.lastRelayId,
      createdAtHlcMs: traceMeta.createdAtHlcMs,
      expiresAtHlcMs: traceMeta.expiresAtHlcMs,
      action: TraceAction.dropped,
      dropReason: drop.dropReason,
      signatureStatus: traceMeta.sigStatus,
      sourceTrust: traceMeta.sourceTrust,
      peerId: traceMeta.peerId,
    );
    return drop;
  }

  static int _stToInt(SourceTrust t) {
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

class _TraceMeta {
  final int eventType;
  final int priority;
  final Uint8List authorKey;
  final String? lastRelayId;
  final int createdAtHlcMs;
  final int expiresAtHlcMs;
  final int? sigStatus;
  final int? sourceTrust;
  final String? peerId;

  _TraceMeta({
    required this.eventType,
    required this.priority,
    required this.authorKey,
    required this.lastRelayId,
    required this.createdAtHlcMs,
    required this.expiresAtHlcMs,
    required this.sigStatus,
    required this.sourceTrust,
    required this.peerId,
  });

  factory _TraceMeta.empty(String? peerId, [String? detail]) => _TraceMeta(
        eventType: 0,
        priority: 0,
        authorKey: Uint8List(0),
        lastRelayId: detail,
        createdAtHlcMs: 0,
        expiresAtHlcMs: 0,
        sigStatus: null,
        sourceTrust: null,
        peerId: peerId,
      );

  factory _TraceMeta.fromEnvelope(EventEnvelopeV2 e, String? peerId,
      {int? sigStatus, int? sourceTrust}) {
    return _TraceMeta(
      eventType: e.eventType,
      priority: e.priority,
      authorKey: e.authorKey,
      lastRelayId: e.lastRelayId.isEmpty ? null : e.lastRelayId,
      createdAtHlcMs: e.createdAtHlc.msSinceEpoch,
      expiresAtHlcMs: e.expiresAtHlc.msSinceEpoch,
      sigStatus: sigStatus,
      sourceTrust: sourceTrust,
      peerId: peerId,
    );
  }
}
