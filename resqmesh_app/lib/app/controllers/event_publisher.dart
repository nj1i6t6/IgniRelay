import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/event_publisher_v2_facade.dart';

/// EventPublisher — UI/app-layer facade over [EventManager] (legacy v0.2
/// publish path) with optional dual-write to [EventPublisherV2Facade]
/// (v0.3 wire path).
///
/// Stage 0c wave 3E-r2: the dual-write hook is wired so that the four
/// v2-eligible event types (SOS / STATUS_UPDATE, HAZARD_MARKER, CHAT) are
/// actually emitted on the v0.3 wire whenever a v2 facade is injected.
/// Existing UI call sites continue to call the legacy methods on this
/// class unchanged — no per-screen migration required for the 0d gate.
///
/// IMPORTANT for tests: `v2Facade` is optional. Existing harnesses that
/// construct `EventPublisher(eventManager: EventManager())` keep working
/// (they simply skip the dual-write step). main.dart wires both.
class EventPublisher {
  EventPublisher({
    required EventManager eventManager,
    EventPublisherV2Facade? v2Facade,
  })  : _em = eventManager,
        _v2 = v2Facade;

  final EventManager _em;
  final EventPublisherV2Facade? _v2;

  /// Map legacy "urgency" (0..3+) to spec §5.3 SafetyState enum.
  ///
  /// Legacy `publishEvent` overloads multiple semantics into one
  /// integer ("triage urgency" 0=info, 1=watch, 2=help, 3=critical),
  /// while the v2 STATUS_UPDATE payload exposes the structured safety
  /// state directly. This mapping is the smallest faithful translation;
  /// callers that want richer needs[] semantics should use the facade
  /// directly.
  ///
  /// Wave 3E-r3 — priority is NOT derived here. The facade applies the
  /// spec §5.3 implied-priority floor (`StatusUpdateData.
  /// impliedPriorityFloor()`) based on the safety state we set, so:
  /// `urgency >= 3` (TRAPPED) → facade emits at SOS_RED; `urgency == 2`
  /// (INJURED) → facade emits at SOS_YELLOW. The previous 3E-r2 code
  /// passed `priority: STATUS` for everything below urgency 3, which
  /// silently violated §5.3 for INJURED.
  static int _legacyUrgencyToSafetyState(int urgency) {
    if (urgency >= 3) return SafetyState.trapped;
    if (urgency == 2) return SafetyState.injured;
    if (urgency == 1) return SafetyState.unsafe;
    return SafetyState.safe; // 0 / cancel
  }

  Future<String> publishEvent({
    required int urgency,
    required String description,
    double? lat,
    double? lng,
    double maxRangeMeters = 1000.0,
    bool attachMedicalCard = false,
  }) async {
    final id = await _em.publishEvent(
      urgency: urgency,
      description: description,
      lat: lat,
      lng: lng,
      maxRangeMeters: maxRangeMeters,
      attachMedicalCard: attachMedicalCard,
    );
    _dualWriteStatusUpdate(urgency: urgency);
    return id;
  }

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
  }) async {
    final id = await _em.publishHazard(
      type: type, severity: severity, lat: lat, lng: lng,
      radiusMeters: radiusMeters, description: description,
    );
    _dualWriteHazardMarker(
      type: type,
      severity: severity,
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      description: description,
    );
    return id;
  }

  Future<String> publishChatMessage({
    required String roomId,
    required String roomType,
    required String content,
    String? replyTo,
  }) async {
    final id = await _em.publishChatMessage(
      roomId: roomId,
      roomType: roomType,
      content: content,
      replyTo: replyTo,
    );
    _dualWriteChatMessage(
      roomId: roomId,
      roomType: roomType,
      content: content,
      replyTo: replyTo,
    );
    return id;
  }

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

  // ── v0.3 dual-write helpers (Stage 0c wave 3E-r2) ─────────────────────
  //
  // These never throw to the caller: the v2 facade is fire-and-forget so
  // a wire-side failure never blocks the legacy v0.2 publish (which is
  // still the authoritative local-write path). Errors are debug-logged.

  void _dualWriteStatusUpdate({required int urgency}) {
    final v2 = _v2;
    if (v2 == null) return;
    final safetyState = _legacyUrgencyToSafetyState(urgency);
    // Always go through publishStatusUpdate; the facade applies the
    // §5.3 implied-priority floor based on safetyState/needs, so we
    // never need to pre-decide SOS_RED vs SOS_YELLOW vs STATUS here.
    final fut = v2.publishStatusUpdate(safetyState: safetyState);
    unawaited(fut.catchError((Object e, StackTrace s) {
      debugPrint('[EventPublisher] v2 publishStatusUpdate failed: $e');
      // Synthetic outcome — never observed by callers because we ignore
      // the future, but keeps the type signature honest.
      return BroadcastOutcome.noActivePeers();
    }));
  }

  void _dualWriteHazardMarker({
    required String type,
    required int severity,
    required double lat,
    required double lng,
    required double radiusMeters,
    required String description,
  }) {
    final v2 = _v2;
    if (v2 == null) return;
    // v2 HazardMarkerData proto is not yet defined (tracked in the
    // facade's docstring as v0.4 follow-up). Until then, encode a
    // forward-compatible JSON blob that hazard_marker decoders can
    // upgrade to the typed proto without breaking the wire signature.
    final json = jsonEncode(<String, dynamic>{
      'type': type,
      'severity': severity,
      'lat': lat,
      'lng': lng,
      'radius_m': radiusMeters,
      'description': description,
      'schema': 'hazard_marker_v0_3_json_shim',
    });
    final payload = Uint8List.fromList(utf8.encode(json));
    unawaited(v2
        .publishHazardMarker(payload: payload)
        .catchError((Object e, StackTrace s) {
      debugPrint('[EventPublisher] v2 publishHazardMarker failed: $e');
      return BroadcastOutcome.noActivePeers();
    }));
  }

  void _dualWriteChatMessage({
    required String roomId,
    required String roomType,
    required String content,
    String? replyTo,
  }) {
    final v2 = _v2;
    if (v2 == null) return;
    final json = jsonEncode(<String, dynamic>{
      'room_id': roomId,
      'room_type': roomType,
      'content': content,
      if (replyTo != null) 'reply_to': replyTo,
    });
    final payload = Uint8List.fromList(utf8.encode(json));
    unawaited(v2
        .publishChatMessage(payload: payload)
        .catchError((Object e, StackTrace s) {
      debugPrint('[EventPublisher] v2 publishChatMessage failed: $e');
      return BroadcastOutcome.noActivePeers();
    }));
  }
}
