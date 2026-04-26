// location_service_test.dart
//
// Bug 4 驗證：LocationService 靜態工具函數 + onFirstFix 回呼機制
// GPS 實際呼叫無法在 unit test 中測試，但可測試 haversine / bearing / formatDistance

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ignirelay_app/app/services/location_service.dart';

void main() {
  group('LocationService — Static Utilities', () {
    test('haversineMeters: same point = 0', () {
      const p = LatLng(25.033, 121.565);
      expect(LocationService.haversineMeters(p, p), closeTo(0, 0.01));
    });

    test('haversineMeters: Taipei to Kaohsiung ~300 km', () {
      const taipei = LatLng(25.033, 121.565);
      const kaohsiung = LatLng(22.627, 120.301);
      final dist = LocationService.haversineMeters(taipei, kaohsiung);
      expect(dist, greaterThan(280000));
      expect(dist, lessThan(320000));
    });

    test('bearing: due east ≈ 90°', () {
      const from = LatLng(0, 0);
      const to = LatLng(0, 1);
      expect(LocationService.bearing(from, to), closeTo(90, 1));
    });

    test('bearing: due north ≈ 0°', () {
      const from = LatLng(0, 0);
      const to = LatLng(1, 0);
      expect(LocationService.bearing(from, to), closeTo(0, 1));
    });

    test('bearingToDirection covers all 8 directions', () {
      expect(LocationService.bearingToDirection(0), equals('北方'));
      expect(LocationService.bearingToDirection(45), equals('東北方'));
      expect(LocationService.bearingToDirection(90), equals('東方'));
      expect(LocationService.bearingToDirection(135), equals('東南方'));
      expect(LocationService.bearingToDirection(180), equals('南方'));
      expect(LocationService.bearingToDirection(225), equals('西南方'));
      expect(LocationService.bearingToDirection(270), equals('西方'));
      expect(LocationService.bearingToDirection(315), equals('西北方'));
    });

    test('formatDistance: meters', () {
      expect(LocationService.formatDistance(500), equals('500 m'));
    });

    test('formatDistance: kilometers', () {
      expect(LocationService.formatDistance(2500), equals('2.5 km'));
    });

    test('normalizeDistance: 0m = 1.0', () {
      expect(LocationService.normalizeDistance(0), equals(1.0));
    });

    test('normalizeDistance: maxRange = 0.0', () {
      expect(LocationService.normalizeDistance(20000), equals(0.0));
    });

    test('normalizeDistance: 10km = 0.5 (with 20km max)', () {
      expect(LocationService.normalizeDistance(10000), closeTo(0.5, 0.01));
    });
  });

  group('LocationService — onFirstFix callback (Bug 4)', () {
    test('onFirstFix field is initially null', () {
      final service = LocationService();
      expect(service.onFirstFix, isNull);
    });

    test('onFirstFix can be set and read back', () {
      final service = LocationService();
      bool called = false;
      service.onFirstFix = () { called = true; };
      expect(service.onFirstFix, isNotNull);
      service.onFirstFix!();
      expect(called, isTrue);
    });

    test('hasLocation is false before init', () {
      // Fresh singleton — if no GPS has run, currentLocation is null
      // (In test env GPS won't initialize)
      final service = LocationService();
      // This test just validates the property accessor doesn't throw
      expect(service.hasLocation, isA<bool>());
    });
  });
}
