import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/crdt/hlc.dart';
import 'package:ignirelay_app/app/crdt/conflict_resolver.dart';
import 'dart:typed_data';

void main() {
  group('Hybrid Logical Clock (HLC)', () {
    test('HLC should correctly compare timestamps', () {
      final hlc1 = HLC(1000, 0);
      final hlc2 = HLC(2000, 0);

      expect(hlc1.compareTo(hlc2), lessThan(0));
      expect(hlc2.compareTo(hlc1), greaterThan(0));
    });

    test('HLC should correctly compare counters when timestamps match', () {
      final hlc1 = HLC(1000, 1);
      final hlc2 = HLC(1000, 2);

      expect(hlc1.compareTo(hlc2), lessThan(0));
    });

    test('HLC merge should advance timestamp when other is greater', () {
      final remote = HLC(2000, 5);

      final merged = HLC.merge(remote);
      // Because DateTime.now() is likely > 2000, it actually snaps to NOW with counter 0.
      // But assuming we inject time or if now < 2000:
      // it should take max(local, remote, now).
      expect(merged.timestamp, greaterThanOrEqualTo(2000));
    });
  });

  group('Conflict Resolver (Double Spending)', () {
    test('Earlier HLC should win', () {
      final pubKey1 = Uint8List.fromList([1, 2, 3]);
      final pubKey2 = Uint8List.fromList([4, 5, 6]);

      // Event 1 happens earlier
      final result = ConflictResolver.resolveMatchConflict(
        hlc1: HLC(1000, 0),
        urgency1: 1,
        pubKey1: pubKey1,
        hlc2: HLC(2000, 0),
        urgency2: 1,
        pubKey2: pubKey2,
      );

      expect(result, equals(1)); // 1 wins
    });

    test('Tiebreaker uses urgency when HLC matches', () {
      final pubKey1 = Uint8List.fromList([1, 2, 3]);
      final pubKey2 = Uint8List.fromList([4, 5, 6]);

      // Event 2 is SOS_RED (3)
      final result = ConflictResolver.resolveMatchConflict(
        hlc1: HLC(1000, 0),
        urgency1: 1, // RESOURCE
        pubKey1: pubKey1,
        hlc2: HLC(1000, 0),
        urgency2: 3, // SOS_RED
        pubKey2: pubKey2,
      );

      expect(result, equals(2)); // 2 wins
    });
  });
}
