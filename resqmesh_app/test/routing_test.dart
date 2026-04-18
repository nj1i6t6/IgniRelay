import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/mesh_router.dart';
import 'package:ignirelay_app/app/mesh/triage_queue.dart';

void main() {
  group('Mesh Routing: Exemption Paths (no VillageGeofence needed)', () {
    test('SOS_RED from Identity Level 1 is fully exempt (no zone check)', () async {
      // 台北 → 高雄：距離遠超任何行政區邊界
      // 但 SOS_RED + identityLevel >= 1 在 zone check 之前就直接 return true
      final bool result = await MeshRouter.shouldForwardPacket(
        urgency: 3, // SOS_RED
        eventType: 1,
        originLat: 25.0339, // 台北
        originLng: 121.5644,
        myLat: 22.6273, // 高雄
        myLng: 120.3014,
        maxRangeMeters: 1000.0,
        senderIdentityLevel: 1, // L1 驗證用戶 → 豁免
        isHardwareMule: false,
        isAndroidTier1Foreground: false,
      );
      expect(result, isTrue);
    });

    test('Hardware Data Mule is fully exempt (no zone check)', () async {
      final bool result = await MeshRouter.shouldForwardPacket(
        urgency: 0, // INFO
        eventType: 0,
        originLat: 25.0339,
        originLng: 121.5644,
        myLat: 22.6273,
        myLng: 120.3014,
        maxRangeMeters: 500.0,
        senderIdentityLevel: 0,
        isHardwareMule: true, // 豁免
        isAndroidTier1Foreground: false,
      );
      expect(result, isTrue);
    });

    test('Android Tier 1 Foreground is fully exempt (no zone check)', () async {
      final bool result = await MeshRouter.shouldForwardPacket(
        urgency: 0,
        eventType: 0,
        originLat: 25.0339,
        originLng: 121.5644,
        myLat: 22.6273,
        myLng: 120.3014,
        maxRangeMeters: 500.0,
        senderIdentityLevel: 0,
        isHardwareMule: false,
        isAndroidTier1Foreground: true, // 豁免
      );
      expect(result, isTrue);
    });

    test('SOS_RED identity level 2 is exempt', () async {
      final bool result = await MeshRouter.shouldForwardPacket(
        urgency: 3,
        eventType: 1,
        originLat: 25.0,
        originLng: 121.0,
        myLat: 23.0,
        myLng: 120.0,
        maxRangeMeters: 100.0,
        senderIdentityLevel: 2,
        isHardwareMule: false,
        isAndroidTier1Foreground: false,
      );
      expect(result, isTrue);
    });

    test('SOS_RED identity level 3 is exempt', () async {
      final bool result = await MeshRouter.shouldForwardPacket(
        urgency: 3,
        eventType: 1,
        originLat: 25.0,
        originLng: 121.0,
        myLat: 23.0,
        myLng: 120.0,
        maxRangeMeters: 100.0,
        senderIdentityLevel: 3,
        isHardwareMule: false,
        isAndroidTier1Foreground: false,
      );
      expect(result, isTrue);
    });

    // NOTE: 以下測試需要 VillageGeofence 初始化（geodata asset），
    // 僅在 integration test 環境下可跑。在 unit test 中略過。
    test(
      'INFO within village distance → forward (needs VillageGeofence)',
      () async {
        final bool result = await MeshRouter.shouldForwardPacket(
          urgency: 0,
          eventType: 0,
          originLat: 25.034000,
          originLng: 121.565000,
          myLat: 25.033964,
          myLng: 121.564468,
          maxRangeMeters: 500.0,
          senderIdentityLevel: 1,
          isHardwareMule: false,
          isAndroidTier1Foreground: false,
        );
        expect(result, isTrue);
      },
      skip: 'Requires VillageGeofence.init() with geodata asset (integration test)',
    );

    test(
      'INFO Taipei→Kaohsiung → drop (needs VillageGeofence)',
      () async {
        final bool result = await MeshRouter.shouldForwardPacket(
          urgency: 0,
          eventType: 0,
          originLat: 25.0339,
          originLng: 121.5644,
          myLat: 22.6273,
          myLng: 120.3014,
          maxRangeMeters: 1000.0,
          senderIdentityLevel: 1,
          isHardwareMule: false,
          isAndroidTier1Foreground: false,
        );
        expect(result, isFalse);
      },
      skip: 'Requires VillageGeofence.init() with geodata asset (integration test)',
    );
  });

  group('Triage Queue QoS', () {
    test('Queue should order by highest priority first', () {
      final queue = TriageQueue();
      queue.enqueue(MeshTask('1', 0, [])); // INFO
      queue.enqueue(MeshTask('2', 3, [])); // SOS_RED
      queue.enqueue(MeshTask('3', 1, [])); // RESOURCE

      expect(queue.dequeue()?.eventId, equals('2')); // SOS_RED 最先
      expect(queue.dequeue()?.eventId, equals('3')); // RESOURCE
      expect(queue.dequeue()?.eventId, equals('1')); // INFO 最後
    });

    test('SOS_RED triggers preemption flag', () {
      final queue = TriageQueue();
      queue.enqueue(MeshTask('1', 0, []));
      expect(queue.hasSOSRedPreemptionPending, isFalse);

      queue.enqueue(MeshTask('2', 3, []));
      expect(queue.hasSOSRedPreemptionPending, isTrue);
    });
  });
}
