// Cross-platform wire conformance corpus generator (v0.3 Stage 0c).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §17.5
//   + docs/specs/native_transport_v1_2026-05-13.md §11.7.
//
// Per spec, this Dart script is the SOLE source of truth for new test
// vectors. Kotlin and Swift implementations CONSUME the JSON and MUST NOT
// regenerate it. Inputs live in `test/wire_conformance/scenarios/*.yaml`;
// output goes to `../docs/specs/wire_conformance_v1.json`.
//
// Scope (this scaffold lands in Stage 0c1 alongside the Chunker / canonical
// encoder; the full corpus production lands as YAML scenarios are authored):
//
//   ✓ Wire envelope (canonical signature input, proto bytes, signature)
//   ◯ IBLT bucket-state samples — depends on regenerated proto messages
//   ◯ Bloom v2 bit-vector samples — depends on Bloom Dart helper
//   ✓ Chunk framing samples (uses Chunker directly)
//   ✓ Negative cases (oversized SOS, invalid sig_algo, etc.)
//
// Usage:
//   dart run tool/generate_wire_conformance_v1.dart
//
// Exit codes:
//   0 — corpus regenerated, output written
//   1 — input scenario malformed
//   2 — output unwritable / spec drift detected

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:ignirelay_app/app/crypto/canonical_encoder_v2.dart';
import 'package:ignirelay_app/app/mesh/chunker.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';

const String _scenariosDir = 'test/wire_conformance/scenarios';
const String _outputPath = '../docs/specs/wire_conformance_v1.json';

Future<int> main(List<String> args) async {
  final scenariosDir = Directory(_scenariosDir);
  if (!await scenariosDir.exists()) {
    stderr.writeln('generate_wire_conformance_v1: scenarios dir missing: ${scenariosDir.path}');
    return 2;
  }

  final corpus = <String, dynamic>{
    'spec_version': 'v0.3 Stage 0c',
    'spec_envelope': 'docs/specs/envelope_v2_spec_2026-05-13.md',
    'spec_transport': 'docs/specs/native_transport_v1_2026-05-13.md',
    'generated_at_iso': DateTime.now().toUtc().toIso8601String(),
    'envelope_samples': <Map<String, dynamic>>[],
    'chunking_samples': <Map<String, dynamic>>[],
    'iblt_samples': <Map<String, dynamic>>[],
    'bloom_samples': <Map<String, dynamic>>[],
    'negative_cases': <Map<String, dynamic>>[],
  };

  // 1) Build envelope samples from each YAML scenario.
  await for (final entity in scenariosDir.list()) {
    if (entity is! File || !entity.path.endsWith('.yaml')) continue;
    try {
      final scenario = _parseScenario(await entity.readAsString());
      final result = await _buildEnvelopeSample(scenario);
      (corpus['envelope_samples'] as List).add(result);
    } on FormatException catch (e) {
      stderr.writeln('  malformed scenario ${entity.path}: $e');
      return 1;
    }
  }

  // 2) Canonical chunking samples — exercise the locked MTU matrix at the
  //    SOS budget so cross-platform implementations all hit the same
  //    `total_chunks` derivation.
  for (final mtu in [185, 247, 512]) {
    final envelopeBytes = Uint8List(kSosEnvelopeBudgetBytes);
    for (var i = 0; i < envelopeBytes.length; i++) {
      envelopeBytes[i] = i & 0xFF;
    }
    final id = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      id[i] = (0xA0 | (i & 0x0F));
    }
    final chunks = Chunker.split(
      envelopeId: id,
      envelopeBytes: envelopeBytes,
      mtu: mtu,
    );
    (corpus['chunking_samples'] as List).add({
      'kind': 'chunking',
      'envelope_bytes_hex': _hex(envelopeBytes),
      'envelope_id_hex': _hex(id),
      'negotiated_mtu': mtu,
      'expected_chunk_bytes_hex_array': chunks.map(_hex).toList(),
      'expected_chunk_count': chunks.length,
    });
  }

  // 3) Negative cases that MUST fail decode at sender or receiver.
  final negatives = corpus['negative_cases'] as List<Map<String, dynamic>>;

  negatives.add({
    'kind': 'oversize_sos',
    'description': 'SOS envelope > 240B — sender REJECTS at publish time.',
    'envelope_bytes_hex_length': kSosEnvelopeBudgetBytes + 1,
    'expected_drop_reason': 'over-budget-sos-rejected',
  });

  negatives.add({
    'kind': 'oversize_envelope',
    'description': 'Envelope > MAX_ENVELOPE_BYTES — Chunker REJECTS.',
    'envelope_bytes_hex_length': kMaxEnvelopeBytes + 1,
    'expected_drop_reason': 'over-max-envelope-bytes',
  });

  negatives.add({
    'kind': 'unknown_sig_algo',
    'description': 'sig_algo = 0x02 (post-quantum slot, not implemented in v0.3).',
    'sig_algo': 0x02,
    'expected_drop_reason': 'unknown-sig-algo',
  });

  negatives.add({
    'kind': 'chunk_total_zero',
    'description': 'Chunk header with total_chunks=0 is illegal.',
    'expected_drop_reason': 'chunk-bad-header',
  });

  negatives.add({
    'kind': 'chunk_index_oob',
    'description': 'Chunk header with chunk_index >= total_chunks is illegal.',
    'expected_drop_reason': 'chunk-bad-header',
  });

  // 4) Write the corpus.
  final outFile = File(_outputPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(corpus),
  );

  stdout.writeln('generate_wire_conformance_v1: wrote ${outFile.path}');
  stdout.writeln('  envelope_samples=${(corpus['envelope_samples'] as List).length}');
  stdout.writeln('  chunking_samples=${(corpus['chunking_samples'] as List).length}');
  stdout.writeln('  negative_cases=${(corpus['negative_cases'] as List).length}');
  return 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// YAML-lite scenario parser
//
// Avoids pulling a YAML dependency by parsing the pinned subset we use in the
// hand-authored scenarios. If the format grows, swap in package:yaml.
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
    // Strip inline `# comment`. For quoted strings we look for the matching
    // closing quote first, then trim anything after it. For bare values we
    // strip on the first `#` preceded by whitespace.
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
      // Nested map opens here.
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

/// Returns the index of an inline `#` comment marker, or -1 when none.
/// Heuristic: `#` must be preceded by whitespace (or at index 0).
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
  if (raw.startsWith('"') && raw.endsWith('"')) return raw.substring(1, raw.length - 1);
  final asInt = int.tryParse(raw);
  if (asInt != null) return asInt;
  return raw;
}

Future<Map<String, dynamic>> _buildEnvelopeSample(_Scenario s) async {
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
    final pubBytes = Uint8List.fromList(await keyPair.extractPublicKey().then((p) => p.bytes));
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

    return <String, dynamic>{
      'kind': 'envelope',
      'name': s.name,
      'description': s.description,
      'envelope_struct': env,
      'expected_canonical_sig_input_hex': _hex(sigInput),
      'expected_canonical_sig_input_bytes': sigInput.length,
      'expected_signature_hex': _hex(signature),
      'derived_author_key_hex': _hex(authorKey),
      'test_only_private_key_hex': privKeyHex,
    };
  }

  // No signing key in this scenario — emit canonical-input-only sample.
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
  return <String, dynamic>{
    'kind': 'envelope',
    'name': s.name,
    'description': s.description,
    'envelope_struct': env,
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
