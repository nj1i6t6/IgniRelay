import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_app/mesh/mesh_router.dart';
import 'package:resqmesh_app/mesh/triage_queue.dart';

void main() {
  group('Mesh Routing: Adaptive Geo Fencing', () {
    test('Should forward if within normal distance', () async {
      // Taipei 101 to nearby
      final bool result = await MeshRouter.shouldForwardPacket(
        urgency: 0, // INFO
        receivedLat: 25.033964,
        receivedLng: 121.564468,
        originLat: 25.034000,
        originLng: 121.565000,
        maxRangeMeters: 500.0, // Should be within 500m
        senderIdentityLevel: 1,
        isHardwareMule: false,
        isAndroidTier1Foreground: false,
      );
      
      expect(result, isTrue);
    });

    test('Should DROP if outside distance', () async {
      // Taipei to Kaohsiung
      final bool result = await MeshRouter.shouldForwardPacket(
        urgency: 0, // INFO
        receivedLat: 22.6273, // Kaohsiung
        receivedLng: 120.3014,
        originLat: 25.0339, // Taipei
        originLng: 121.5644,
        maxRangeMeters: 1000.0, // 1km max
        senderIdentityLevel: 1,
        isHardwareMule: false,
        isAndroidTier1Foreground: false,
      );
      
      expect(result, isFalse);
    });

    test('SOS_RED from Identity Level 1 should be fully exempt from distance', () async {
      // Taipei to Kaohsiung (Should FORWARD due to SOS_RED exemption)
      final bool result = await MeshRouter.shouldForwardPacket(
        urgency: 3, // SOS_RED
        receivedLat: 22.6273, // Kaohsiung
        receivedLng: 120.3014,
        originLat: 25.0339, // Taipei
        originLng: 121.5644,
        maxRangeMeters: 1000.0, // Initially 1km max (should be ignored)
        senderIdentityLevel: 1, // Reaching threshold for absolute exemption
        isHardwareMule: false,
        isAndroidTier1Foreground: false,
      );
      
      expect(result, isTrue);
    });

    test('Hardware Data Mule should be fully exempt from distance', () async {
      final bool result = await MeshRouter.shouldForwardPacket(
        urgency: 0, // INFO
        receivedLat: 22.6273, 
        receivedLng: 120.3014,
        originLat: 25.0339, 
        originLng: 121.5644,
        maxRangeMeters: 500.0,
        senderIdentityLevel: 0,
        isHardwareMule: true, // EXEMPTION
        isAndroidTier1Foreground: false,
      );
      
      expect(result, isTrue);
    });
  });

  group('Triage Queue QoS', () {
    test('Queue should order by highest priority first', () {
      final queue = TriageQueue();
      queue.enqueue(MeshTask("1", 0, [])); // INFO
      queue.enqueue(MeshTask("2", 3, [])); // SOS_RED
      queue.enqueue(MeshTask("3", 1, [])); // RESOURCE

      // First out should be urgency 3
      expect(queue.dequeue()?.eventId, equals("2"));
      // Next should be 1
      expect(queue.dequeue()?.eventId, equals("3"));
      // Next should be 0
      expect(queue.dequeue()?.eventId, equals("1"));
    });

    test('SOS_RED triggers preemption flag', () {
      final queue = TriageQueue();
      queue.enqueue(MeshTask("1", 0, [])); // INFO
      expect(queue.hasSOSRedPreemptionPending, isFalse);

      queue.enqueue(MeshTask("2", 3, [])); // SOS_RED
      // Flag should now be true
      expect(queue.hasSOSRedPreemptionPending, isTrue);
    });
  });
}
