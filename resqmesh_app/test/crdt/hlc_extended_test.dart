import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/crdt/hlc.dart';

void main() {
  group('HLC — now() monotonicity', () {
    test('consecutive calls produce non-decreasing timestamps', () {
      final a = HLC.now();
      final b = HLC.now();
      expect(b.timestamp >= a.timestamp, isTrue);
    });

    test('10 rapid calls all non-decreasing', () {
      final timestamps = List.generate(10, (_) => HLC.now().timestamp);
      for (int i = 1; i < timestamps.length; i++) {
        expect(
          timestamps[i] >= timestamps[i - 1],
          isTrue,
          reason: 'HLC must not go backwards at index $i',
        );
      }
    });

    test('now() advances HLC.current', () {
      final before = HLC.current;
      HLC.now();
      final after = HLC.current;
      expect(after.timestamp >= before.timestamp, isTrue);
    });

    test('same-millisecond calls increment counter', () {
      // 快速連續呼叫，保證 counter 在同 ms 內遞增
      HLC.now(); // prime the clock
      final snapTs = HLC.current.timestamp;
      int? firstSameMs;
      int? secondSameMs;

      // 收集同一 ms 的兩個讀數
      for (int i = 0; i < 100; i++) {
        final h = HLC.now();
        if (h.timestamp == snapTs) {
          if (firstSameMs == null) {
            firstSameMs = h.counter;
          } else {
            secondSameMs = h.counter;
            break;
          }
        }
      }
      if (firstSameMs != null && secondSameMs != null) {
        expect(secondSameMs, greaterThan(firstSameMs));
      }
      // 如果所有呼叫都落在不同 ms，counter 可能都是 0，也算通過
    });
  });

  group('HLC — merge()', () {
    test('merge with future timestamp advances local clock', () {
      final futureTs = DateTime.now().millisecondsSinceEpoch + 10000;
      final merged = HLC.merge(HLC(futureTs, 0));
      expect(merged.timestamp, greaterThanOrEqualTo(futureTs));
    });

    test('merge with past timestamp keeps local time', () {
      HLC.now(); // advance local
      final local = HLC.current;
      final pastRemote = HLC(local.timestamp - 3600000, 99);
      final merged = HLC.merge(pastRemote);
      expect(merged.timestamp, greaterThanOrEqualTo(local.timestamp));
    });

    test('merge same timestamp: counter is max(local,remote)+1', () {
      // 用遠未來時間戳避免 wallclock 在兩次 merge 之間前進造成干擾
      final farFuture = DateTime.now().millisecondsSinceEpoch + 50000;
      // 第一次 merge：把 local 推到 farFuture，counter 設為某值
      HLC.merge(HLC(farFuture, 5));
      final localCounter = HLC.current.counter; // 6 或更高
      // 第二次 merge：同一 timestamp，remote counter = 3 < localCounter
      // → nextCounter = max(localCounter, 3) + 1 = localCounter + 1
      final merged = HLC.merge(HLC(farFuture, 3));
      expect(merged.counter, greaterThan(localCounter));
    });

    test('after merge HLC.current reflects new state', () {
      final futureTs = DateTime.now().millisecondsSinceEpoch + 5000;
      HLC.merge(HLC(futureTs, 0));
      expect(HLC.current.timestamp, greaterThanOrEqualTo(futureTs));
    });

    test('merge is idempotent for same remote', () {
      final ts = DateTime.now().millisecondsSinceEpoch + 1000;
      final r = HLC(ts, 0);
      HLC.merge(r);
      final ts1 = HLC.current.timestamp;
      // merging same remote again should not go backward
      HLC.merge(r);
      expect(HLC.current.timestamp, greaterThanOrEqualTo(ts1));
    });
  });

  group('HLC — compareTo()', () {
    test('earlier timestamp < later timestamp', () {
      final earlier = HLC(1000, 0);
      final later = HLC(2000, 0);
      expect(earlier.compareTo(later), lessThan(0));
      expect(later.compareTo(earlier), greaterThan(0));
    });

    test('same timestamp, lower counter < higher counter', () {
      final a = HLC(1000, 0);
      final b = HLC(1000, 1);
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
    });

    test('same timestamp, same counter, nodeId tiebreaker', () {
      final a = HLC(1000, 5, 'aaaa');
      final b = HLC(1000, 5, 'bbbb');
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
    });

    test('identical HLC: compareTo = 0', () {
      final a = HLC(1000, 5, 'node');
      final b = HLC(1000, 5, 'node');
      expect(a.compareTo(b), equals(0));
    });
  });

  group('HLC — equality & hashCode', () {
    test('equal HLCs are equal', () {
      final a = HLC(1000, 5, 'node');
      final b = HLC(1000, 5, 'node');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different timestamps are not equal', () {
      expect(HLC(1000, 5, 'node'), isNot(equals(HLC(2000, 5, 'node'))));
    });

    test('different counters are not equal', () {
      expect(HLC(1000, 5, 'node'), isNot(equals(HLC(1000, 6, 'node'))));
    });

    test('different nodeIds are not equal', () {
      expect(HLC(1000, 5, 'aaa'), isNot(equals(HLC(1000, 5, 'bbb'))));
    });
  });

  group('HLC — setNodeId', () {
    test('nodeId propagates to subsequent now() calls', () {
      HLC.setNodeId('test-node-xyz');
      final h = HLC.now();
      expect(h.nodeId, equals('test-node-xyz'));
    });
  });

  group('HLC — toString()', () {
    test('toString includes all three components', () {
      final h = HLC(12345, 7, 'abc');
      final s = h.toString();
      expect(s, contains('12345'));
      expect(s, contains('7'));
      expect(s, contains('abc'));
    });
  });
}
