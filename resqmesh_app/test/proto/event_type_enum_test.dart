// event_type_enum_test.dart
//
// Bug 1 驗證：Protobuf EventType enum 0–13 全部可解析
// 確保 valueOf() 不回傳 null（之前 8–13 缺失導致 chatMessage 被編碼為 type=0）

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/proto/mesh_protocol.pbenum.dart';

void main() {
  group('EventType enum — Bug 1 regression', () {
    test('valueOf(0..13) all return non-null', () {
      for (var i = 0; i <= 13; i++) {
        final et = EventType.valueOf(i);
        expect(et, isNotNull, reason: 'EventType.valueOf($i) should not be null');
        expect(et!.value, equals(i));
      }
    });

    test('CHAT_MESSAGE is value 13', () {
      expect(EventType.CHAT_MESSAGE.value, equals(13));
      expect(EventType.valueOf(13), equals(EventType.CHAT_MESSAGE));
    });

    test('MATCH_CONFIRM through MATCH_GONE are 8–12', () {
      expect(EventType.MATCH_CONFIRM.value, equals(8));
      expect(EventType.MATCH_REJECT.value, equals(9));
      expect(EventType.MATCH_INQUIRY.value, equals(10));
      expect(EventType.MATCH_AVAILABLE.value, equals(11));
      expect(EventType.MATCH_GONE.value, equals(12));
    });

    test('values list contains all 15 entries', () {
      expect(EventType.values.length, equals(15));
    });

    test('valueOf(14) returns LOCATION_UPDATE', () {
      expect(EventType.valueOf(14), equals(EventType.LOCATION_UPDATE));
    });

    test('valueOf(15) returns null (out of range)', () {
      expect(EventType.valueOf(15), isNull);
    });
  });
}
