import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Canonical signature input for `EventEnvelope` v2.
///
/// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §8.2 (decisions §20.2 LE,
/// §20.6 SOS budget, §20.10 is_experimental on wire but unsigned).
///
/// The signature is computed over a deterministic byte sequence that is NOT
/// the protobuf serializer's output. This decouples signature stability from
/// proto3 quirks (field order, default omission, unknown fields, repeated
/// ordering). The result is a fixed 124-byte input for v2.
///
/// Layout:
/// ```
/// sig_input  = u32_le(protocol_version)              # 4
///            || u8(16) || envelope_id                 # 17
///            || u32_le(event_type)                    # 4
///            || u32_le(priority)                      # 4
///            || u64_le(created_at_hlc.ms)             # 8
///            || u32_le(created_at_hlc.counter)        # 4
///            || u64_le(expires_at_hlc.ms)             # 8
///            || u32_le(expires_at_hlc.counter)        # 4
///            || u32_le(max_hops)                      # 4
///            || u8(32) || author_key                  # 33
///            || u8(sig_algo)                          # 1
///            || u8(32) || SHA-256(payload)            # 33
/// total                                                # 124
/// ```
///
/// `payload_hash` is computed locally; it is NOT a wire field. Both sender and
/// receiver compute SHA-256(payload) on demand and feed it into this routine.
/// Any wire-level corruption of `payload` produces a different hash and the
/// envelope is dropped with `drop_reason = signature-invalid`.
class CanonicalEncoderV2 {
  static const int sigInputBytes = 124;

  static const int sigAlgoEd25519 = 0x01;

  /// Build the canonical signature input.
  ///
  /// `payloadHash` MUST be SHA-256(payload), 32 bytes. Use [hashPayload] to
  /// compute it. `envelopeId` MUST be 16 bytes; `authorKey` MUST be 32 bytes.
  static Uint8List buildSignatureInput({
    required int protocolVersion,
    required Uint8List envelopeId,
    required int eventType,
    required int priority,
    required int createdAtHlcMs,
    required int createdAtHlcCounter,
    required int expiresAtHlcMs,
    required int expiresAtHlcCounter,
    required int maxHops,
    required Uint8List authorKey,
    required int sigAlgo,
    required Uint8List payloadHash,
  }) {
    if (envelopeId.length != 16) {
      throw ArgumentError('envelope_id must be 16 bytes; got ${envelopeId.length}');
    }
    if (authorKey.length != 32) {
      throw ArgumentError('author_key must be 32 bytes; got ${authorKey.length}');
    }
    if (payloadHash.length != 32) {
      throw ArgumentError('payload_hash must be 32 bytes; got ${payloadHash.length}');
    }
    if (sigAlgo < 0 || sigAlgo > 0xFF) {
      throw ArgumentError('sig_algo must fit in u8; got $sigAlgo');
    }

    final out = Uint8List(sigInputBytes);
    var offset = 0;
    final view = ByteData.sublistView(out);

    view.setUint32(offset, protocolVersion, Endian.little);
    offset += 4;

    out[offset++] = 16;
    out.setRange(offset, offset + 16, envelopeId);
    offset += 16;

    view.setUint32(offset, eventType, Endian.little);
    offset += 4;

    view.setUint32(offset, priority, Endian.little);
    offset += 4;

    view.setUint64(offset, createdAtHlcMs, Endian.little);
    offset += 8;

    view.setUint32(offset, createdAtHlcCounter, Endian.little);
    offset += 4;

    view.setUint64(offset, expiresAtHlcMs, Endian.little);
    offset += 8;

    view.setUint32(offset, expiresAtHlcCounter, Endian.little);
    offset += 4;

    view.setUint32(offset, maxHops, Endian.little);
    offset += 4;

    out[offset++] = 32;
    out.setRange(offset, offset + 32, authorKey);
    offset += 32;

    out[offset++] = sigAlgo;

    out[offset++] = 32;
    out.setRange(offset, offset + 32, payloadHash);
    offset += 32;

    assert(offset == sigInputBytes,
        'canonical sig_input length drift: $offset vs $sigInputBytes');
    return out;
  }

  /// Compute SHA-256(payload). Both sender and receiver call this; the result
  /// is fed into [buildSignatureInput] but is never put on the wire.
  static Future<Uint8List> hashPayload(List<int> payload) async {
    final digest = await Sha256().hash(payload);
    return Uint8List.fromList(digest.bytes);
  }
}
