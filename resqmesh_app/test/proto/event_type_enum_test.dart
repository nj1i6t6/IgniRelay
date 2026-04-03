import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/proto/mesh_protocol.pbenum.dart';

void main() {
  group('EventType enum — extended match/hazard sync', () {
    test('valueOf(0..15) all return non-null', () {
      for (var i = 0; i <= 15; i++) {
        final et = EventType.valueOf(i);
        expect(et, isNotNull,
            reason: 'EventType.valueOf($i) should not be null');
        expect(et!.value, equals(i));
      }
    });

    test('HAZARD_CONFIRM is value 14', () {
      expect(EventType.HAZARD_CONFIRM.value, equals(14));
      expect(EventType.valueOf(14), equals(EventType.HAZARD_CONFIRM));
    });

    test('MATCH_LOCATION_UPDATE is value 15', () {
      expect(EventType.MATCH_LOCATION_UPDATE.value, equals(15));
      expect(EventType.valueOf(15), equals(EventType.MATCH_LOCATION_UPDATE));
    });

    test('values list contains all 16 entries', () {
      expect(EventType.values.length, equals(16));
    });

    test('valueOf(16) returns null (out of range)', () {
      expect(EventType.valueOf(16), isNull);
    });
  });
}
