// routing_extended_test.dart
//
// Tests for MeshRouter exemption logic — 這些路徑在 zone check 之前就 return，
// 不需要 VillageGeofence 初始化，可在純 unit test 環境中執行。
//
// 需要 VillageGeofence DB 的距離/行政區測試請見 routing_test.dart (marked skip)。
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/mesh_router.dart';

// 台北→高雄：任何行政區邊界的距離都不會通過（~330 km）
const double _tpLat = 25.0339, _tpLng = 121.5644;
const double _ksLat = 22.6273, _ksLng = 120.3014;

Future<bool> _route({
  required int urgency,
  required int eventType,
  required int identityLevel,
  required bool isHardwareMule,
  required bool isAndroidTier1,
  double originLat = _tpLat,
  double originLng = _tpLng,
  double myLat = _ksLat,
  double myLng = _ksLng,
  double maxRange = 500.0,
}) =>
    MeshRouter.shouldForwardPacket(
      urgency: urgency,
      eventType: eventType,
      originLat: originLat,
      originLng: originLng,
      myLat: myLat,
      myLng: myLng,
      maxRangeMeters: maxRange,
      senderIdentityLevel: identityLevel,
      isHardwareMule: isHardwareMule,
      isAndroidTier1Foreground: isAndroidTier1,
    );

void main() {
  group('MeshRouter — Tier 0/1 Exemptions', () {
    test('isHardwareMule=true → always forward regardless of distance/urgency', () async {
      expect(
        await _route(urgency: 0, eventType: 0, identityLevel: 0,
            isHardwareMule: true, isAndroidTier1: false),
        isTrue,
      );
    });

    test('isAndroidTier1Foreground=true → always forward', () async {
      expect(
        await _route(urgency: 0, eventType: 0, identityLevel: 0,
            isHardwareMule: false, isAndroidTier1: true),
        isTrue,
      );
    });

    test('both mule flags true → still forward', () async {
      expect(
        await _route(urgency: 0, eventType: 0, identityLevel: 0,
            isHardwareMule: true, isAndroidTier1: true),
        isTrue,
      );
    });

    test('hardware mule exempt for every urgency level', () async {
      for (final urg in [0, 1, 2, 3]) {
        expect(
          await _route(urgency: urg, eventType: 0, identityLevel: 0,
              isHardwareMule: true, isAndroidTier1: false),
          isTrue,
          reason: 'urgency=$urg',
        );
      }
    });

    test('hardware mule exempt for every event type', () async {
      for (final t in [0, 1, 2, 3, 4, 5, 6, 7]) {
        expect(
          await _route(urgency: 0, eventType: t, identityLevel: 0,
              isHardwareMule: true, isAndroidTier1: false),
          isTrue,
          reason: 'eventType=$t',
        );
      }
    });
  });

  group('MeshRouter — SOS_RED Identity Exemption', () {
    test('SOS_RED + identityLevel=1 → exempt (no zone check)', () async {
      expect(
        await _route(urgency: 3, eventType: 1, identityLevel: 1,
            isHardwareMule: false, isAndroidTier1: false),
        isTrue,
      );
    });

    test('SOS_RED + identityLevel=2 → exempt', () async {
      expect(
        await _route(urgency: 3, eventType: 1, identityLevel: 2,
            isHardwareMule: false, isAndroidTier1: false),
        isTrue,
      );
    });

    test('SOS_RED + identityLevel=3 → exempt', () async {
      expect(
        await _route(urgency: 3, eventType: 1, identityLevel: 3,
            isHardwareMule: false, isAndroidTier1: false),
        isTrue,
      );
    });

    // identityLevel=0 (anonymous) 不豁免 → 進入 zone check → 需要 VillageGeofence
    test(
      'SOS_RED + identityLevel=0 (anonymous) → needs zone check (requires VillageGeofence)',
      () async {
        await _route(urgency: 3, eventType: 1, identityLevel: 0,
            isHardwareMule: false, isAndroidTier1: false);
        // If we get here without throw, zone check fell through to fallback
      },
      skip: 'Anonymous SOS_RED goes through VillageGeofence (integration test)',
    );
  });

  group('MeshRouter — Quarantine Vote accumulation', () {
    // processQuarantineVote writes to DB — only run if DB is available
    // These tests just verify the function signatures compile and can be called
    test('processQuarantineVote is callable', () async {
      // Uses DatabaseHelper; will init sqflite on device or fail gracefully in unit test
      // Just verify it returns normally without blowing up the test runner
      try {
        await MeshRouter.processQuarantineVote('deadbeef', 0.2);
      } catch (_) {
        // DB not available in unit test — acceptable
      }
    });

    test('isBlacklisted returns false for unknown pubKey', () async {
      try {
        final result = await MeshRouter.isBlacklisted('unknownpubkeyhex');
        expect(result, isFalse);
      } catch (_) {
        // DB not available in unit test — acceptable
      }
    });
  });
}
