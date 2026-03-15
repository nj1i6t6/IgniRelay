import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:uuid/uuid.dart';
import '../proto/mesh_protocol.pb.dart';
import '../crdt/hlc.dart';
import '../crypto/identity_manager.dart';
import '../crypto/signer.dart';

/// 統一的 Protobuf 事件序列化 / 反序列化工具
/// 取代原本的 String 拼接方式，使用真正的 Protobuf 二進位編碼
class EventSerializer {
  static const _uuid = Uuid();

  // ── 序列化 ResourceData → MeshEvent bytes ──────────────────────

  static Future<SerializedEvent> buildResourceEvent({
    required String resourceId,
    required String resourceType,
    required String description,
    required double quantity,
    required String unit,
    required double maxRangeMeters,
    double? lat,
    double? lng,
  }) async {
    final resourceData = ResourceData(
      resourceId: resourceId,
      resourceType: resourceType,
      description: description,
      quantity: quantity,
      unit: unit,
      maxRangeMeters: maxRangeMeters,
      lat: lat ?? 0.0,
      lng: lng ?? 0.0,
    );

    return _buildMeshEvent(
      eventType: EventType.RESOURCE_REGISTER,
      urgency: UrgencyLevel.RESOURCE,
      payloadBytes: resourceData.writeToBuffer(),
      lat: lat,
      lng: lng,
    );
  }

  // ── 序列化 RequestData → MeshEvent bytes ───────────────────────

  static Future<SerializedEvent> buildRequestEvent({
    required String requestId,
    required String resourceType,
    required String description,
    required double quantityNeeded,
    required int urgencyInt,
    double? lat,
    double? lng,
    double maxRangeMeters = 1000.0,
  }) async {
    final urgency = UrgencyLevel.valueOf(urgencyInt) ?? UrgencyLevel.SOS_YELLOW;
    final requestData = RequestData(
      requestId: requestId,
      resourceType: resourceType,
      description: description,
      quantityNeeded: quantityNeeded,
      urgency: urgency,
      lat: lat ?? 0.0,
      lng: lng ?? 0.0,
      maxRangeMeters: maxRangeMeters,
    );

    return _buildMeshEvent(
      eventType: EventType.REQUEST_BROADCAST,
      urgency: urgency,
      payloadBytes: requestData.writeToBuffer(),
      lat: lat,
      lng: lng,
    );
  }

  // ── 序列化 HazardData → MeshEvent bytes ────────────────────────

  static Future<SerializedEvent> buildHazardEvent({
    required String hazardId,
    required String hazardType,
    required int severity,
    required double lat,
    required double lng,
    double radiusMeters = 200.0,
  }) async {
    final hazardData = HazardData(
      hazardId: hazardId,
      hazardType: hazardType,
      severity: severity,
      centerLat: lat,
      centerLng: lng,
      radiusMeters: radiusMeters,
      observedAt: Int64(DateTime.now().millisecondsSinceEpoch),
    );

    return _buildMeshEvent(
      eventType: EventType.HAZARD_MARKER,
      urgency: UrgencyLevel.SOS_YELLOW,
      payloadBytes: hazardData.writeToBuffer(),
      lat: lat,
      lng: lng,
    );
  }

  // ── 序列化 PhysicalHandshakeData → MeshEvent bytes ─────────────

  static Future<SerializedEvent> buildHandshakeEvent({
    required String resourceId,
    required String requestId,
    required List<int> requesterPubKey,
    required List<int> providerPubKey,
    required List<int> requesterSignature,
    required List<int> providerSignature,
    String method = 'PIN_4DIGIT',
  }) async {
    final handshakeData = PhysicalHandshakeData(
      resourceId: resourceId,
      requestId: requestId,
      requesterPubKey: requesterPubKey,
      providerPubKey: providerPubKey,
      requesterSignature: requesterSignature,
      providerSignature: providerSignature,
      method: method,
    );

    return _buildMeshEvent(
      eventType: EventType.PHYSICAL_HANDSHAKE,
      urgency: UrgencyLevel.RESOURCE,
      payloadBytes: handshakeData.writeToBuffer(),
    );
  }

  // ── 序列化 QuarantineVoteData → MeshEvent bytes ────────────────

