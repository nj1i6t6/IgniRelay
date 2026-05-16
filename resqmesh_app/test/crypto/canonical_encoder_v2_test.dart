// v0.3 Stage 0c1 — unit tests for the canonical signature input encoder.
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §8.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/crypto/canonical_encoder_v2.dart';

void main() {
  group('CanonicalEncoderV2.buildSignatureInput', () {
    final envelopeId = Uint8List.fromList(List.generate(16, (i) => i));
    final authorKey = Uint8List.fromList(List.generate(32, (i) => 0x80 | i));
    final payloadHash = Uint8List.fromList(List.generate(32, (i) => 0xAA));

    test('output is exactly 124 bytes (locked length §8.2)', () {
      final out = CanonicalEncoderV2.buildSignatureInput(
        protocolVersion: 2,
        envelopeId: envelopeId,
        eventType: 1,
        priority: 1,
        createdAtHlcMs: 1,
        createdAtHlcCounter: 0,
        expiresAtHlcMs: 1,
        expiresAtHlcCounter: 0,
        maxHops: 6,
        authorKey: authorKey,
        sigAlgo: CanonicalEncoderV2.sigAlgoEd25519,
        payloadHash: payloadHash,
      );
      expect(out.length, CanonicalEncoderV2.sigInputBytes);
      expect(out.length, 124);
    });

    test('layout matches spec §8.2 byte-by-byte', () {
      final out = CanonicalEncoderV2.buildSignatureInput(
        protocolVersion: 0x01020304,
        envelopeId: envelopeId,
        eventType: 0x05060708,
        priority: 0x090A0B0C,
        createdAtHlcMs: 0x1112131415161718,
        createdAtHlcCounter: 0x191A1B1C,
        expiresAtHlcMs: 0x2122232425262728,
        expiresAtHlcCounter: 0x292A2B2C,
        maxHops: 0x31323334,
        authorKey: authorKey,
        sigAlgo: 0x01,
        payloadHash: payloadHash,
      );
      // protocol_version u32_le
      expect(out.sublist(0, 4), [0x04, 0x03, 0x02, 0x01]);
      // length-prefixed envelope_id
      expect(out[4], 16);
      expect(out.sublist(5, 21), envelopeId);
      // event_type u32_le
      expect(out.sublist(21, 25), [0x08, 0x07, 0x06, 0x05]);
      // priority u32_le
      expect(out.sublist(25, 29), [0x0C, 0x0B, 0x0A, 0x09]);
      // created_at_hlc.ms u64_le
      expect(out.sublist(29, 37),
          [0x18, 0x17, 0x16, 0x15, 0x14, 0x13, 0x12, 0x11]);
      // created_at_hlc.counter u32_le
      expect(out.sublist(37, 41), [0x1C, 0x1B, 0x1A, 0x19]);
      // expires_at_hlc.ms u64_le
      expect(out.sublist(41, 49),
          [0x28, 0x27, 0x26, 0x25, 0x24, 0x23, 0x22, 0x21]);
      // expires_at_hlc.counter u32_le
      expect(out.sublist(49, 53), [0x2C, 0x2B, 0x2A, 0x29]);
      // max_hops u32_le
      expect(out.sublist(53, 57), [0x34, 0x33, 0x32, 0x31]);
      // length-prefixed author_key
      expect(out[57], 32);
      expect(out.sublist(58, 90), authorKey);
      // sig_algo u8
      expect(out[90], 0x01);
      // length-prefixed payload_hash
      expect(out[91], 32);
      expect(out.sublist(92, 124), payloadHash);
    });

    test('rejects bad envelope_id length', () {
      expect(
        () => CanonicalEncoderV2.buildSignatureInput(
          protocolVersion: 2,
          envelopeId: Uint8List(15),
          eventType: 1,
          priority: 1,
          createdAtHlcMs: 0,
          createdAtHlcCounter: 0,
          expiresAtHlcMs: 0,
          expiresAtHlcCounter: 0,
          maxHops: 1,
          authorKey: authorKey,
          sigAlgo: 1,
          payloadHash: payloadHash,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects bad payload_hash length', () {
      expect(
        () => CanonicalEncoderV2.buildSignatureInput(
          protocolVersion: 2,
          envelopeId: envelopeId,
          eventType: 1,
          priority: 1,
          createdAtHlcMs: 0,
          createdAtHlcCounter: 0,
          expiresAtHlcMs: 0,
          expiresAtHlcCounter: 0,
          maxHops: 1,
          authorKey: authorKey,
          sigAlgo: 1,
          payloadHash: Uint8List(31),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('hashPayload matches reference SHA-256', () async {
      // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      final empty = await CanonicalEncoderV2.hashPayload(const <int>[]);
      final emptyHex = empty
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(emptyHex,
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });
  });
}
