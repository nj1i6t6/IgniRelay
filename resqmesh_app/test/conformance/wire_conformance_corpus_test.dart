// v0.3 Stage 0c wave 3D — wire conformance corpus consumer test.
//
// Pins the committed `docs/specs/wire_conformance_v1.json` against:
//   1. Spec count thresholds (envelope ≥100 / IBLT ≥50 / Bloom ≥30 /
//      chunking ≥20 / negative ≥10).
//   2. Determinism — buildCorpus() output is byte-identical to disk.
//      This is the gate against silent wire drift: anyone changing
//      IBLT/Chunker/CanonicalEncoderV2/Bloom semantics MUST regenerate
//      the corpus and commit, otherwise this test fails.
//   3. Metadata shape — corpus_revision, spec_date, notes, no live
//      timestamp.
//   4. Envelope signature verification — every signed sample verifies
//      via live Ed25519. Catches algorithm drift in CanonicalEncoderV2.
//   5. Bloom ASCII-only constraint — Kotlin/Swift bloomMurmurHash diverge
//      on non-ASCII; corpus must never emit non-ASCII Bloom event IDs.
//   6. Negative-case shape + drop-reason vocabulary + live Chunker
//      reproduction of the structural Chunker negatives.
//
// If this test fails after a change to lib/app/{mesh,crypto}/, the live
// code drifted from the committed corpus. Regenerate via:
//
//     dart run tool/generate_wire_conformance_v1.dart
//
// ...then re-run this test, then run the iOS/Android consumer tests
// (Swift: ios/RunnerTests/WireConformanceTests.swift, NOT yet wired into
// Android instrumentation in 3D).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/chunker.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';

import '../../tool/generate_wire_conformance_v1.dart' as gen;

const String _corpusPath = '../docs/specs/wire_conformance_v1.json';

