import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';

void main() {
  group('Bloom Filter — parseBloomFilter', () {
    test('single event ID parsed', () {
      const id = 'aabb-1234-5678-9000';
      final bytes = Uint8List.fromList(utf8.encode(id));
      expect(MeshEventHandler.parseBloomFilter(bytes), equals({id}));
    });

    test('multiple newline-separated IDs parsed as set', () {
      const ids = ['id-001', 'id-002', 'id-003'];
      final bytes = Uint8List.fromList(utf8.encode(ids.join('\n')));
      expect(MeshEventHandler.parseBloomFilter(bytes), equals(ids.toSet()));
    });

    test('empty bytes → empty set', () {
      expect(MeshEventHandler.parseBloomFilter(Uint8List(0)), isEmpty);
    });

    test('trailing newline is ignored', () {
      final bytes = Uint8List.fromList(utf8.encode('id-a\nid-b\n'));
      expect(MeshEventHandler.parseBloomFilter(bytes), equals({'id-a', 'id-b'}));
    });

    test('whitespace-only lines are ignored', () {
      final bytes = Uint8List.fromList(utf8.encode('id-a\n   \nid-b'));
      expect(MeshEventHandler.parseBloomFilter(bytes), equals({'id-a', 'id-b'}));
    });

    test('duplicate IDs are deduplicated', () {
      final bytes = Uint8List.fromList(utf8.encode('id-dup\nid-dup\nid-other'));
      final result = MeshEventHandler.parseBloomFilter(bytes);
      expect(result.length, equals(2));
      expect(result, containsAll(['id-dup', 'id-other']));
    });

    test('50 UUID-format IDs all present', () {
      final ids = List.generate(
        50,
        (i) => 'aaaaaaaa-bbbb-cccc-dddd-${i.toString().padLeft(12, '0')}',
      );
      final bytes = Uint8List.fromList(utf8.encode(ids.join('\n')));
      final result = MeshEventHandler.parseBloomFilter(bytes);
      expect(result.length, equals(50));
      for (final id in ids) {
        expect(result.contains(id), isTrue, reason: 'Missing $id');
      }
    });

    test('known ID present, unknown ID absent', () {
      final bytes = Uint8List.fromList(utf8.encode('id-known'));
      final result = MeshEventHandler.parseBloomFilter(bytes);
      expect(result.contains('id-known'), isTrue);
      expect(result.contains('id-unknown'), isFalse);
    });

    test('CRLF line endings handled gracefully', () {
      final bytes = Uint8List.fromList(utf8.encode('id-a\r\nid-b\r\n'));
      final result = MeshEventHandler.parseBloomFilter(bytes);
      // After trim(), '\r' gets stripped; both IDs should be present
      expect(result.length, greaterThanOrEqualTo(2));
    });
  });
}
