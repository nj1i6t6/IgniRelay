// v0.3 Stage 0c wave 3C — IBLT cross-platform parity fixture generator.
//
// One-shot script. Run when the Dart IBLT changes (it's the oracle):
//
//     dart run tool/generate_iblt_swift_parity_fixture.dart
//
// Produces test/fixtures/iblt_swift_parity_vectors.json. The Dart test
// in test/mesh/iblt_swift_parity_test.dart verifies the fixture matches
// the live Dart IBLT (catches regressions). The Swift test in
// ios/RunnerTests/RunnerTests.swift verifies the fixture also matches
// the live Swift IBLT (catches cross-platform divergence — the whole
// point of the parity check).

import 'dart:convert';
import 'dart:io';

import 'package:ignirelay_app/app/mesh/iblt.dart';

void main() {
  final cases = <_Case>[
    const _Case(name: 'empty', insert: <String>[], remove: <String>[]),
    const _Case(name: 'single_event', insert: ['event-001']),
    const _Case(name: 'ascii_triple', insert: ['abc', 'def', 'ghi']),
    const _Case(
      name: 'uuid_v7_five',
      insert: [
        '01890b1a00000000000000000000aa01',
        '01890b1a00000000000000000000aa02',
        '01890b1a00000000000000000000aa03',
        '01890b1a00000000000000000000aa04',
        '01890b1a00000000000000000000aa05',
      ],
    ),
    const _Case(
      name: 'uuid_v7_thirty',
      insert: [
        '01890b1ad2dc7d3a8b9c4f8d63b21f01',
        '01890b1ad2dc7d3a8b9c4f8d63b21f02',
        '01890b1ad2dc7d3a8b9c4f8d63b21f03',
        '01890b1ad2dc7d3a8b9c4f8d63b21f04',
        '01890b1ad2dc7d3a8b9c4f8d63b21f05',
        '01890b1ad2dc7d3a8b9c4f8d63b21f06',
        '01890b1ad2dc7d3a8b9c4f8d63b21f07',
        '01890b1ad2dc7d3a8b9c4f8d63b21f08',
        '01890b1ad2dc7d3a8b9c4f8d63b21f09',
        '01890b1ad2dc7d3a8b9c4f8d63b21f0a',
        '01890b1ad2dc7d3a8b9c4f8d63b21f0b',
        '01890b1ad2dc7d3a8b9c4f8d63b21f0c',
        '01890b1ad2dc7d3a8b9c4f8d63b21f0d',
        '01890b1ad2dc7d3a8b9c4f8d63b21f0e',
        '01890b1ad2dc7d3a8b9c4f8d63b21f0f',
        '01890b1ad2dc7d3a8b9c4f8d63b21f10',
        '01890b1ad2dc7d3a8b9c4f8d63b21f11',
        '01890b1ad2dc7d3a8b9c4f8d63b21f12',
        '01890b1ad2dc7d3a8b9c4f8d63b21f13',
        '01890b1ad2dc7d3a8b9c4f8d63b21f14',
        '01890b1ad2dc7d3a8b9c4f8d63b21f15',
        '01890b1ad2dc7d3a8b9c4f8d63b21f16',
        '01890b1ad2dc7d3a8b9c4f8d63b21f17',
        '01890b1ad2dc7d3a8b9c4f8d63b21f18',
        '01890b1ad2dc7d3a8b9c4f8d63b21f19',
        '01890b1ad2dc7d3a8b9c4f8d63b21f1a',
        '01890b1ad2dc7d3a8b9c4f8d63b21f1b',
        '01890b1ad2dc7d3a8b9c4f8d63b21f1c',
        '01890b1ad2dc7d3a8b9c4f8d63b21f1d',
        '01890b1ad2dc7d3a8b9c4f8d63b21f1e',
      ],
    ),
    const _Case(
      name: 'insert_then_remove',
      insert: ['x', 'y', 'z'],
      remove: ['y'],
    ),
  ];

  final entries = <Map<String, dynamic>>[];
  for (final c in cases) {
    final iblt = IBLT();
    for (final id in c.insert) {
      iblt.insert(id);
    }
    for (final id in c.remove) {
      iblt.remove(id);
    }
    final bytes = iblt.toBytes();
    entries.add({
      'name': c.name,
      'insert': c.insert,
      'remove': c.remove,
      'expected_bytes_hex': _hex(bytes),
    });
  }

  // Subtract vector: build A and B with overlapping + unique sets, capture
  // A.subtract(B).toBytes() so Swift can verify its subtract is byte-identical
  // even if peel() is unreliable (see note below).
  final subtractCase = _buildSubtractCase();
  entries.add({
    'name': subtractCase.name,
    'a_insert': subtractCase.aInsert,
    'b_insert': subtractCase.bInsert,
    'a_bytes_hex': subtractCase.aHex,
    'b_bytes_hex': subtractCase.bHex,
    'diff_bytes_hex': subtractCase.diffHex,
  });

  // NOTE: We intentionally do NOT pin a peel() golden vector. The existing
  // Dart/Kotlin IBLT uses `getIndicesFromHash` (CRC-bit-derived) for the
  // peel-side index lookup while `getIndices` (MurmurHash-derived) drives
  // insert — these two derivations are NOT equivalent, so peel succeeds
  // only on inputs that happen to align across the two index spaces. This
  // is a structural quirk of the existing implementation, not introduced
  // by Wave 3C. Swift IBLT.peel mirrors the same quirk byte-for-byte. The
  // wire contract that matters across platforms is toBytes()/subtract(),
  // which the fixture covers exhaustively.

  final fixture = {
    'version': 1,
    'generated_by': 'tool/generate_iblt_swift_parity_fixture.dart',
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'oracle': 'Dart IBLT @ lib/app/mesh/iblt.dart',
    'bucket_count': IBLT.bucketCount,
    'bucket_size': IBLT.bucketSize,
    'total_bytes': IBLT.totalBytes,
    'cases': entries,
  };

  const outPath = 'test/fixtures/iblt_swift_parity_vectors.json';
  Directory(File(outPath).parent.path).createSync(recursive: true);
  File(outPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(fixture)}\n',
  );
  stdout.writeln('Wrote $outPath with ${entries.length} cases');
}

class _Case {
  final String name;
  final List<String> insert;
  final List<String> remove;
  const _Case({
    required this.name,
    required this.insert,
    this.remove = const <String>[],
  });
}

class _SubtractCase {
  final String name;
  final List<String> aInsert;
  final List<String> bInsert;
  final String aHex;
  final String bHex;
  final String diffHex;
  _SubtractCase({
    required this.name,
    required this.aInsert,
    required this.bInsert,
    required this.aHex,
    required this.bHex,
    required this.diffHex,
  });
}

_SubtractCase _buildSubtractCase() {
  final a = IBLT();
  final b = IBLT();
  const shared = ['shared-1', 'shared-2', 'shared-3'];
  const aOnly = ['a-only-1', 'a-only-2'];
  const bOnly = ['b-only-1', 'b-only-2'];
  for (final id in [...shared, ...aOnly]) {
    a.insert(id);
  }
  for (final id in [...shared, ...bOnly]) {
    b.insert(id);
  }
  final diff = a.subtract(b);
  return _SubtractCase(
    name: 'subtract_symmetric_diff_4',
    aInsert: [...shared, ...aOnly],
    bInsert: [...shared, ...bOnly],
    aHex: _hex(a.toBytes()),
    bHex: _hex(b.toBytes()),
    diffHex: _hex(diff.toBytes()),
  );
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