void main() {
  late Map<String, dynamic> corpus;
  late String corpusOnDisk;

  setUpAll(() {
    final file = File(_corpusPath);
    expect(file.existsSync(), isTrue,
        reason: 'corpus missing at $_corpusPath — '
            'run `dart run tool/generate_wire_conformance_v1.dart`');
    corpusOnDisk = file.readAsStringSync();
    corpus = jsonDecode(corpusOnDisk) as Map<String, dynamic>;
  });

  group('wire conformance corpus v1 — metadata', () {
    test('has corpus_revision + spec_date and NO generated_at_iso', () {
      expect(corpus['corpus_revision'], 'v0.3-stage0c-wave3d-1');
      expect(corpus['spec_date'], '2026-05-13');
      expect(corpus.containsKey('generated_at_iso'), isFalse,
          reason: 'corpus must be deterministic; no live timestamp allowed');
    });

    test('notes section documents corpus conventions', () {
      final notes = corpus['notes'] as Map<String, dynamic>;
      expect(notes['bloom_hash_ascii_only'], isA<String>());
      expect(notes['payload_generator_lcg_byte_pattern_v1'], isA<String>());
      expect(notes['event_id_generator_ascii_seq_v1'], isA<String>());
      expect(notes['iblt_peel_quirk'], isA<String>());
    });

    test('spec references point at the committed spec files', () {
      expect(corpus['spec_envelope'], 'docs/specs/envelope_v2_spec_2026-05-13.md');
      expect(corpus['spec_transport'], 'docs/specs/native_transport_v1_2026-05-13.md');
      expect(File('../${corpus['spec_envelope']}').existsSync(), isTrue);
      expect(File('../${corpus['spec_transport']}').existsSync(), isTrue);
    });
  });

  group('wire conformance corpus v1 — count thresholds (spec §11.7)', () {
    test('envelope_samples >= 100', () {
      expect((corpus['envelope_samples'] as List).length,
          greaterThanOrEqualTo(100));
    });
    test('chunking_samples >= 20', () {
      expect((corpus['chunking_samples'] as List).length,
          greaterThanOrEqualTo(20));
    });
    test('iblt_samples >= 50', () {
      expect((corpus['iblt_samples'] as List).length,
          greaterThanOrEqualTo(50));
    });
    test('bloom_samples >= 30', () {
      expect((corpus['bloom_samples'] as List).length,
          greaterThanOrEqualTo(30));
    });
    test('negative_cases >= 10', () {
      expect((corpus['negative_cases'] as List).length,
          greaterThanOrEqualTo(10));
    });
  });

  group('wire conformance corpus v1 — determinism gate', () {
    test('buildCorpus() output is byte-identical to committed JSON', () async {
      final rebuilt = await gen.buildCorpus();
      final rebuiltJson = const JsonEncoder.withIndent('  ').convert(rebuilt);
      expect(rebuiltJson, corpusOnDisk,
          reason: 'corpus drift detected. '
              'Re-run: dart run tool/generate_wire_conformance_v1.dart. '
              'If the live IBLT / Bloom / Chunker / CanonicalEncoderV2 '
              'changed semantics, the corpus MUST be regenerated and '
              'committed alongside the code change.');
    });
  });

  group('wire conformance corpus v1 — envelope signature verification', () {
    test('every signed envelope sample verifies via live Ed25519', () async {
      final samples =
          (corpus['envelope_samples'] as List).cast<Map<String, dynamic>>();
      var verified = 0;
      var unsigned = 0;
      for (final s in samples) {
        if (!s.containsKey('expected_signature_hex')) {
          unsigned++;
          continue;
        }
        final sigInput =
            _hexDecode(s['expected_canonical_sig_input_hex'] as String);
        final sigBytes = _hexDecode(s['expected_signature_hex'] as String);
        final pubKey = _hexDecode(s['derived_author_key_hex'] as String);

        final ed = Ed25519();
        final publicKey =
            SimplePublicKey(pubKey, type: KeyPairType.ed25519);
        final ok = await ed.verify(
          sigInput,
          signature: Signature(sigBytes, publicKey: publicKey),
        );
        expect(ok, isTrue,
            reason: 'signature verify failed for "${s['name']}"');
        verified++;
      }
      expect(verified, greaterThan(0),
          reason: 'corpus has no signed samples to verify');
      // Sanity: most corpus envelopes are unsigned (procedural, sig-input
      // only), some are signed. Both populations must be non-empty.
      expect(unsigned, greaterThan(0));
    });

    test('canonical sig input length is always 124 bytes', () {
      final samples =
          (corpus['envelope_samples'] as List).cast<Map<String, dynamic>>();
      for (final s in samples) {
        expect(s['expected_canonical_sig_input_bytes'], 124,
            reason: 'sample "${s['name']}" has non-124-byte sig input');
        expect(
          (s['expected_canonical_sig_input_hex'] as String).length,
          124 * 2,
          reason: 'sample "${s['name']}" sig input hex length mismatch',
        );
      }
    });
  });

  group('wire conformance corpus v1 — bloom ASCII-only constraint', () {
    test('every Bloom sample asserts ascii_only and uses ASCII prefix', () {
      final samples =
          (corpus['bloom_samples'] as List).cast<Map<String, dynamic>>();
      for (final s in samples) {
        expect(s['ascii_only'], isTrue,
            reason: 'bloom sample "${s['name']}" missing ascii_only=true');
        final genCfg = s['event_ids_generator'] as Map<String, dynamic>;
        expect(genCfg['algorithm'], 'ascii_seq_v1');
        final prefix = genCfg['prefix'] as String;
        for (final c in prefix.codeUnits) {
          expect(c, lessThanOrEqualTo(0x7F),
              reason: 'bloom prefix "$prefix" is not ASCII');
        }
        // ascii_seq_v1 zero-pads decimal digits — guaranteed ASCII by spec.
        expect(genCfg['width'], isA<int>());
        expect(genCfg['count'], isA<int>());
      }
    });

    test('Bloom samples carry sha256 + size, not raw bytes', () {
      final samples =
          (corpus['bloom_samples'] as List).cast<Map<String, dynamic>>();
      for (final s in samples) {
        expect(s['expected_bytes_size'], 2052,
            reason: 'bloom v2 byte length must be 4(magic) + 2048');
        expect(s['expected_bytes_sha256_hex'], isA<String>());
        expect((s['expected_bytes_sha256_hex'] as String).length, 64);
        // Defensive: no raw bytes in corpus (size discipline).
        expect(s.containsKey('expected_bytes_hex'), isFalse,
            reason: 'bloom corpus must use sha256 not raw hex to stay lean');
      }
    });
  });

  group('wire conformance corpus v1 — chunking sample shape', () {
    test('every chunking sample uses generator + sha256 (no raw chunks)', () {
      final samples =
          (corpus['chunking_samples'] as List).cast<Map<String, dynamic>>();
      for (final s in samples) {
        expect(s['envelope_bytes_generator'], isA<Map<String, dynamic>>());
        expect(s['expected_chunk_count'], isA<int>());
        expect(s['expected_first_chunk_sha256_hex'], isA<String>());
        expect(s['expected_last_chunk_sha256_hex'], isA<String>());
        expect(s.containsKey('expected_chunk_bytes_hex_array'), isFalse,
            reason: 'chunking corpus must use sha256 not raw chunk arrays');
      }
    });
  });

  group('wire conformance corpus v1 — IBLT sample shape', () {
    test('every IBLT sample byte hex is 504 chars (252B) or 1008 chars (504B hex)', () {
      // 56 buckets × 9 bytes = 504 bytes = 1008 hex chars.
      final samples =
          (corpus['iblt_samples'] as List).cast<Map<String, dynamic>>();
      for (final s in samples) {
        if (s['kind'] == 'iblt') {
          expect((s['expected_bytes_hex'] as String).length, 1008,
              reason: 'IBLT sample "${s['name']}" has wrong byte length');
        } else if (s['kind'] == 'iblt_subtract') {
          expect((s['expected_a_bytes_hex'] as String).length, 1008);
          expect((s['expected_b_bytes_hex'] as String).length, 1008);
          expect((s['expected_diff_bytes_hex'] as String).length, 1008);
        } else {
          fail('unknown IBLT sample kind: ${s['kind']}');
        }
      }
    });
  });

  group('wire conformance corpus v1 — negative cases', () {
    test('every negative case has kind + description + expected_drop_reason',
        () {
      final cases =
          (corpus['negative_cases'] as List).cast<Map<String, dynamic>>();
      for (final c in cases) {
        expect(c['kind'], isA<String>());
        expect(c['description'], isA<String>());
        expect(c['expected_drop_reason'], isA<String>());
      }
    });

    test('drop_reason vocabulary is spec-recognized', () {
      const knownReasons = <String>{
        'over-budget-sos-rejected',
        'over-max-envelope-bytes',
        'unknown-sig-algo',
        'chunk-bad-header',
        'invalid-envelope-id',
        'mtu-below-minimum-for-chunked',
        'over-max-chunks',
        'unknown-protocol-version',
        'envelope-expired',
        'reassembly-envelope-id-mismatch',
      };
      final cases =
          (corpus['negative_cases'] as List).cast<Map<String, dynamic>>();
      for (final c in cases) {
        expect(knownReasons, contains(c['expected_drop_reason']),
            reason: 'unrecognized drop reason in $c — '
                'either spec the new reason here or fix the corpus');
      }
    });

    // ── Live-code reproduction of structural Chunker negatives.
    // The other negatives (sig_algo, protocol_version, HLC ordering,
    // reassembly mismatch) are decoder / dispatcher responsibilities, not
    // covered by Chunker; their live-code coverage lives in the dispatcher
    // / decoder test suites.

    test('invalid-envelope-id: Chunker rejects 15-byte envelope_id', () {
      expect(
        () => Chunker.split(
          envelopeId: Uint8List(15),
          envelopeBytes: Uint8List(100),
          mtu: 247,
        ),
        throwsA(predicate(
            (e) => e is ChunkingError && e.dropReason == 'invalid-envelope-id')),
      );
    });

    test('mtu-below-minimum-for-chunked: Chunker rejects mtu = ATT+HEADER', () {
      expect(
        () => Chunker.split(
          envelopeId: Uint8List(16),
          envelopeBytes: Uint8List(100),
          mtu: kAttHeaderSize + kChunkHeaderSize,
        ),
        throwsA(predicate((e) =>
            e is ChunkingError &&
            e.dropReason == 'mtu-below-minimum-for-chunked')),
      );
    });

    test('over-max-envelope-bytes: Chunker rejects > MAX_ENVELOPE_BYTES', () {
      expect(
        () => Chunker.split(
          envelopeId: Uint8List(16),
          envelopeBytes: Uint8List(kMaxEnvelopeBytes + 1),
          mtu: 247,
        ),
        throwsA(predicate((e) =>
            e is ChunkingError && e.dropReason == 'over-max-envelope-bytes')),
      );
    });

    test('over-max-chunks: Chunker rejects when chunk count > cap', () {
      final cases =
          (corpus['negative_cases'] as List).cast<Map<String, dynamic>>();
      final overMaxChunksCase = cases.firstWhere(
        (c) => c['kind'] == 'over_max_chunks',
        orElse: () => throw StateError(
            'missing negative case kind=over_max_chunks in corpus'),
      );
      final mtu = overMaxChunksCase['mtu'];
      final envelopeBytesHexLength =
          overMaxChunksCase['envelope_bytes_hex_length'];
      final expectedDropReason = overMaxChunksCase['expected_drop_reason'];

      expect(mtu, isA<int>(), reason: 'over_max_chunks.mtu must be int');
      expect(
        envelopeBytesHexLength,
        isA<int>(),
        reason: 'over_max_chunks.envelope_bytes_hex_length must be int',
      );
      expect(
        expectedDropReason,
        isA<String>(),
        reason: 'over_max_chunks.expected_drop_reason must be string',
      );

      expect(
        () => Chunker.split(
          envelopeId: Uint8List(16),
          envelopeBytes: Uint8List(envelopeBytesHexLength as int),
          mtu: mtu as int,
        ),
        throwsA(predicate((e) =>
            e is ChunkingError && e.dropReason == expectedDropReason)),
      );
    });
  });
}

Uint8List _hexDecode(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  if (clean.length.isOdd) {
    throw FormatException('odd hex length: $hex');
  }
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
