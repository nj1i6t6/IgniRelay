// Sender-side publisher facade for EventEnvelope v2 (v0.3 Stage 0c).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §3, §6.3, §7, §8, §9.3
//   + docs/specs/native_transport_v1_2026-05-13.md §4.
//
// `MessagePublisherV2.send(...)` runs the full publish pipeline:
//
//   1. Caller-supplied `priority` is checked against the §6 matrix; the matrix
//      may DOWNGRADE it. UPGRADE/drop is not allowed at publish time — the
//      author must pick a legal priority before calling.
//   2. Build EventEnvelopeV2 (with UUIDv7 envelope_id if not supplied).
//   3. Compute SHA-256(payload) → canonical signature input → sign.
//   4. proto3 wire-encode the full envelope.
//   5. Payload-budget validate (sender-side) — REJECT on over-budget.
//   6. Chunker.split into MTU-sized chunks.
//   7. Trace `action = SENT` to mesh_trace_logs.
//
// The publisher does NOT manage the transport itself — it returns the framed
// chunk list. The integration site (BLE manager) chooses peers + invokes notify.

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:ignirelay_app/app/crypto/canonical_encoder_v2.dart';
import 'package:ignirelay_app/app/mesh/chunker.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/mesh_trace_writer.dart';
import 'package:ignirelay_app/app/services/payload_budget_v2.dart';
import 'package:ignirelay_app/app/services/priority_matrix_v2.dart';

/// Result of a successful publish.
class PublishedEnvelope {
  final EventEnvelopeV2 envelope;
  final Uint8List wireBytes;
  final List<Uint8List> chunks;
  final int negotiatedMtu;

  /// Effective priority after matrix downgrade (signed into the envelope).
  final int effectivePriority;

  const PublishedEnvelope({
    required this.envelope,
    required this.wireBytes,
    required this.chunks,
    required this.negotiatedMtu,
    required this.effectivePriority,
  });
}

class PublishRejected implements Exception {
  /// Spec named `drop_reason` from envelope_v2_spec §15.2.
  final String dropReason;
  final String detail;

  PublishRejected(this.dropReason, this.detail);

  @override
  String toString() => 'PublishRejected($dropReason): $detail';
}

class MessagePublisherV2 {
  /// Caller-supplied signing key (Ed25519 SimpleKeyPair). Injected so this
  /// facade does not depend on IdentityManager — keeps it test-friendly.
  final SimpleKeyPair _keyPair;
  final Uint8List _authorPublicKey;
  final MeshTraceWriter _trace;
  final Uint8List Function() _newEnvelopeId;

  MessagePublisherV2({
    required SimpleKeyPair keyPair,
    required Uint8List authorPublicKey,
    required MeshTraceWriter trace,
    Uint8List Function()? envelopeIdFactory,
  })  : _keyPair = keyPair,
        _authorPublicKey = authorPublicKey,
        _trace = trace,
        _newEnvelopeId = envelopeIdFactory ?? _newUuidV7;

