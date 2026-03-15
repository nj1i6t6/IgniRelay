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
  static HLC merge(HLC remote) {
    final nowTs = DateTime.now().millisecondsSinceEpoch;
    final local = _current;

    // 取本地時間、本地 HLC 紀錄、外部 HLC 三者中最大值
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
}