  static Future<SerializedEvent> buildQuarantineVoteEvent({
    required List<int> targetPubKey,
    required String reason,
    required double voteWeight,
  }) async {
    final voteData = QuarantineVoteData(
      targetPubKey: targetPubKey,
      reason: reason,
      voteWeight: voteWeight,
    );

    return _buildMeshEvent(
      eventType: EventType.QUARANTINE_VOTE,
      urgency: UrgencyLevel.INFO,
      payloadBytes: voteData.writeToBuffer(),
    );
  }

  // ── 反序列化 MeshEvent ─────────────────────────────────────────

  static MeshEvent? decodeMeshEvent(List<int> bytes) {
    try {
      return MeshEvent.fromBuffer(bytes);
    } catch (e) {
      return null;
    }
  }

  /// 從 MeshEvent 的 payload 解析出 ResourceData
  static ResourceData? decodeResourceData(MeshEvent event) {
    if (event.type != EventType.RESOURCE_REGISTER) return null;
    try {
      return ResourceData.fromBuffer(event.payload);
    } catch (_) {
      return null;
    }
  }

  /// 從 MeshEvent 的 payload 解析出 RequestData
  static RequestData? decodeRequestData(MeshEvent event) {
    if (event.type != EventType.REQUEST_BROADCAST) return null;
    try {
      return RequestData.fromBuffer(event.payload);
    } catch (_) {
      return null;
    }
  }

  /// 從 MeshEvent 的 payload 解析出 HazardData
  static HazardData? decodeHazardData(MeshEvent event) {
    if (event.type != EventType.HAZARD_MARKER) return null;
    try {
      return HazardData.fromBuffer(event.payload);
    } catch (_) {
      return null;
    }
  }

  /// 從 MeshEvent 的 payload 解析出 PhysicalHandshakeData
  static PhysicalHandshakeData? decodeHandshakeData(MeshEvent event) {
    if (event.type != EventType.PHYSICAL_HANDSHAKE) return null;
    try {
      return PhysicalHandshakeData.fromBuffer(event.payload);
    } catch (_) {
      return null;
    }
  }

  // ── Internal ───────────────────────────────────────────────────

  static Future<SerializedEvent> _buildMeshEvent({
    required EventType eventType,
    required UrgencyLevel urgency,
    required List<int> payloadBytes,
    double? lat,
    double? lng,
  }) async {
    final eventId = _uuid.v4();
    final hlc = HLC.now();
    final pubKeyBytes = await IdentityManager().getPublicKeyBytes();
    final signature = await Signer.signPayload(payloadBytes);

    final meshEvent = MeshEvent(
      eventId: eventId,
      senderPubKey: pubKeyBytes,
      identityLevel: IdentityManager().getIdentityLevel(),
      type: eventType,
      urgency: urgency,
      hlcTimestamp: Int64(hlc.timestamp),
      hlcCounter: Int64(hlc.counter),
      ttl: 10,
      chunkIndex: 0,
      totalChunks: 1,
      payload: payloadBytes,
      signature: signature,
      receivedLat: lat ?? 0.0,
      receivedLng: lng ?? 0.0,
    );

    return SerializedEvent(
      eventId: eventId,
      meshEventBytes: Uint8List.fromList(meshEvent.writeToBuffer()),
      payloadBytes: Uint8List.fromList(payloadBytes),
      signatureBytes: Uint8List.fromList(signature),
      hlcTimestamp: hlc.timestamp,
      hlcCounter: hlc.counter,
      eventType: eventType.value,
      urgencyInt: urgency.value,
      pubKeyBytes: Uint8List.fromList(pubKeyBytes),
    );
  }
}

/// 序列化後的事件結果（含所有需要寫入 DB 和 TriageQueue 的欄位）
class SerializedEvent {
  final String eventId;
  final Uint8List meshEventBytes;
  final Uint8List payloadBytes;
  final Uint8List signatureBytes;
  final int hlcTimestamp;
  final int hlcCounter;
  final int eventType;
  final int urgencyInt;
  final Uint8List pubKeyBytes;

  SerializedEvent({
    required this.eventId,
    required this.meshEventBytes,
    required this.payloadBytes,
    required this.signatureBytes,
    required this.hlcTimestamp,
    required this.hlcCounter,
    required this.eventType,
    required this.urgencyInt,
    required this.pubKeyBytes,
  });
}