  /// Build, sign, validate, and chunk an envelope. Throws [PublishRejected]
  /// for any sender-side spec violation; returns [PublishedEnvelope] on
  /// success. The caller hands `result.chunks` to the BLE notify path.
  Future<PublishedEnvelope> send({
    required int eventType,
    required int priority,
    required Uint8List payload,
    required HlcTimestampV2 createdAtHlc,
    required HlcTimestampV2 expiresAtHlc,
    required int maxHops,
    required int negotiatedMtu,
    Uint8List? envelopeId,
    bool isExperimental = false,
  }) async {
    if (eventType == EventTypeV2.unspecified) {
      throw PublishRejected('priority-mismatch', 'event_type=UNSPECIFIED');
    }
    if (priority == PriorityV2.unspecified) {
      throw PublishRejected('priority-mismatch', 'priority=UNSPECIFIED');
    }

    final matrix = PriorityMatrixV2.check(eventType, priority);
    if (matrix.outcome == MatrixOutcome.drop) {
      throw PublishRejected(
        matrix.dropReason ?? 'priority-mismatch',
        'event_type=$eventType priority=$priority not allowed by §6 matrix',
      );
    }
    final effectivePriority = matrix.outcome == MatrixOutcome.downgrade
        ? matrix.downgradeTo!
        : priority;

    final id = envelopeId ?? _newEnvelopeId();
    if (id.length != 16) {
      throw PublishRejected('invalid-envelope-id', 'envelope_id must be 16 bytes');
    }

    // Compute signature over the FINAL field set the wire will carry.
    final payloadHash = await CanonicalEncoderV2.hashPayload(payload);
    final sigInput = CanonicalEncoderV2.buildSignatureInput(
      protocolVersion: 2,
      envelopeId: id,
      eventType: eventType,
      priority: effectivePriority,
      createdAtHlcMs: createdAtHlc.msSinceEpoch,
      createdAtHlcCounter: createdAtHlc.counter,
      expiresAtHlcMs: expiresAtHlc.msSinceEpoch,
      expiresAtHlcCounter: expiresAtHlc.counter,
      maxHops: maxHops,
      authorKey: _authorPublicKey,
      sigAlgo: SigAlgo.ed25519,
      payloadHash: payloadHash,
    );
    final sig = await Ed25519().sign(sigInput, keyPair: _keyPair);
    final signature = Uint8List.fromList(sig.bytes);

    final envelope = EventEnvelopeV2(
      protocolVersion: 2,
      envelopeId: id,
      eventType: eventType,
      priority: effectivePriority,
      createdAtHlc: createdAtHlc,
      expiresAtHlc: expiresAtHlc,
      maxHops: maxHops,
      authorKey: _authorPublicKey,
      sigAlgo: SigAlgo.ed25519,
      signature: signature,
      payload: payload,
      lastRelayId: '',
      isExperimental: isExperimental,
    );
    final wireBytes = envelope.encode();

    final budget = PayloadBudgetV2.check(
      priority: effectivePriority,
      totalEnvelopeBytes: wireBytes.length,
      side: BudgetSide.sender,
    );
    if (!budget.ok) {
      throw PublishRejected(
        budget.dropReason!,
        'serialized=${wireBytes.length} cap=${budget.cap}',
      );
    }

    List<Uint8List> chunks;
    try {
      chunks = Chunker.split(
        envelopeId: id,
        envelopeBytes: wireBytes,
        mtu: negotiatedMtu,
      );
    } on ChunkingError catch (e) {
      throw PublishRejected(e.dropReason, e.message);
    }

    await _trace.write(
      envelopeId: id,
      eventType: eventType,
      priority: effectivePriority,
      authorKey: _authorPublicKey,
      lastRelayId: null,
      createdAtHlcMs: createdAtHlc.msSinceEpoch,
      expiresAtHlcMs: expiresAtHlc.msSinceEpoch,
      action: TraceAction.sent,
    );

    return PublishedEnvelope(
      envelope: envelope,
      wireBytes: wireBytes,
      chunks: chunks,
      negotiatedMtu: negotiatedMtu,
      effectivePriority: effectivePriority,
    );
  }

  /// UUIDv7 envelope_id factory exposed for pre-allocation paths (e.g.,
  /// `EventPublisherV2Facade` Outbox_V2 persistence — wave 3F-r3). When the
  /// caller pre-allocates so a restart-driven re-send emits the SAME id the
  /// first attempt did, receiver-side dedup on `Envelopes_V2.envelope_id`
  /// PK / `Tombstones_V2` stays idempotent.
  static Uint8List newEnvelopeId() => _newUuidV7();

  /// UUIDv7 generator — RFC 9562 §5.7 layout (48-bit unix_ts_ms || version 7
  /// nibble || 12-bit rand_a || variant 10b || 62-bit rand_b). Self-contained
  /// (uses only dart:math). Spec-locked decision §20.3.
  static Uint8List _newUuidV7() {
    final out = Uint8List(16);
    final rng = Random.secure();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    out[0] = (nowMs >> 40) & 0xFF;
    out[1] = (nowMs >> 32) & 0xFF;
    out[2] = (nowMs >> 24) & 0xFF;
    out[3] = (nowMs >> 16) & 0xFF;
    out[4] = (nowMs >> 8) & 0xFF;
    out[5] = nowMs & 0xFF;
    final randA = rng.nextInt(0x10000);
    out[6] = 0x70 | ((randA >> 8) & 0x0F);
    out[7] = randA & 0xFF;
    final randHigh = rng.nextInt(0x10000);
    out[8] = 0x80 | ((randHigh >> 8) & 0x3F);
    out[9] = randHigh & 0xFF;
    final randMid = rng.nextInt(0x10000);
    out[10] = (randMid >> 8) & 0xFF;
    out[11] = randMid & 0xFF;
    final randLow = rng.nextInt(0x100000000);
    out[12] = (randLow >> 24) & 0xFF;
    out[13] = (randLow >> 16) & 0xFF;
    out[14] = (randLow >> 8) & 0xFF;
    out[15] = randLow & 0xFF;
    return out;
  }
}
