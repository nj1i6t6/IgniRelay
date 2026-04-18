import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';

void main() {
  // MeshEventHandler 是 singleton，用帶時間戳的 ID 避免跨測試干擾
  final handler = MeshEventHandler();

  group('MeshEventHandler — Deduplication State', () {
    test('hasSeen returns false for unknown event', () {
      final id = 'unknown-${DateTime.now().microsecondsSinceEpoch}';
      expect(handler.hasSeen(id), isFalse);
    });

    test('markSeen makes hasSeen return true', () {
      final id = 'mark-me-${DateTime.now().microsecondsSinceEpoch}';
      expect(handler.hasSeen(id), isFalse);
      handler.markSeen(id);
      expect(handler.hasSeen(id), isTrue);
    });

    test('seenEventsCount increments after each unique markSeen', () {
      final before = handler.seenEventsCount;
      handler.markSeen('count-a-${DateTime.now().microsecondsSinceEpoch}');
      expect(handler.seenEventsCount, equals(before + 1));
      handler.markSeen('count-b-${DateTime.now().microsecondsSinceEpoch}');
      expect(handler.seenEventsCount, equals(before + 2));
    });

    test('marking the same ID twice does not increment count again', () {
      final id = 'double-mark-${DateTime.now().microsecondsSinceEpoch}';
      handler.markSeen(id);
      final count = handler.seenEventsCount;
      handler.markSeen(id); // 重複
      expect(handler.seenEventsCount, equals(count));
    });

    test('different IDs are tracked independently', () {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final id1 = 'ind-a-$ts';
      final id2 = 'ind-b-$ts';
      handler.markSeen(id1);
      expect(handler.hasSeen(id1), isTrue);
      expect(handler.hasSeen(id2), isFalse);
    });

    test('seenEventsCount is non-negative', () {
      expect(handler.seenEventsCount, greaterThanOrEqualTo(0));
    });
  });
}
