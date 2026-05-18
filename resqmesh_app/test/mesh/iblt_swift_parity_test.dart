// v0.3 Stage 0c wave 3C — IBLT cross-platform parity regression test.
//
// Pins the Dart IBLT byte output against the JSON fixture committed at
// test/fixtures/iblt_swift_parity_vectors.json. If this test fails after a
// change to lib/app/mesh/iblt.dart, you MUST regenerate the fixture:
//
//     dart run tool/generate_iblt_swift_parity_fixture.dart
//
// ... and then re-run the iOS XCTest in ios/RunnerTests/IBLTParityTests.swift
// against the new fixture. Divergence between Dart and Swift means the
// cross-platform IBLT sync is broken; spec docs/specs/native_transport_v1
// _2026-05-13.md §3.2.1 requires bit-identical bucket bytes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/iblt.dart';

void main() {
  group('IBLT cross-platform parity (Dart side)', () {
    late Map<String, dynamic> fixture;

    setUpAll(() {
      final file = File('test/fixtures/iblt_swift_parity_vectors.json');
      expect(file.existsSync(), true,
          reason: 'fixture missing — regenerate via '
              'tool/generate_iblt_swift_parity_fixture.dart');
      fixture =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('fixture metadata matches live constants', () {
      expect(fixture['bucket_count'], IBLT.bucketCount);
      expect(fixture['bucket_size'], IBLT.bucketSize);
      expect(fixture['total_bytes'], IBLT.totalBytes);
      expect(fixture['version'], 1);
    });

    test('insert/remove cases produce fixture-pinned bytes', () {
      final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
      for (final c in cases) {
        if (!c.containsKey('insert')) continue; // skip subtract case here
        final iblt = IBLT();
        for (final id in (c['insert'] as List).cast<String>()) {
          iblt.insert(id);
        }
        for (final id in (c['remove'] as List).cast<String>()) {
          iblt.remove(id);
        }
        final bytes = iblt.toBytes();
        expect(_hex(bytes), c['expected_bytes_hex'],
            reason: 'case "${c['name']}" diverged — regenerate fixture');
        expect(bytes.length, IBLT.totalBytes);
      }
    });

    test('subtract case produces fixture-pinned diff bytes', () {
      final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
      final sub = cases.firstWhere((c) => c['name'] == 'subtract_symmetric_diff_4');
      final a = IBLT();
      final b = IBLT();
      for (final id in (sub['a_insert'] as List).cast<String>()) {
        a.insert(id);
      }
      for (final id in (sub['b_insert'] as List).cast<String>()) {
        b.insert(id);
      }
      expect(_hex(a.toBytes()), sub['a_bytes_hex']);
      expect(_hex(b.toBytes()), sub['b_bytes_hex']);
      expect(_hex(a.subtract(b).toBytes()), sub['diff_bytes_hex']);
    });

    test('round-trip: fromBytes(toBytes) preserves bucket state', () {
      final iblt = IBLT();
      for (final id in const ['a', 'b', 'c', 'd', 'e']) {
        iblt.insert(id);
      }
      final bytes = iblt.toBytes();
      final restored = IBLT.fromBytes(bytes);
      expect(_hex(restored.toBytes()), _hex(bytes));
      for (var i = 0; i < IBLT.bucketCount; i++) {
        expect(restored.buckets[i].count, iblt.buckets[i].count);
        expect(restored.buckets[i].keySum, iblt.buckets[i].keySum);
        expect(restored.buckets[i].hashSum, iblt.buckets[i].hashSum);
      }
    });

    test('empty IBLT has all-zero buckets', () {
      final iblt = IBLT();
      for (final bucket in iblt.buckets) {
        expect(bucket.count, 0);
        expect(bucket.keySum, 0);
        expect(bucket.hashSum, 0);
      }
      expect(iblt.toBytes(), List.filled(IBLT.totalBytes, 0));
    });

    test('a.subtract(a) is all-zero', () {
      final a = IBLT();
      for (final id in const ['x', 'y', 'z']) {
        a.insert(id);
      }
      final z = a.subtract(a);
      expect(z.toBytes(), List.filled(IBLT.totalBytes, 0));
    });
  });
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
