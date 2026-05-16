import 'dart:typed_data';

import 'mesh_constants.dart';

/// App-level chunk framing for v0.3 envelope transport.
///
/// Spec: docs/specs/native_transport_v1_2026-05-13.md §4 (decisions §15.1, §15.5).
///
/// Every envelope on the wire is wrapped in chunk framing (Option B in §4.5):
///
///   ┌────────────────┬─────────────┬─────────────┬─────────────────┐
///   │ envelope_id    │ chunk_index │ total_chunks│ chunk_payload   │
///   │ 16 bytes       │ 1 byte u8   │ 1 byte u8   │ remaining bytes │
///   └────────────────┴─────────────┴─────────────┴─────────────────┘
///
/// Header size is fixed at 18 bytes (`kChunkHeaderSize`). At MTU=247 a single
/// chunk carries `247 - 3 (ATT) - 18 = 226 bytes` of envelope. A 240-byte SOS
/// envelope therefore takes 2 chunks at MTU=247 and MTU=185, and 1 chunk at
/// MTU=512.
class Chunker {
  /// Split a serialized envelope into MTU-sized chunks for the negotiated MTU.
  ///
  /// Throws [ChunkingError] when the envelope is too large, the MTU is too low,
  /// or the resulting chunk count would exceed [kMaxChunksPerEnvelope].
  /// `envelopeId` MUST be exactly 16 bytes.
  static List<Uint8List> split({
    required Uint8List envelopeId,
    required Uint8List envelopeBytes,
    required int mtu,
  }) {
    if (envelopeId.length != 16) {
      throw ChunkingError.invalidEnvelopeId(
          'envelope_id must be 16 bytes; got ${envelopeId.length}');
    }
    if (envelopeBytes.length > kMaxEnvelopeBytes) {
      throw ChunkingError.overMaxEnvelopeBytes(
          'envelope ${envelopeBytes.length} B exceeds MAX_ENVELOPE_BYTES=$kMaxEnvelopeBytes');
    }
    final chunkPayloadSize = mtu - kAttHeaderSize - kChunkHeaderSize;
    if (chunkPayloadSize < 1) {
      throw ChunkingError.mtuBelowMinimum(
          'mtu=$mtu leaves $chunkPayloadSize B for chunk payload');
    }
    final total = (envelopeBytes.length + chunkPayloadSize - 1) ~/ chunkPayloadSize;
    if (total < 1) {
      // Empty envelope — still emit one chunk so receiver path is uniform.
      return [
        _frame(envelopeId, 0, 1, Uint8List(0)),
      ];
    }
    if (total > kMaxChunksPerEnvelope) {
      throw ChunkingError.overMaxChunks(
          'envelope needs $total chunks at chunk_payload=$chunkPayloadSize; cap=$kMaxChunksPerEnvelope');
    }
    final chunks = <Uint8List>[];
    for (var i = 0; i < total; i++) {
      final start = i * chunkPayloadSize;
      final end = (start + chunkPayloadSize).clamp(0, envelopeBytes.length);
      final slice = Uint8List.sublistView(envelopeBytes, start, end);
      chunks.add(_frame(envelopeId, i, total, slice));
    }
    return chunks;
  }

  static Uint8List _frame(
    Uint8List envelopeId,
    int chunkIndex,
    int totalChunks,
    Uint8List chunkPayload,
  ) {
    assert(envelopeId.length == 16);
    assert(chunkIndex >= 0 && chunkIndex < 256);
    assert(totalChunks >= 1 && totalChunks < 256);
    final out = Uint8List(kChunkHeaderSize + chunkPayload.length);
    out.setRange(0, 16, envelopeId);
    out[16] = chunkIndex;
    out[17] = totalChunks;
    out.setRange(18, 18 + chunkPayload.length, chunkPayload);
    return out;
  }
}

/// Errors raised by [Chunker.split]. Each maps to a documented `drop_reason`
/// from the spec / mesh_trace_logs `drop_reason` enum.
enum ChunkingErrorKind {
  overMaxEnvelopeBytes, // "over-max-envelope-bytes"
  overMaxChunks,        // "over-max-chunks"
  mtuBelowMinimum,      // "mtu-below-minimum-for-chunked"
  invalidEnvelopeId,    // local programmer error
}

class ChunkingError implements Exception {
  final ChunkingErrorKind kind;
  final String message;

  ChunkingError._(this.kind, this.message);

  factory ChunkingError.overMaxEnvelopeBytes(String m) =>
      ChunkingError._(ChunkingErrorKind.overMaxEnvelopeBytes, m);

  factory ChunkingError.overMaxChunks(String m) =>
      ChunkingError._(ChunkingErrorKind.overMaxChunks, m);

  factory ChunkingError.mtuBelowMinimum(String m) =>
      ChunkingError._(ChunkingErrorKind.mtuBelowMinimum, m);

  factory ChunkingError.invalidEnvelopeId(String m) =>
      ChunkingError._(ChunkingErrorKind.invalidEnvelopeId, m);

  /// drop_reason string for `mesh_trace_logs.drop_reason` (envelope_v2_spec §15.2).
  String get dropReason {
    switch (kind) {
      case ChunkingErrorKind.overMaxEnvelopeBytes:
        return 'over-max-envelope-bytes';
      case ChunkingErrorKind.overMaxChunks:
        return 'over-max-chunks';
      case ChunkingErrorKind.mtuBelowMinimum:
        return 'mtu-below-minimum-for-chunked';
      case ChunkingErrorKind.invalidEnvelopeId:
        return 'invalid-envelope-id';
    }
  }

  @override
  String toString() => 'ChunkingError($dropReason): $message';
}
