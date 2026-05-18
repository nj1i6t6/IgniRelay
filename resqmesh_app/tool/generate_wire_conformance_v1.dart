// Cross-platform wire conformance corpus generator (v0.3 Stage 0c wave 3D).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §17.5
//   + docs/specs/native_transport_v1_2026-05-13.md §11.7.
//
// Per spec, this Dart script is the SOLE source of truth for new test
// vectors. Kotlin and Swift implementations CONSUME the JSON and MUST NOT
// regenerate it. Inputs:
//
//   - test/wire_conformance/scenarios/*.yaml   (hand-authored seed cases)
//   - procedural matrix below                  (deterministic from seeds)
//
// Output:
//
//   ../docs/specs/wire_conformance_v1.json     (byte-deterministic)
//
// Output is DETERMINISTIC: same input -> byte-identical JSON. There is
// no `generated_at_iso` field; corpus revision is tracked via
// `corpus_revision`. The conformance test suite calls [buildCorpus] and
// compares against the committed JSON to enforce.
//
// Usage:
//   dart run tool/generate_wire_conformance_v1.dart           # write to disk
//   dart run tool/generate_wire_conformance_v1.dart --check   # exit 2 on drift
//
// Exit codes:
//   0 — corpus regenerated, output written (or --check passed)
//   1 — input scenario malformed
//   2 — output unwritable / --check detected drift

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:cryptography/cryptography.dart';
import 'package:ignirelay_app/app/crypto/canonical_encoder_v2.dart';
import 'package:ignirelay_app/app/mesh/chunker.dart';
import 'package:ignirelay_app/app/mesh/iblt.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const String _scenariosDir = 'test/wire_conformance/scenarios';
const String _outputPath = '../docs/specs/wire_conformance_v1.json';
const String _corpusRevision = 'v0.3-stage0c-wave3d-1';
const String _specDate = '2026-05-13';

// Anchor for HLC timestamps in procedural samples (matches existing YAML
// scenarios so adjacent envelopes look coherent). 2026-05-15 13:00:00 UTC.
const int _baseHlcMs = 1747350000000;

// Hand-authored YAML scenarios pin the all-zero private key
// '00...00' inline in their `test_signing.private_key_hex` field; procedural
// signed samples derive deterministic per-case seeds via
// _proceduralPrivKeySeed. There is intentionally no shared Dart constant.

// ─────────────────────────────────────────────────────────────────────────────
// main()
// ─────────────────────────────────────────────────────────────────────────────

