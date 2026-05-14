import 'package:ignirelay_app/app/mesh/event_manager.dart';

class EventPublisher {
  EventPublisher({required EventManager eventManager})
      : _em = eventManager;

  final EventManager _em;

  Future<String> publishEvent({
    required int urgency,
    required String description,
    double? lat,
    double? lng,
    double maxRangeMeters = 1000.0,
    bool attachMedicalCard = false,
  }) =>
      _em.publishEvent(
        urgency: urgency,
        description: description,
        lat: lat,
        lng: lng,
        maxRangeMeters: maxRangeMeters,
        attachMedicalCard: attachMedicalCard,
      );

  Future<String> publishSupply({
    required String resourceType,
    required int quantity,
    String unit = '份',
    required double maxRangeMeters,
    String deliveryMode = 'PICKUP',
    double? lat,
    double? lng,
  }) =>
      _em.publishSupply(
        resourceType: resourceType,
        quantity: quantity,
        unit: unit,
        maxRangeMeters: maxRangeMeters,
        deliveryMode: deliveryMode,
        lat: lat,
        lng: lng,
      );

  Future<String> publishRequest({
    required String resourceType,
    required int quantity,
    required String note,
    required double maxRangeMeters,
    String mobilityMode = 'CAN_GO',
    double? lat,
    double? lng,
  }) =>
      _em.publishRequest(
        resourceType: resourceType,
        quantity: quantity,
        note: note,
        maxRangeMeters: maxRangeMeters,
        mobilityMode: mobilityMode,
        lat: lat,
        lng: lng,
      );

  Future<String> publishHazard({
    required String type,
    required int severity,
    required double lat,
    required double lng,
    double radiusMeters = 200.0,
    String description = '',
  }) =>
      _em.publishHazard(
        type: type,
        severity: severity,
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        description: description,
      );

  Future<String> publishChatMessage({
    required String roomId,
    required String roomType,
    required String content,
    String? replyTo,
  }) =>
      _em.publishChatMessage(
        roomId: roomId,
        roomType: roomType,
        content: content,
        replyTo: replyTo,
      );

  Future<String?> publishMatchOffer({
    required String resourceId,
    required String requestId,
    required List<int> requesterPubKey,
    required double offeredQty,
    required double matchScore,
  }) =>
      _em.publishMatchOffer(
        resourceId: resourceId,
        requestId: requestId,
        requesterPubKey: requesterPubKey,
        offeredQty: offeredQty,
        matchScore: matchScore,
      );

  Future<String?> publishMatchRequest({
    required String resourceId,
    required String requestId,
    required List<int> providerPubKey,
    required double requestedQty,
  }) =>
      _em.publishMatchRequest(
        resourceId: resourceId,
        requestId: requestId,
        providerPubKey: providerPubKey,
        requestedQty: requestedQty,
      );

  Future<String?> publishMatchAccept({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required double agreedQty,
  }) =>
      _em.publishMatchAccept(
        negotiationId: negotiationId,
        resourceId: resourceId,
        requestId: requestId,
        agreedQty: agreedQty,
      );

  Future<String?> publishMatchDecline({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required String reason,
  }) =>
      _em.publishMatchDecline(
        negotiationId: negotiationId,
        resourceId: resourceId,
        requestId: requestId,
        reason: reason,
      );

  Future<String?> publishHandshakeComplete({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required List<int> providerPubKey,
    required List<int> requesterPubKey,
    required double actualDeliveredQty,
    required String method,
  }) =>
      _em.publishHandshakeComplete(
        negotiationId: negotiationId,
        resourceId: resourceId,
        requestId: requestId,
        providerPubKey: providerPubKey,
        requesterPubKey: requesterPubKey,
        actualDeliveredQty: actualDeliveredQty,
        method: method,
      );

  Future<String?> publishMatchCancel({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required String reason,
  }) =>
      _em.publishMatchCancel(
        negotiationId: negotiationId,
        resourceId: resourceId,
        requestId: requestId,
        reason: reason,
      );

  Future<void> publishLocationUpdate({
    required String negotiationId,
    required double lat,
    required double lng,
  }) =>
      _em.publishLocationUpdate(
        negotiationId: negotiationId,
        lat: lat,
        lng: lng,
      );

  Future<void> cancelSupply(String eventId) => _em.cancelSupply(eventId);
  Future<void> cancelRequest(String eventId) => _em.cancelRequest(eventId);

  Future<List<Map<String, dynamic>>> getActiveHazards() =>
      _em.getActiveHazards();
  Future<String> getReporterHex() => _em.getReporterHex();
  Future<void> confirmHazard(String hazardId) => _em.confirmHazard(hazardId);
  Future<void> updateHazard(
    String hazardId, {
    String? type,
    int? severity,
    double? lat,
    double? lng,
    double? radiusMeters,
    String? description,
  }) =>
      _em.updateHazard(
        hazardId,
        type: type,
        severity: severity,
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        description: description,
      );
  Future<void> deleteHazard(String hazardId) => _em.deleteHazard(hazardId);
  Future<Map<String, dynamic>?> findNearbyHazard(
    double lat,
    double lng,
    String type, {
    double searchRadius = 500.0,
  }) =>
      _em.findNearbyHazard(lat, lng, type, searchRadius: searchRadius);

  /// 啟動時把過期的 match negotiation 標記為失效。對應 EventManager 同名 method，
  /// 提供給 main.dart 取代直接呼叫 `EventManager().expireStaleMatches()` singleton。
  Future<void> expireStaleMatches() => _em.expireStaleMatches();
}
