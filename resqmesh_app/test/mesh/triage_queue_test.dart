import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/triage_queue.dart';

void main() {
  late TriageQueue queue;

  setUp(() {
    queue = TriageQueue();
  });

  group('TriageQueue — Priority Ordering', () {
    test('dequeue returns highest urgency first', () {
      queue.enqueue(MeshTask('info', 0, []));    // INFO
      queue.enqueue(MeshTask('red', 3, []));     // SOS_RED
      queue.enqueue(MeshTask('res', 1, []));     // RESOURCE
      queue.enqueue(MeshTask('yel', 2, []));     // SOS_YELLOW

      expect(queue.dequeue()?.urgency, equals(3)); // SOS_RED
      expect(queue.dequeue()?.urgency, equals(2)); // SOS_YELLOW
      expect(queue.dequeue()?.urgency, equals(1)); // RESOURCE
      expect(queue.dequeue()?.urgency, equals(0)); // INFO
    });

    test('all four urgency levels can be inserted and dequeued in order', () {
      for (final urg in [0, 3, 1, 2]) {
        queue.enqueue(MeshTask('u$urg', urg, []));
      }
      final urgencies = <int>[];
      while (!queue.isEmpty) {
        urgencies.add(queue.dequeue()!.urgency);
      }
      expect(urgencies, equals([3, 2, 1, 0]));
    });

    test('same urgency: both items dequeued', () {
      queue.enqueue(MeshTask('red-a', 3, []));
      queue.enqueue(MeshTask('red-b', 3, []));
      final first = queue.dequeue();
      final second = queue.dequeue();
      expect({first?.eventId, second?.eventId}, containsAll(['red-a', 'red-b']));
    });

    test('empty queue: dequeue returns null', () {
      expect(queue.dequeue(), isNull);
    });

    test('isEmpty reflects queue state correctly', () {
      expect(queue.isEmpty, isTrue);
      queue.enqueue(MeshTask('x', 0, []));
      expect(queue.isEmpty, isFalse);
      queue.dequeue();
      expect(queue.isEmpty, isTrue);
    });

    test('length tracks item count', () {
      expect(queue.length, equals(0));
      queue.enqueue(MeshTask('a', 1, []));
      expect(queue.length, equals(1));
      queue.enqueue(MeshTask('b', 2, []));
      expect(queue.length, equals(2));
      queue.dequeue();
      expect(queue.length, equals(1));
    });

    test('payload bytes are preserved through enqueue/dequeue', () {
      final payload = [0x01, 0x02, 0x03];
      queue.enqueue(MeshTask('payload-test', 1, payload));
      final task = queue.dequeue();
      expect(task?.payload, equals(payload));
    });
  });

  group('TriageQueue — SOS_RED Preemption Flag', () {
    test('no SOS_RED: flag is false', () {
      queue.enqueue(MeshTask('info', 0, []));
      queue.enqueue(MeshTask('res', 1, []));
      expect(queue.hasSOSRedPreemptionPending, isFalse);
    });

    test('SOS_RED enqueued: flag becomes true', () {
      queue.enqueue(MeshTask('info', 0, []));
      queue.enqueue(MeshTask('red', 3, []));
      expect(queue.hasSOSRedPreemptionPending, isTrue);
    });

    test('after SOS_RED dequeued and no more: flag is false', () {
      queue.enqueue(MeshTask('red', 3, []));
      queue.enqueue(MeshTask('info', 0, []));
      expect(queue.hasSOSRedPreemptionPending, isTrue);
      queue.dequeue(); // removes SOS_RED (highest)
      expect(queue.hasSOSRedPreemptionPending, isFalse);
    });

    test('two SOS_RED: flag still true after first is dequeued', () {
      queue.enqueue(MeshTask('red-1', 3, []));
      queue.enqueue(MeshTask('red-2', 3, []));
      queue.dequeue();
      expect(queue.hasSOSRedPreemptionPending, isTrue);
    });

    test('empty queue: flag is false', () {
      expect(queue.hasSOSRedPreemptionPending, isFalse);
    });
  });

  group('TriageQueue — Overflow Handling', () {
    test('queue size capped at maxQueueSize after overflow', () {
      // 300 low-priority + 100 high-priority + 101 more low → triggers overflow
      for (int i = 0; i < 400; i++) {
        queue.enqueue(MeshTask('low-$i', 0, []));
      }
      for (int i = 0; i < 100; i++) {
        queue.enqueue(MeshTask('high-$i', 3, []));
      }
      // This push triggers the overflow trim
      queue.enqueue(MeshTask('overflow-trigger', 0, []));

      expect(queue.length, equals(TriageQueue.maxQueueSize));
    });

    test('after overflow, highest urgency items survive', () {
      for (int i = 0; i < 450; i++) {
        queue.enqueue(MeshTask('low-$i', 0, []));
      }
      for (int i = 0; i < 51; i++) {
        queue.enqueue(MeshTask('high-$i', 3, []));
      }
      // First dequeued item should be urgency 3
      expect(queue.dequeue()?.urgency, equals(3));
    });
  });
}