Future<int> main(List<String> args) async {
  final checkMode = args.contains('--check');

  late Map<String, dynamic> corpus;
  try {
    corpus = await buildCorpus();
  } on FormatException catch (e) {
    stderr.writeln('generate_wire_conformance_v1: $e');
    return 1;
  }
  final encoded = const JsonEncoder.withIndent('  ').convert(corpus);

  final outFile = File(_outputPath);

  if (checkMode) {
    if (!outFile.existsSync()) {
      stderr.writeln('generate_wire_conformance_v1: --check failed; '
          'corpus file missing at ${outFile.path}');
      return 2;
    }
    final onDisk = outFile.readAsStringSync();
    if (onDisk != encoded) {
      stderr.writeln('generate_wire_conformance_v1: --check failed; '
          'regenerated corpus differs from disk. '
          'Run without --check to update, then re-run tests.');
      return 2;
    }
    stdout.writeln('generate_wire_conformance_v1: --check OK '
        '(corpus is deterministic + up to date)');
    return 0;
  }

  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(encoded);

  stdout.writeln('generate_wire_conformance_v1: wrote ${outFile.path}');
  stdout.writeln('  envelope_samples=${(corpus['envelope_samples'] as List).length}');
  stdout.writeln('  chunking_samples=${(corpus['chunking_samples'] as List).length}');
  stdout.writeln('  iblt_samples=${(corpus['iblt_samples'] as List).length}');
  stdout.writeln('  bloom_samples=${(corpus['bloom_samples'] as List).length}');
  stdout.writeln('  negative_cases=${(corpus['negative_cases'] as List).length}');
  return 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// buildCorpus()
//
// Pure function. No file writes. Called by main() (which writes the result
// to disk) and by test/conformance/wire_conformance_corpus_test.dart (which
// compares against the committed JSON to enforce determinism).
// ─────────────────────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> buildCorpus() async {
  final scenariosDir = Directory(_scenariosDir);
  if (!scenariosDir.existsSync()) {
    throw FormatException('scenarios dir missing: ${scenariosDir.path}');
  }

  final corpus = <String, dynamic>{
    'corpus_revision': _corpusRevision,
    'spec_date': _specDate,
    'spec_envelope': 'docs/specs/envelope_v2_spec_2026-05-13.md',
    'spec_transport': 'docs/specs/native_transport_v1_2026-05-13.md',
    'notes': <String, dynamic>{
      'bloom_hash_ascii_only':
          'Bloom vectors intentionally use ASCII event IDs only. Kotlin and '
              'Swift Bloom MurmurHash currently diverge on non-ASCII code units '
              '(Kotlin: c.code unmasked; Swift: codeUnit & 0xFF). v0.3 envelope '
              'IDs are UUIDv7 ASCII so this is not runtime-impacting. The '
              'generator asserts every Bloom event_id is ASCII before emitting; '
              'the Dart inline Bloom builder follows Kotlin (oracle).',
      'payload_generator_lcg_byte_pattern_v1':
          'Deterministic byte generator. state := seed (uint32); for i in '
              '[0, size): state := (state * 1664525 + 1013904223) mod 2^32; '
              'out[i] := state & 0xFF. Used to avoid bloating the corpus with '
              'large raw payload_hex blobs. Cross-platform consumers MUST '
              'reproduce identical bytes given the same (seed, size).',
      'event_id_generator_ascii_seq_v1':
          'Deterministic ASCII event ID generator. for i in [start, start+count): '
              'yield prefix + decimal(i) zero-padded to width digits. '
              'Example {prefix:"evt-", start:0, count:2, width:8} -> '
              '["evt-00000000", "evt-00000001"]. Bloom and IBLT samples use '
              'this so the corpus does not store hundreds of full ID strings.',
      'iblt_peel_quirk':
          'Dart/Kotlin/Swift IBLT.peel uses CRC-derived index lookup while '
              'insert/remove use MurmurHash-derived indices. The two spaces are '
              'not equivalent, so peel succeeds only on inputs that happen to '
              'align. Pre-existing quirk; NOT covered by this corpus. The wire '
              'contract that matters is toBytes()/subtract(), which IS covered.',
    },
    'envelope_samples': <Map<String, dynamic>>[],
    'chunking_samples': <Map<String, dynamic>>[],
    'iblt_samples': <Map<String, dynamic>>[],
    'bloom_samples': <Map<String, dynamic>>[],
    'negative_cases': <Map<String, dynamic>>[],
  };

  // 1) Hand-authored YAML scenarios (sorted by filename for determinism).
  final yamlFiles = scenariosDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in yamlFiles) {
    final scenario = _parseScenario(f.readAsStringSync());
    final result = await _buildEnvelopeSampleFromYaml(scenario);
    (corpus['envelope_samples'] as List).add(result);
  }

  // 2) Procedural envelope samples — top up to >= 100 total.
  final proceduralEnvelopes = await _buildProceduralEnvelopeSamples();
  (corpus['envelope_samples'] as List).addAll(proceduralEnvelopes);

  // 3) Chunking samples — MTU × envelope-size matrix.
  (corpus['chunking_samples'] as List).addAll(_buildChunkingSamples());

  // 4) IBLT samples.
  (corpus['iblt_samples'] as List).addAll(_buildIbltSamples());

  // 5) Bloom samples (uses inline Dart Bloom v2 builder + ASCII assertion).
  (corpus['bloom_samples'] as List).addAll(_buildBloomSamples());

  // 6) Negative cases.
  (corpus['negative_cases'] as List).addAll(_buildNegativeCases());

  return corpus;
}

// ─────────────────────────────────────────────────────────────────────────────
// Procedural envelope samples
//
// 100 cases total split across:
//   - 30  per-type × per-priority sweep (broad coverage)
//   - 18  SOS boundary @ priorities 1, 2 × sizes near 240B
//   - 10  ALERT chunking-required @ priority 3
//   - 12  NORMAL multi-chunk @ priorities 4, 5, 6
//   - 30  Ed25519-signed cases with deterministic per-case private keys
// ─────────────────────────────────────────────────────────────────────────────

const List<int> _eventTypes = [1, 10, 11, 12, 20, 30, 40, 50, 60, 70, 80, 90];
const List<int> _priorities = [1, 2, 3, 4, 5, 6];

