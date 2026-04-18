/// Hybrid Logical Clock — 有狀態單例
/// 標準 HLC 三元組：(wallclock, counter, nodeId)
/// nodeId 用於打破所有 tie，由 IdentityManager 提供公鑰前 8 bytes hex
class HLC {
  final int timestamp;
  final int counter;
  final String nodeId;

  HLC(this.timestamp, this.counter, [this.nodeId = '']);

  // ── 全域有狀態單例 ─────────────────────────────────────────
  static HLC _current = HLC(0, 0);
  static String _nodeId = '';

  /// 設定本機 nodeId（應在 App 啟動時呼叫一次）
  static void setNodeId(String id) => _nodeId = id;

  /// App 構建時間戳（由 main.dart 在啟動時設定）
  /// 用於判斷本地時鐘是否明顯錯誤
  static int _appBuildTimestamp = 0;
  static void setAppBuildTimestamp(int ts) => _appBuildTimestamp = ts;

  /// 最近收到的遠端時間戳（用於 median network time）
  static final List<int> _recentRemoteTimestamps = [];
  static const int _maxSamples = 10;

  /// 取得當前 HLC 並推進（等同 increment），用於本地發布事件
  static HLC now() {
    final nowTs = DateTime.now().millisecondsSinceEpoch;
    if (nowTs > _current.timestamp) {
      _current = HLC(nowTs, 0, _nodeId);
    } else {
      _current = HLC(_current.timestamp, _current.counter + 1, _nodeId);
    }
    return _current;
  }

  /// 取得當前快照（不推進）
  static HLC get current => _current;

  /// 比較兩個 HLC 的先後順序
  /// 回傳負數表示 this 先發生，正數表示 other 先發生，0 表示同時發生
  int compareTo(HLC other) {
    if (timestamp != other.timestamp) {
      return timestamp < other.timestamp ? -1 : 1;
    }
    if (counter != other.counter) {
      return counter < other.counter ? -1 : 1;
    }
    // Tiebreaker: nodeId 字典序
    return nodeId.compareTo(other.nodeId);
  }

  /// 交會強制校時協議 (接收到其他節點的 HLC 時呼叫)
  /// 更新全域 _current，防止因斷電重置為 1970 年導致的時間戳倒退
  ///
  /// v2.2 改動：
  /// - 本地時鐘壞了時（< appBuildTimestamp），有條件接受遠端（build+2年內）
  /// - 本地時鐘正常時，拒絕超前 24h 的惡意未來時間
  /// - 記錄遠端時間戳用於 median network time
  static HLC merge(HLC remote) {
    final nowTs = DateTime.now().millisecondsSinceEpoch;
    final local = _current;

    // ── 階段 1：判斷本地時鐘是否明顯不正常 ──
    final bool localClockBroken =
        _appBuildTimestamp > 0 && nowTs < _appBuildTimestamp;

    if (localClockBroken) {
      // ── 階段 2：本地時鐘壞了，有條件接受遠端 ──
      // 只接受比 app build time 晚但不超過 2 年的遠端時間
      final maxAcceptable = _appBuildTimestamp + (730 * 86400000); // 2 years
      if (remote.timestamp > maxAcceptable) {
        return _current; // 遠端太未來，也不正常，拒絕
      }
    } else {
      // ── 階段 3：本地時鐘正常，防禦惡意未來時間 ──
      if (remote.timestamp - nowTs > 86400000) {
        // 超前 24h
        return _current; // 拒絕
      }
    }

    // ── 記錄遠端時間戳（用於 median 計算）──
    _recordRemoteTimestamp(remote.timestamp);

    // ── 原有 merge 邏輯 ──
    int maxTs = nowTs;
    if (local.timestamp > maxTs) maxTs = local.timestamp;
    if (remote.timestamp > maxTs) maxTs = remote.timestamp;

    int nextCounter = 0;

    if (maxTs == local.timestamp && maxTs == remote.timestamp) {
      nextCounter =
          (local.counter > remote.counter ? local.counter : remote.counter) + 1;
    } else if (maxTs == local.timestamp) {
      nextCounter = local.counter + 1;
    } else if (maxTs == remote.timestamp) {
      nextCounter = remote.counter + 1;
    }

    _current = HLC(maxTs, nextCounter, _nodeId);
    return _current;
  }

  /// 記錄遠端時間戳
  static void _recordRemoteTimestamp(int ts) {
    _recentRemoteTimestamps.add(ts);
    if (_recentRemoteTimestamps.length > _maxSamples) {
      _recentRemoteTimestamps.removeAt(0);
    }
  }

  /// Mesh 網路中位數時間（可選：用於 UI 提示時鐘偏差）
  static int? get medianNetworkTime {
    if (_recentRemoteTimestamps.length < 3) return null;
    final sorted = List<int>.from(_recentRemoteTimestamps)..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// 在本地發布新事件時呼叫，推進計數器（等同 now()）
  HLC increment() {
    return HLC.now();
  }

  @override
  String toString() => 'HLC($timestamp, $counter, $nodeId)';

  @override
  bool operator ==(Object other) =>
      other is HLC &&
      timestamp == other.timestamp &&
      counter == other.counter &&
      nodeId == other.nodeId;

  @override
  int get hashCode => Object.hash(timestamp, counter, nodeId);

  /// Reset for testing only
  static void resetForTest() {
    _current = HLC(0, 0);
    _nodeId = '';
    _appBuildTimestamp = 0;
    _recentRemoteTimestamps.clear();
  }
}
