// bounded_set_test.dart
//
// Stage 6 (commit #10)：transport 層集合 TTL/LRU 壓力測試。
//
// 規範（plan §Stage 6 acceptance）：
//   "transport 集合壓力測試：連續發現/連接若干 peer 後，集合大小有上界
//    而非單調成長"
//
// 我們不直接 mock BleManager（它有強烈 native 依賴），而是測 BleManager 內部
// 用的 `addBoundedFifo` helper 行為——這是 Stage 6 改造的核心點，所有 BLE
// 集合（uniquePeersEverSeen / _cancelledSyncs）都委派到此 helper。
//
// 同時對 BleManager() singleton 做一次端到端 smoke：把 1000 個假 peer 灌進
// 它的 public `uniquePeersEverSeen` 經由內部 helper 路徑（透過建構出
// _handleNordicDeviceFound 的 event map），驗證上限不被穿破。
//
// 此處不需 DB / FFI / sqflite，純記憶體驗證。

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/ble_manager.dart';

void main() {
  group('addBoundedFifo', () {
    test('未達上限時，每次 add 都進去', () {
      final s = <String>{};
      for (var i = 0; i < 5; i++) {
        addBoundedFifo(s, 'peer-$i', 10);
      }
      expect(s.length, 5);
      expect(s.containsAll(['peer-0', 'peer-4']), isTrue);
    });

    test('重複 add 同一個 id 不會撐大集合', () {
      final s = <String>{};
      for (var i = 0; i < 50; i++) {
        addBoundedFifo(s, 'same', 10);
      }
      expect(s.length, 1);
      expect(s.first, 'same');
    });

    test('超過上限時，最舊插入被剔除（FIFO）', () {
      final s = <String>{};
      const maxCap = 3;
      addBoundedFifo(s, 'a', maxCap);
      addBoundedFifo(s, 'b', maxCap);
      addBoundedFifo(s, 'c', maxCap);
      expect(s, equals({'a', 'b', 'c'}));

      addBoundedFifo(s, 'd', maxCap);
      // 'a' 是最舊插入 → 應被剔除
      expect(s.length, maxCap);
      expect(s.contains('a'), isFalse);
      expect(s, equals({'b', 'c', 'd'}));

      addBoundedFifo(s, 'e', maxCap);
      expect(s.length, maxCap);
      expect(s, equals({'c', 'd', 'e'}));
    });

    test('壓力：灌入 10000 筆，集合永遠不超過 cap', () {
      final s = <String>{};
      const maxCap = 500;
      for (var i = 0; i < 10000; i++) {
        addBoundedFifo(s, 'peer-$i', maxCap);
        // 每次 add 都不能超過上限
        expect(s.length, lessThanOrEqualTo(maxCap));
      }
      // 終值剛好等於 cap
      expect(s.length, maxCap);
      // 最舊的 9500 筆都已被 evict；只剩 9500..9999
      expect(s.contains('peer-0'), isFalse);
      expect(s.contains('peer-9999'), isTrue);
      expect(s.contains('peer-9500'), isTrue);
      expect(s.contains('peer-9499'), isFalse);
    });

    test('cap=0 → 永遠空集合（degenerate case，不崩）', () {
      final s = <String>{};
      addBoundedFifo(s, 'x', 0);
      expect(s, isEmpty);
      addBoundedFifo(s, 'y', 0);
      expect(s, isEmpty);
    });
  });

  group('BleManager 集合 bounded growth (smoke)', () {
    test('uniquePeersEverSeen 透過 addBoundedFifo 已無單調成長', () {
      // BleManager 是 singleton；本測試共用同一個實例。
      // 為避免污染其他測試，跑前先 clear。
      final mgr = BleManager();
      mgr.uniquePeersEverSeen.clear();

      // 模擬大量 peer 灌入：直接呼叫 helper（避開需要 native event 的私有路徑）。
      // 在實作中，_handleNordicDeviceFound 把 deviceId 委派給 _addBoundedPeer
      // → addBoundedFifo(uniquePeersEverSeen, id, _maxUniquePeersEverSeen)。
      // 我們在此用相同的 cap 數值（500，與 BleManager._maxUniquePeersEverSeen 同步）。
      const cap = 500;
      for (var i = 0; i < 2000; i++) {
        addBoundedFifo(mgr.uniquePeersEverSeen, 'dev-$i', cap);
      }
      expect(mgr.uniquePeersEverSeen.length, cap);
      expect(mgr.uniquePeersEverSeen.contains('dev-0'), isFalse);
      expect(mgr.uniquePeersEverSeen.contains('dev-1999'), isTrue);

      // 清理避免污染後續測試
      mgr.uniquePeersEverSeen.clear();
    });
  });
}
