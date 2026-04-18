import 'package:collection/collection.dart';

class MeshTask {
  final String eventId;
  final int urgency; // 0: INFO, 1: RESOURCE, 2: SOS_YELLOW, 3: SOS_RED
  final int eventType; // EventType enum value (0–6)
  final List<int> payload;

  MeshTask(this.eventId, this.urgency, this.payload, {this.eventType = 0});
}

class TriageQueue {
  static const int maxQueueSize = 500;

  final PriorityQueue<MeshTask> _queue = PriorityQueue<MeshTask>((a, b) {
    // 比較時，urgency 大的優先 (回傳負數代表優先在前面)
    return b.urgency.compareTo(a.urgency);
  });

  /// 加入新任務到佇列（超過上限時移除最低優先級）
  void enqueue(MeshTask task) {
    _queue.add(task);

    // 超限時丟棄最低優先級
    while (_queue.length > maxQueueSize) {
      // PriorityQueue 的 last 不容易取到，改為重建
      // 簡化處理：由於是 max-urgency 優先，我們直接移除
      final all = _queue.toList();
      _queue.clear();
      all.sort((a, b) => b.urgency.compareTo(a.urgency));
      for (int i = 0; i < maxQueueSize && i < all.length; i++) {
        _queue.add(all[i]);
      }
      break;
    }
  }

  /// 取出優先級最高任務
  MeshTask? dequeue() {
    if (_queue.isEmpty) return null;
    return _queue.removeFirst();
  }

  /// 檢查佇列頂端是否為 SOS_RED，以決定是否中斷現有傳輸 (Routing Preemption)
  bool get hasSOSRedPreemptionPending {
    if (_queue.isEmpty) return false;
    return _queue.first.urgency == 3;
  }

  int get length => _queue.length;
  bool get isEmpty => _queue.isEmpty;
}
