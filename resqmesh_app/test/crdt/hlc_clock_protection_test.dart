// hlc_clock_protection_test.dart
//
// 測試 HLC v2.2 時鐘保護功能：
// 1. 本地時鐘正常 — 遠端超前 24h 被拒絕
// 2. 本地時鐘壞了 — 合理遠端時間被接受
// 3. 本地時鐘壞了 — 遠端超過 build+2year 被拒絕
// 4. median network time 計算
// 5. resetForTest 正確清空狀態

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/crdt/hlc.dart';

void main() {
  setUp(() {
    HLC.resetForTest();
  });

  group('HLC — clock protection', () {
    test('normal clock: remote within 24h is accepted', () {
      HLC.setNodeId('local');
      HLC.now();

      // Remote 1 hour ahead
      final remoteTs = DateTime.now().millisecondsSinceEpoch + 3600000;
      final remote = HLC(remoteTs, 0, 'remote');
      final merged = HLC.merge(remote);

      // Should accept: merged timestamp >= remote timestamp
      expect(merged.timestamp, greaterThanOrEqualTo(remoteTs));
    });

    test('normal clock: remote >24h ahead is rejected', () {
      HLC.setNodeId('local');
      HLC.now(); // initialize current

      // Remote 25 hours ahead
      final nowTs = DateTime.now().millisecondsSinceEpoch;
      final remoteTs = nowTs + (25 * 3600000);
      final remote = HLC(remoteTs, 0, 'attacker');

      final before = HLC.current;
      final merged = HLC.merge(remote);

      // Should be rejected — merged should equal previous state
      expect(merged.timestamp, equals(before.timestamp));
      expect(merged.counter, equals(before.counter));
    });

    test('broken clock: reasonable remote is accepted', () {
      HLC.setNodeId('local');

      // Set app build timestamp to a recent date
      final buildTs = DateTime.now().millisecondsSinceEpoch;
      HLC.setAppBuildTimestamp(buildTs + 3600000); // build is "1h in future" → local clock appears broken

      HLC.now(); // initialize (will have nowTs < appBuildTimestamp → broken)

      // Remote at build+1 day (within build+2years)
      final remoteTs = buildTs + 3600000 + 86400000;
      final remote = HLC(remoteTs, 0, 'helper');
      final merged = HLC.merge(remote);

      // Should accept
      expect(merged.timestamp, greaterThanOrEqualTo(remoteTs));
    });

    test('broken clock: remote beyond build+2years is rejected', () {
      HLC.setNodeId('local');

      final buildTs = DateTime.now().millisecondsSinceEpoch;
      // Make clock appear broken
      HLC.setAppBuildTimestamp(buildTs + 3600000);
      HLC.now();

      // Remote at build+3 years (beyond 2-year window)
      final remoteTs = buildTs + 3600000 + (1100 * 86400000); // ~3 years
      final remote = HLC(remoteTs, 0, 'bad');

      final before = HLC.current;
      final merged = HLC.merge(remote);

      // Should be rejected
      expect(merged.timestamp, equals(before.timestamp));
    });

    test('median network time computed from 3+ samples', () {
      HLC.setNodeId('local');
      HLC.now();

      // No samples yet
      expect(HLC.medianNetworkTime, isNull);

      // Add 3 samples via merge
      final now = DateTime.now().millisecondsSinceEpoch;
      HLC.merge(HLC(now + 100, 0, 'a'));
      HLC.merge(HLC(now + 300, 0, 'b'));
      HLC.merge(HLC(now + 200, 0, 'c'));

      final median = HLC.medianNetworkTime;
      expect(median, isNotNull);
      // Median of [now+100, now+200, now+300] should be now+200
      expect(median, equals(now + 200));
    });
  });

  group('HLC — basic operations', () {
    test('now() advances timestamp', () {
      HLC.setNodeId('test');
      final h1 = HLC.now();
      final h2 = HLC.now();

      // h2 should be >= h1
      expect(h2.compareTo(h1), greaterThanOrEqualTo(0));
    });

    test('compareTo works correctly', () {
      final a = HLC(100, 0, 'a');
      final b = HLC(100, 1, 'a');
      final c = HLC(200, 0, 'a');

      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
      expect(a.compareTo(c), lessThan(0));
      expect(c.compareTo(a), greaterThan(0));
    });

    test('equality', () {
      final a = HLC(100, 1, 'node');
      final b = HLC(100, 1, 'node');
      expect(a, equals(b));
    });

    test('resetForTest clears all state', () {
      HLC.setNodeId('test');
      HLC.setAppBuildTimestamp(12345);
      HLC.now();

      HLC.resetForTest();

      final current = HLC.current;
      expect(current.timestamp, equals(0));
      expect(current.counter, equals(0));
      expect(HLC.medianNetworkTime, isNull);
    });
  });
}
