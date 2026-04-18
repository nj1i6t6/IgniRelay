// iblt_test.dart
//
// 測試 IBLT (Invertible Bloom Lookup Table) 基本行為
// 56 buckets × 9 bytes = 504 bytes

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/iblt.dart';

void main() {
  group('IBLT — Construction & Serialization', () {
    test('new IBLT has correct byte length (504)', () {
      final iblt = IBLT();
      final bytes = iblt.toBytes();
      expect(bytes.length, equals(504)); // 56 × 9
    });

    test('roundtrip: toBytes → fromBytes preserves structure', () {
      final iblt = IBLT();
      iblt.insert('test-event-id-1');
      iblt.insert('test-event-id-2');
      final bytes = iblt.toBytes();
      final restored = IBLT.fromBytes(bytes);
      expect(restored.toBytes(), equals(bytes));
    });

    test('insert adds item without throwing', () {
      final iblt = IBLT();
      expect(() => iblt.insert('event-abc-123'), returnsNormally);
    });

    test('multiple inserts do not throw', () {
      final iblt = IBLT();
      for (int i = 0; i < 20; i++) {
        iblt.insert('event-$i');
      }
      expect(iblt.toBytes().length, equals(504));
    });
  });

  group('IBLT — Subtract & Peel', () {
    test('subtract identical IBLTs and peel → empty sets', () {
      final a = IBLT();
      final b = IBLT();
      a.insert('e1');
      a.insert('e2');
      b.insert('e1');
      b.insert('e2');
      final diff = a.subtract(b);
      final result = diff.peel();
      expect(result, isNotNull);
      expect(result!.onlyInA, isEmpty);
      expect(result.onlyInB, isEmpty);
    });

    test('subtract produces non-zero IBLT when inputs differ', () {
      final a = IBLT();
      final b = IBLT();
      a.insert('e1');
      a.insert('e2');
      b.insert('e1');
      final diff = a.subtract(b);
      // The diff should not be all zeros
      final bytes = diff.toBytes();
      final hasNonZero = bytes.any((b) => b != 0);
      expect(hasNonZero, isTrue);
    });

    test('subtract produces zero IBLT when inputs are identical', () {
      final a = IBLT();
      final b = IBLT();
      a.insert('e1');
      b.insert('e1');
      final diff = a.subtract(b);
      final result = diff.peel();
      expect(result, isNotNull);
      expect(result!.onlyInA, isEmpty);
      expect(result.onlyInB, isEmpty);
    });

    test('peel returns null for too many differences', () {
      final a = IBLT();
      final b = IBLT();
      // Insert 50+ unique items in each — exceeds ~38 item tolerance
      for (int i = 0; i < 60; i++) {
        a.insert('a-only-$i');
        b.insert('b-only-$i');
      }
      final diff = a.subtract(b);
      final result = diff.peel();
      // Too many differences → peel fails
      expect(result, isNull);
    });
  });

  group('IBLT — Error Handling', () {
    test('fromBytes with wrong length throws', () {
      final tooShort = Uint8List(100);
      expect(() => IBLT.fromBytes(tooShort), throwsA(anything));
    });

    test('fromBytes with empty bytes throws', () {
      final empty = Uint8List(0);
      expect(() => IBLT.fromBytes(empty), throwsA(anything));
    });

    test('fromBytes with correct length (504) does not throw', () {
      final valid = Uint8List(504);
      expect(() => IBLT.fromBytes(valid), returnsNormally);
    });
  });
}