Future<List<Map<String, dynamic>>> _buildProceduralEnvelopeSamples() async {
  final out = <Map<String, dynamic>>[];

  // ── Group A: 30 type×priority matrix
  for (var i = 0; i < 30; i++) {
    final eventType = _eventTypes[i % _eventTypes.length];
    final priority = _priorities[i % _priorities.length];
    final payloadSize = 16 + ((i * 7) % 64); // 16..79 B
    out.add(await _emitProceduralEnvelope(
      caseSeed: 1000 + i,
      name: 'matrix_${eventType}_${priority}_${payloadSize}_$i',
      eventType: eventType,
      priority: priority,
      payloadSize: payloadSize,
      withSignature: false,
    ));
  }

  // ── Group B: 18 SOS boundary @ priorities 1, 2
  const sosBoundarySizes = [50, 100, 150, 180, 200, 220, 230, 235, 240];
  for (final priority in [1, 2]) {
    for (final size in sosBoundarySizes) {
      out.add(await _emitProceduralEnvelope(
        caseSeed: 2000 + out.length,
        name: 'sos_boundary_p${priority}_${size}B',
        eventType: 1, // STATUS_UPDATE
        priority: priority,
        payloadSize: size,
        withSignature: false,
      ));
    }
  }

  // ── Group C: 10 ALERT chunking-required @ priority 3
  const alertSizes = [250, 300, 400, 500, 600, 700, 800, 1000, 1200, 1500];
  for (final size in alertSizes) {
    out.add(await _emitProceduralEnvelope(
      caseSeed: 3000 + out.length,
      name: 'alert_chunk_${size}B',
      eventType: 80, // OFFICIAL_ALERT_CAP
      priority: 3,
      payloadSize: size,
      withSignature: false,
    ));
  }

  // ── Group D: 12 NORMAL multi-chunk
  const normalSizes = [1024, 1500, 1800, 2000];
  for (final priority in [4, 5, 6]) {
    for (final size in normalSizes) {
      out.add(await _emitProceduralEnvelope(
        caseSeed: 4000 + out.length,
        name: 'normal_chunk_p${priority}_${size}B',
        eventType: 30, // CHAT_MESSAGE
        priority: priority,
        payloadSize: size,
        withSignature: false,
      ));
    }
  }

  // ── Group E: 30 signed cases
  for (var i = 0; i < 30; i++) {
    final eventType = _eventTypes[i % _eventTypes.length];
    final priority = _priorities[i % _priorities.length];
    final payloadSize = 20 + ((i * 11) % 80); // 20..99 B
    out.add(await _emitProceduralEnvelope(
      caseSeed: 5000 + i,
      name: 'signed_${eventType}_${priority}_$i',
      eventType: eventType,
      priority: priority,
      payloadSize: payloadSize,
      withSignature: true,
    ));
  }

  return out;
}

Future<Map<String, dynamic>> _emitProceduralEnvelope({
  required int caseSeed,
  required String name,
  required int eventType,
  required int priority,
  required int payloadSize,
  required bool withSignature,
}) async {
  final envelopeId = _proceduralEnvelopeId(caseSeed);
  final createdMs = _baseHlcMs + caseSeed * 1000;
  final expiresMs = createdMs + 86400 * 1000; // +24h
  final maxHops = 6 + (caseSeed % 4); // 6..9
  final payload = _lcgPayload(seed: caseSeed, size: payloadSize);
  final payloadHash = await CanonicalEncoderV2.hashPayload(payload);
  final payloadSha256 = _hex(crypto_pkg.sha256.convert(payload).bytes);

  // Author key: signed cases derive from private key; unsigned cases use a
  // deterministic 32-byte pattern.
  Uint8List authorKey;
  Uint8List? signature;
  String? privKeyHex;

  if (withSignature) {
    final privSeed = _proceduralPrivKeySeed(caseSeed);
    privKeyHex = _hex(privSeed);
    final ed = Ed25519();
    final keyPair = await ed.newKeyPairFromSeed(privSeed);
    final pubBytes = await keyPair.extractPublicKey().then((p) => p.bytes);
    authorKey = Uint8List.fromList(pubBytes);
  } else {
    authorKey = Uint8List.fromList(
      List.generate(32, (i) => ((caseSeed + i) * 31) & 0xFF),
    );
  }

  final sigInput = CanonicalEncoderV2.buildSignatureInput(
    protocolVersion: kProtocolVersionV2,
    envelopeId: envelopeId,
    eventType: eventType,
    priority: priority,
    createdAtHlcMs: createdMs,
    createdAtHlcCounter: 0,
    expiresAtHlcMs: expiresMs,
    expiresAtHlcCounter: 0,
    maxHops: maxHops,
    authorKey: authorKey,
    sigAlgo: 1,
    payloadHash: payloadHash,
  );

  if (withSignature) {
    final ed = Ed25519();
    final keyPair = await ed.newKeyPairFromSeed(_proceduralPrivKeySeed(caseSeed));
    final sig = await ed.sign(sigInput, keyPair: keyPair);
    signature = Uint8List.fromList(sig.bytes);
  }

  // Decide whether to inline payload_hex or use payload_generator.
  // Threshold: 64 bytes. Smaller payloads are eyeball-friendly; larger
  // ones blow up the JSON unnecessarily.
  final envelopeStruct = <String, dynamic>{
    'protocol_version': kProtocolVersionV2,
    'envelope_id_hex': _hex(envelopeId),
    'event_type': eventType,
    'priority': priority,
    'created_at_hlc': {'ms_since_epoch': createdMs, 'counter': 0},
    'expires_at_hlc': {'ms_since_epoch': expiresMs, 'counter': 0},
    'max_hops': maxHops,
    'author_key_hex': _hex(authorKey),
    'sig_algo': 1,
    'is_experimental': false,
  };
  if (payloadSize <= 64) {
    envelopeStruct['payload_hex'] = _hex(payload);
  } else {
    envelopeStruct['payload_generator'] = {
      'algorithm': 'lcg_byte_pattern_v1',
      'seed': caseSeed,
      'size': payloadSize,
    };
  }

  final sample = <String, dynamic>{
    'kind': 'envelope',
    'name': name,
    'description': 'Procedural envelope sample (case_seed=$caseSeed).',
    'envelope_struct': envelopeStruct,
    'payload_sha256_hex': payloadSha256,
    'expected_canonical_sig_input_hex': _hex(sigInput),
    'expected_canonical_sig_input_bytes': sigInput.length,
  };
  if (signature != null) {
    sample['expected_signature_hex'] = _hex(signature);
    sample['derived_author_key_hex'] = _hex(authorKey);
    sample['test_only_private_key_hex'] = privKeyHex;
  }
  return sample;
}

Uint8List _proceduralEnvelopeId(int caseSeed) {
  // UUIDv7-shape: bytes 0..5 = fixed timestamp prefix, bytes 6..15 derived
  // from caseSeed for uniqueness. Keeps procedural IDs visually distinct
  // from YAML-authored ones.
  final out = Uint8List(16);
  const prefix = [0x01, 0x90, 0x00, 0x00, 0x00, 0x00];
  for (var i = 0; i < prefix.length; i++) {
    out[i] = prefix[i];
  }
  for (var i = 6; i < 16; i++) {
    out[i] = ((caseSeed + i * 17) * 31) & 0xFF;
  }
  // Set UUIDv7 version nibble (high nibble of byte 6 = 7) to mimic real IDs.
  out[6] = (out[6] & 0x0F) | 0x70;
  // Set variant nibble (high two bits of byte 8 = 10).
  out[8] = (out[8] & 0x3F) | 0x80;
  return out;
}

Uint8List _proceduralPrivKeySeed(int caseSeed) {
  // Deterministic 32-byte private-key seed. Diverse enough that 30 signed
  // cases yield 30 distinct author keys.
  final out = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    out[i] = ((caseSeed * 1009) + (i * 257)) & 0xFF;
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Chunking matrix — 20 cases
// ─────────────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _buildChunkingSamples() {
  final out = <Map<String, dynamic>>[];

  // MTU × envelope-size boundary matrix. Selected sizes hit the chunk-payload
  // boundaries for each MTU: at MTU=M, single chunk holds (M - 3 - 18) = (M-21)
  // bytes; multi-chunk crosses at M-21 + 1.
  final cases = <List<int>>[
    // [mtu, size]
    [185, 1], [185, 100], [185, 163], [185, 164], [185, 165], [185, 240],
    [247, 1], [247, 100], [247, 225], [247, 226], [247, 227], [247, 500],
    [320, 200], [320, 599],
    [400, 300], [400, 1500],
    [512, 1], [512, 491], [512, 1000], [512, 2048],
  ];

  for (var i = 0; i < cases.length; i++) {
    final mtu = cases[i][0];
    final size = cases[i][1];
    final envelopeBytes = _lcgPayload(seed: 7000 + i, size: size);
    final id = _proceduralEnvelopeId(8000 + i);
    final chunks = Chunker.split(
      envelopeId: id,
      envelopeBytes: envelopeBytes,
      mtu: mtu,
    );
    final firstSha = _hex(crypto_pkg.sha256.convert(chunks.first).bytes);
    final lastSha = _hex(crypto_pkg.sha256.convert(chunks.last).bytes);
    out.add({
      'kind': 'chunking',
      'name': 'mtu${mtu}_size$size',
      'envelope_bytes_generator': {
        'algorithm': 'lcg_byte_pattern_v1',
        'seed': 7000 + i,
        'size': size,
      },
      'envelope_id_hex': _hex(id),
      'negotiated_mtu': mtu,
      'expected_chunk_count': chunks.length,
      'expected_first_chunk_sha256_hex': firstSha,
      'expected_last_chunk_sha256_hex': lastSha,
      'expected_first_chunk_bytes': chunks.first.length,
      'expected_last_chunk_bytes': chunks.last.length,
    });
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// IBLT samples — 52 cases
// ─────────────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _buildIbltSamples() {
  final out = <Map<String, dynamic>>[];

  // ── Insert-only series, n = 1..30 (30 cases)
  for (var n = 1; n <= 30; n++) {
    final ids = _asciiSeqIds(prefix: 'iblt-ins-', start: 0, count: n, width: 8);
    final iblt = IBLT();
    for (final id in ids) {
      iblt.insert(id);
    }
    out.add({
      'kind': 'iblt',
      'name': 'insert_only_$n',
      'operations': [
        {
          'op': 'insert',
          'event_ids_generator': {
            'algorithm': 'ascii_seq_v1',
            'prefix': 'iblt-ins-',
            'start': 0,
            'count': n,
            'width': 8,
          },
        },
      ],
      'expected_bytes_hex': _hex(iblt.toBytes()),
    });
  }

  // ── Insert-then-remove series, n = 1..10 (10 cases)
  for (var n = 1; n <= 10; n++) {
    final insertCount = n * 2;
    final removeCount = n;
    final insertIds = _asciiSeqIds(
        prefix: 'iblt-rm-', start: 0, count: insertCount, width: 8);
    final removeIds = _asciiSeqIds(
        prefix: 'iblt-rm-', start: 0, count: removeCount, width: 8);
    final iblt = IBLT();
    for (final id in insertIds) {
      iblt.insert(id);
    }
    for (final id in removeIds) {
      iblt.remove(id);
    }
    out.add({
      'kind': 'iblt',
      'name': 'insert_remove_$n',
      'operations': [
        {
          'op': 'insert',
          'event_ids_generator': {
            'algorithm': 'ascii_seq_v1',
            'prefix': 'iblt-rm-',
            'start': 0,
            'count': insertCount,
            'width': 8,
          },
        },
        {
          'op': 'remove',
          'event_ids_generator': {
            'algorithm': 'ascii_seq_v1',
            'prefix': 'iblt-rm-',
            'start': 0,
            'count': removeCount,
            'width': 8,
          },
        },
      ],
      'expected_bytes_hex': _hex(iblt.toBytes()),
    });
  }

  // ── Subtract series, A vs B with k differences (10 cases, k = 1..10)
  for (var k = 1; k <= 10; k++) {
    // A: shared (10 ids) + a_only (k ids)
    // B: shared (10 ids) + b_only (k ids)
    final shared = _asciiSeqIds(prefix: 'iblt-sub-sh-', start: 0, count: 10, width: 8);
    final aOnly = _asciiSeqIds(prefix: 'iblt-sub-a-', start: 0, count: k, width: 8);
    final bOnly = _asciiSeqIds(prefix: 'iblt-sub-b-', start: 0, count: k, width: 8);
    final a = IBLT();
    final b = IBLT();
    for (final id in shared) {
      a.insert(id);
      b.insert(id);
    }
    for (final id in aOnly) {
      a.insert(id);
    }
    for (final id in bOnly) {
      b.insert(id);
    }
    final diff = a.subtract(b);
    out.add({
      'kind': 'iblt_subtract',
      'name': 'subtract_k$k',
      'a_operations': [
        {'op': 'insert', 'event_ids_generator': {
          'algorithm': 'ascii_seq_v1', 'prefix': 'iblt-sub-sh-', 'start': 0, 'count': 10, 'width': 8,
        }},
        {'op': 'insert', 'event_ids_generator': {
          'algorithm': 'ascii_seq_v1', 'prefix': 'iblt-sub-a-', 'start': 0, 'count': k, 'width': 8,
        }},
      ],
      'b_operations': [
        {'op': 'insert', 'event_ids_generator': {
          'algorithm': 'ascii_seq_v1', 'prefix': 'iblt-sub-sh-', 'start': 0, 'count': 10, 'width': 8,
        }},
        {'op': 'insert', 'event_ids_generator': {
          'algorithm': 'ascii_seq_v1', 'prefix': 'iblt-sub-b-', 'start': 0, 'count': k, 'width': 8,
        }},
      ],
      'expected_a_bytes_hex': _hex(a.toBytes()),
      'expected_b_bytes_hex': _hex(b.toBytes()),
      'expected_diff_bytes_hex': _hex(diff.toBytes()),
    });
  }

  // ── 2 boundary cases: empty, fill_100
  {
    final iblt = IBLT();
    out.add({
      'kind': 'iblt',
      'name': 'empty',
      'operations': const <Map<String, dynamic>>[],
      'expected_bytes_hex': _hex(iblt.toBytes()),
    });
  }
  {
    final ids = _asciiSeqIds(prefix: 'iblt-fill-', start: 0, count: 100, width: 8);
    final iblt = IBLT();
    for (final id in ids) {
      iblt.insert(id);
    }
    out.add({
      'kind': 'iblt',
      'name': 'fill_100',
      'operations': [
        {
          'op': 'insert',
          'event_ids_generator': {
            'algorithm': 'ascii_seq_v1', 'prefix': 'iblt-fill-', 'start': 0, 'count': 100, 'width': 8,
          },
        },
      ],
      'expected_bytes_hex': _hex(iblt.toBytes()),
    });
  }

  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bloom samples — 30 cases
//
// Inline Dart Bloom v2 builder mirrors Kotlin (oracle). ASCII-only event IDs
// enforced by the generator (asserted below); see notes.bloom_hash_ascii_only
// in the corpus metadata for why.
// ─────────────────────────────────────────────────────────────────────────────

const int _bloomSizeBytes = 2048;
const int _bloomHashCount = 7;
const List<int> _bloomMagic = [0xFF, 0xBF, 0x02, 0x00];

List<Map<String, dynamic>> _buildBloomSamples() {
  final out = <Map<String, dynamic>>[];

  const sizes = [1, 5, 10, 20, 50, 100, 200, 500, 1000, 2000];
  const seeds = ['bloom-a-', 'bloom-b-', 'bloom-c-'];

  for (final prefix in seeds) {
    for (final size in sizes) {
      final ids = _asciiSeqIds(prefix: prefix, start: 0, count: size, width: 8);
      for (final id in ids) {
        if (!_isAscii(id)) {
          throw FormatException(
            'Bloom event_id MUST be ASCII (see notes.bloom_hash_ascii_only); '
            'got "$id". Generator refuses to emit.',
          );
        }
      }
      final bytes = _buildBloomV2(ids);
      final sha = _hex(crypto_pkg.sha256.convert(bytes).bytes);
      out.add({
        'kind': 'bloom_v2',
        'name': 'bloom_${prefix.replaceAll('-', '_')}n$size',
        'event_ids_generator': {
          'algorithm': 'ascii_seq_v1',
          'prefix': prefix,
          'start': 0,
          'count': size,
          'width': 8,
        },
        'ascii_only': true,
        'expected_bytes_size': bytes.length,
        'expected_bytes_sha256_hex': sha,
      });
    }
  }
  return out;
}

/// Inline Dart Bloom v2 builder. Mirrors
/// IgniRelayForegroundService.buildBitVectorBloom (Kotlin) — uses unmasked
/// `c.code` for the MurmurHash byte stream. Swift's bloomMurmurHash uses
/// `codeUnit & 0xFF`; for ASCII the two are equivalent.
Uint8List _buildBloomV2(List<String> eventIds) {
  final out = Uint8List(_bloomSizeBytes + 4);
  out[0] = _bloomMagic[0];
  out[1] = _bloomMagic[1];
  out[2] = _bloomMagic[2];
  out[3] = _bloomMagic[3];
  const totalBits = _bloomSizeBytes * 8;
  for (final id in eventIds) {
    for (var seed = 0; seed < _bloomHashCount; seed++) {
      final h = _bloomMurmurHash(id, seed);
      // Kotlin: (hash.toLong() and 0xFFFFFFFFL) % totalBits
      final hUnsigned = h & 0xFFFFFFFF;
      final idx = hUnsigned % totalBits;
      out[4 + (idx >> 3)] |= (1 << (idx & 7)) & 0xFF;
    }
  }
  return out;
}

/// Equivalent to Kotlin IgniRelayForegroundService.murmurHash. NOTE: unlike
/// Swift's bloomMurmurHash, this does NOT mask code units to a byte (Kotlin
/// uses `c.code` directly). For ASCII inputs (the only inputs corpus emits
/// for Bloom), the two are identical bit-for-bit.
int _bloomMurmurHash(String s, int seed) {
  int h = seed;
  for (final c in s.codeUnits) {
    int k = c;
    k = (k * 0xcc9e2d51) & 0xFFFFFFFF;
    k = (((k << 15) & 0xFFFFFFFF) | (k >>> 17)) & 0xFFFFFFFF;
    k = (k * 0x1b873593) & 0xFFFFFFFF;
    h ^= k;
    h = (((h << 13) & 0xFFFFFFFF) | (h >>> 19)) & 0xFFFFFFFF;
    h = ((h * 5 + 0xe6546b64) & 0xFFFFFFFF);
  }
  h ^= s.length;
  h ^= (h >>> 16);
  h = (h * 0x85ebca6b) & 0xFFFFFFFF;
  h ^= (h >>> 13);
  h = (h * 0xc2b2ae35) & 0xFFFFFFFF;
  h ^= (h >>> 16);
  return h & 0xFFFFFFFF;
}

bool _isAscii(String s) {
  for (final c in s.codeUnits) {
    if (c > 0x7F) return false;
  }
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Negative cases — 11 cases
// ─────────────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _buildNegativeCases() {
  return <Map<String, dynamic>>[
    {
      'kind': 'oversize_sos',
      'description': 'SOS envelope > 240B — sender REJECTS at publish time.',
      'envelope_bytes_hex_length': kSosEnvelopeBudgetBytes + 1,
      'expected_drop_reason': 'over-budget-sos-rejected',
    },
    {
      'kind': 'oversize_envelope',
      'description': 'Envelope > MAX_ENVELOPE_BYTES — Chunker REJECTS.',
      'envelope_bytes_hex_length': kMaxEnvelopeBytes + 1,
      'expected_drop_reason': 'over-max-envelope-bytes',
    },
    {
      'kind': 'unknown_sig_algo',
      'description': 'sig_algo = 0x02 (post-quantum slot, not implemented in v0.3).',
      'sig_algo': 2,
      'expected_drop_reason': 'unknown-sig-algo',
    },
    {
      'kind': 'chunk_total_zero',
      'description': 'Chunk header with total_chunks=0 is illegal.',
      'expected_drop_reason': 'chunk-bad-header',
    },
    {
      'kind': 'chunk_index_oob',
      'description': 'Chunk header with chunk_index >= total_chunks is illegal.',
      'expected_drop_reason': 'chunk-bad-header',
    },
    {
      'kind': 'chunk_bad_envelope_id_length',
      'description': 'envelope_id != 16 bytes — Chunker REJECTS at split.',
      'envelope_id_bytes': 15,
      'expected_drop_reason': 'invalid-envelope-id',
    },
    {
      'kind': 'mtu_below_minimum',
      'description': 'MTU so low that chunk_payload < 1 byte — Chunker REJECTS.',
      'mtu': kAttHeaderSize + kChunkHeaderSize, // exactly leaves 0 payload
      'expected_drop_reason': 'mtu-below-minimum-for-chunked',
    },
    {
      'kind': 'over_max_chunks',
      'description': 'Envelope at MAX_ENVELOPE_BYTES (2048) with low MTU '
          'forces > MAX_CHUNKS_PER_ENVELOPE (16) chunks — Chunker REJECTS.',
      'envelope_bytes_hex_length': kMaxEnvelopeBytes,
      // mtu derivation: chunk_payload = mtu - ATT(3) - HEADER(18).
      // To force > 16 chunks at envelope=2048: chunk_payload must be < 128
      // (ceil(2048/128) = 16 hits the cap exactly). Pick chunk_payload=100
      // → 21 chunks → mtu = 100 + 3 + 18 = 121.
      // NOTE: a common-but-wrong intuition is mtu=185 (low Android baseline).
      // At mtu=185 chunk_payload=164 → only 13 chunks (UNDER the 16 cap),
      // so the Chunker would NOT throw. Conformance test reads this `mtu`
      // dynamically and asserts Chunker.split throws over-max-chunks.
      'mtu': 121,
      'expected_drop_reason': 'over-max-chunks',
    },
    {
      'kind': 'unknown_protocol_version',
      'description': 'protocol_version != 2 — decoder REJECTS the envelope.',
      'protocol_version': 99,
      'expected_drop_reason': 'unknown-protocol-version',
    },
    {
      'kind': 'expires_before_created',
      'description':
          'expires_at_hlc < created_at_hlc — envelope already expired at publish.',
      'created_at_hlc_ms': _baseHlcMs + 10000,
      'expires_at_hlc_ms': _baseHlcMs + 5000,
      'expected_drop_reason': 'envelope-expired',
    },
    {
      'kind': 'invalid_envelope_id_in_chunk',
      'description':
          'Reassembler receives chunks with mismatched envelope_id prefixes — '
          'dropped as drift.',
      'expected_drop_reason': 'reassembly-envelope-id-mismatch',
    },
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Deterministic input generators (cross-platform contract)
// ─────────────────────────────────────────────────────────────────────────────

/// LCG-byte payload generator. See notes.payload_generator_lcg_byte_pattern_v1
/// in corpus metadata for the exact algorithm.
Uint8List _lcgPayload({required int seed, required int size}) {
  final out = Uint8List(size);
  int state = seed & 0xFFFFFFFF;
  for (var i = 0; i < size; i++) {
    state = ((state * 1664525) + 1013904223) & 0xFFFFFFFF;
    out[i] = state & 0xFF;
  }
  return out;
}

/// ASCII sequential event ID generator. See
/// notes.event_id_generator_ascii_seq_v1 in corpus metadata.
List<String> _asciiSeqIds({
  required String prefix,
  required int start,
  required int count,
  required int width,
}) {
  return List.generate(
    count,
    (i) => '$prefix${(start + i).toString().padLeft(width, '0')}',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// YAML-lite scenario parser  (unchanged from prior generator)
// ─────────────────────────────────────────────────────────────────────────────

class _Scenario {
  String name = '';
  String description = '';
  late Map<String, dynamic> envelope;
  Map<String, dynamic> testSigning = const {};
  Map<String, dynamic> expected = const {};
}

_Scenario _parseScenario(String src) {
  final scenario = _Scenario();
  final stack = <_Frame>[_Frame(scenario.toMap(), -1)];

  for (var rawLine in src.split('\n')) {
    final line = rawLine.replaceAll('\r', '');
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final indent = _leadingSpaces(line);
    while (stack.length > 1 && indent <= stack.last.indent) {
      stack.removeLast();
    }
    final content = line.trimLeft();
    final colon = content.indexOf(':');
    if (colon < 0) {
      throw FormatException('expected key:value, got "$line"');
    }
    final key = content.substring(0, colon).trim();
    var rawValue = content.substring(colon + 1).trim();
    if (rawValue.startsWith('"')) {
      final close = rawValue.indexOf('"', 1);
      if (close > 0) {
        rawValue = rawValue.substring(0, close + 1);
      }
    } else {
      final hashIdx = _findInlineHash(rawValue);
      if (hashIdx >= 0) rawValue = rawValue.substring(0, hashIdx).trim();
    }
    if (rawValue.isEmpty) {
      final child = <String, dynamic>{};
      stack.last.map[key] = child;
      stack.add(_Frame(child, indent));
    } else {
      stack.last.map[key] = _coerce(rawValue);
    }
  }

  scenario.fromMap(stack.first.map);
  return scenario;
}

class _Frame {
  final Map<String, dynamic> map;
  final int indent;
  _Frame(this.map, this.indent);
}

int _findInlineHash(String s) {
  for (var i = 0; i < s.length; i++) {
    if (s.codeUnitAt(i) == 0x23) {
      if (i == 0) return i;
      final prev = s.codeUnitAt(i - 1);
      if (prev == 0x20 || prev == 0x09) return i;
    }
  }
  return -1;
}

int _leadingSpaces(String s) {
  var n = 0;
  for (final c in s.codeUnits) {
    if (c == 32) {
      n++;
    } else {
      break;
    }
  }
  return n;
}

dynamic _coerce(String raw) {
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  if (raw.startsWith('"') && raw.endsWith('"')) {
    return raw.substring(1, raw.length - 1);
  }
  final asInt = int.tryParse(raw);
  if (asInt != null) return asInt;
  return raw;
}

Future<Map<String, dynamic>> _buildEnvelopeSampleFromYaml(_Scenario s) async {
  final env = s.envelope;
  final created = (env['created_at_hlc'] ?? const {}) as Map<String, dynamic>;
  final expires = (env['expires_at_hlc'] ?? const {}) as Map<String, dynamic>;
  final payload = _hexDecode(env['payload_hex'] as String? ?? '');
  final envelopeId = _hexDecode(env['envelope_id_hex'] as String);

  Uint8List authorKey = _hexDecode(env['author_key_hex'] as String);
  Uint8List? signature;
  String? privKeyHex;

  if (s.testSigning['private_key_hex'] != null) {
    privKeyHex = s.testSigning['private_key_hex'] as String;
    final priv = _hexDecode(privKeyHex);
    final ed = Ed25519();
    final keyPair = await ed.newKeyPairFromSeed(priv);
    final pubBytes = Uint8List.fromList(
      await keyPair.extractPublicKey().then((p) => p.bytes),
    );
    if ((s.testSigning['public_key_hex_must_match_author'] as bool? ?? false)) {
      authorKey = pubBytes;
    }
    final payloadHash = await CanonicalEncoderV2.hashPayload(payload);
    final sigInput = CanonicalEncoderV2.buildSignatureInput(
      protocolVersion: env['protocol_version'] as int,
      envelopeId: envelopeId,
      eventType: env['event_type'] as int,
      priority: env['priority'] as int,
      createdAtHlcMs: created['ms_since_epoch'] as int,
      createdAtHlcCounter: created['counter'] as int,
      expiresAtHlcMs: expires['ms_since_epoch'] as int,
      expiresAtHlcCounter: expires['counter'] as int,
      maxHops: env['max_hops'] as int,
      authorKey: authorKey,
      sigAlgo: env['sig_algo'] as int,
      payloadHash: payloadHash,
    );
    final sig = await ed.sign(sigInput, keyPair: keyPair);
    signature = Uint8List.fromList(sig.bytes);

    final envelopeStruct = Map<String, dynamic>.from(env);
    envelopeStruct['author_key_hex'] = _hex(authorKey);
    final payloadSha = _hex(crypto_pkg.sha256.convert(payload).bytes);

    return <String, dynamic>{
      'kind': 'envelope',
      'name': s.name,
      'description': s.description,
      'envelope_struct': envelopeStruct,
      'payload_sha256_hex': payloadSha,
      'expected_canonical_sig_input_hex': _hex(sigInput),
      'expected_canonical_sig_input_bytes': sigInput.length,
      'expected_signature_hex': _hex(signature),
      'derived_author_key_hex': _hex(authorKey),
      'test_only_private_key_hex': privKeyHex,
    };
  }

  // Unsigned YAML scenario — canonical-input-only sample.
  final payloadHash = await CanonicalEncoderV2.hashPayload(payload);
  final sigInput = CanonicalEncoderV2.buildSignatureInput(
    protocolVersion: env['protocol_version'] as int,
    envelopeId: envelopeId,
    eventType: env['event_type'] as int,
    priority: env['priority'] as int,
    createdAtHlcMs: created['ms_since_epoch'] as int,
    createdAtHlcCounter: created['counter'] as int,
    expiresAtHlcMs: expires['ms_since_epoch'] as int,
    expiresAtHlcCounter: expires['counter'] as int,
    maxHops: env['max_hops'] as int,
    authorKey: authorKey,
    sigAlgo: env['sig_algo'] as int,
    payloadHash: payloadHash,
  );
  final payloadSha = _hex(crypto_pkg.sha256.convert(payload).bytes);
  return <String, dynamic>{
    'kind': 'envelope',
    'name': s.name,
    'description': s.description,
    'envelope_struct': env,
    'payload_sha256_hex': payloadSha,
    'expected_canonical_sig_input_hex': _hex(sigInput),
    'expected_canonical_sig_input_bytes': sigInput.length,
  };
}

extension _ScenarioMap on _Scenario {
  Map<String, dynamic> toMap() => <String, dynamic>{};
  void fromMap(Map<String, dynamic> map) {
    name = (map['name'] as String?) ?? '';
    description = (map['description'] as String?) ?? '';
    envelope = (map['envelope'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    testSigning = (map['test_signing'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    expected = (map['expected'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hex helpers
// ─────────────────────────────────────────────────────────────────────────────

String _hex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
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
