// V2InboundProjector — projects accepted EventEnvelope v2 (receive path) into
// the v1 `Event_Logs` read-model so `EventStream` / UI can see v2-received
// events.
//
// WHY THIS EXISTS
//
// The v2 receive path (BleV2Bridge → EnvelopeDispatcherV2 → EnvelopeStoreV2)
// terminates in `Envelopes_V2` and never writes `Event_Logs`, which is the
// ONLY table `EventStream` reads. Without this adapter, anything received over
// the v0.3 wire is invisible to the UI. This class bridges that gap during the
// v1→v2 migration window. It is the explicit, deletable "v2 → v1 read-model"
// seam: when v1 is finally retired and the UI reads the v2 store directly,
// delete this file.
//
// TRANSLATION (only the UI-surfaced types are projected)
//
//   • CHAT_MESSAGE   (v2 30 → v1 13): the v2 payload is already the same JSON
//     shape v1 chat uses ({room_id, room_type, content, reply_to}); passthrough.
//   • HAZARD_MARKER  (v2 50 → v1 4):  the v2 wire carries hazard as a JSON shim
//     (`hazard_marker_v0_3_json_shim`, see event_publisher.dart); rebuilt into a
//     v1 `pb.HazardData` proto so the existing Hazards_State projection +
//     EventStream.hazardEvents decode unchanged.
//   • STATUS_UPDATE  (v2 1): SOS-class only (safetyState TRAPPED/INJURED) →
//     v1 requestBroadcast SOS, matching how the legacy path models SOS. Non-SOS
//     status (SAFE/UNSAFE) has no v1 UI surface yet (the v0.3 Now/status tab)
//     and is skipped.
//
// IDEMPOTENCY
//
// The v1 `event_id` is derived deterministically from the 16-byte envelope_id
// ("v2-" + hex). Re-projecting the same envelope is a no-op because
// MeshEventHandler dedups on `event_id` (memory LRU + DB).
//
// MIGRATION NOTE — DOUBLE DISPLAY DURING DUAL-WRITE
//
// The four v2-eligible types are still DUAL-WRITTEN on the legacy v1 wire (see
// EventPublisher). While dual-write is on, a received event arrives on BOTH
// wires with DIFFERENT ids, so it will surface twice. Disabling the per-type v1
// dual-write (the migration step) removes the duplicate. This projector is the
// prerequisite that makes such a per-type v2-only migration safe.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

import 'package:ignirelay_app/app/controllers/envelope_dispatcher_v2.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;

class V2InboundProjector {
  V2InboundProjector({
    required Stream<DispatchOutcome> outcomes,
    required MeshEventHandler handler,
  })  : _outcomes = outcomes,
        _handler = handler;

  final Stream<DispatchOutcome> _outcomes;
  final MeshEventHandler _handler;
  StreamSubscription<DispatchOutcome>? _sub;

  /// Emits the v1 `event_id` after each successful projection. Test-only
  /// signal so unit tests can deterministically await a projection instead of
  /// polling the DB.
  final StreamController<String> _projected =
      StreamController<String>.broadcast();

  @visibleForTesting
  Stream<String> get projectedEventIds => _projected.stream;

  /// Begin consuming dispatcher outcomes. Idempotent.
  void start() {
    _sub ??= _outcomes.listen((o) {
      if (o is DispatchAccepted) {
        unawaited(_project(o));
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _projected.close();
  }

  static String eventIdOf(Uint8List envelopeId) {
    final hex =
        envelopeId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    // Prefix marks the row as a read-model-only projection so v1 outbound /
    // sync paths can exclude it (see MeshEventHandler.v2ProjectionIdPrefix).
    return '${MeshEventHandler.v2ProjectionIdPrefix}$hex';
  }

  Future<void> _project(DispatchAccepted accepted) async {
    final env = accepted.envelope;
    final eventId = eventIdOf(env.envelopeId);
    try {
      switch (env.eventType) {
        case EventTypeV2.chatMessage:
          await _projectChat(accepted, eventId);
          break;
        case EventTypeV2.hazardMarker:
          await _projectHazard(accepted, eventId);
          break;
        case EventTypeV2.statusUpdate:
          await _projectStatus(accepted, eventId);
          break;
        default:
          // Not a UI-surfaced type (supply / match / official / control);
          // nothing to project into the v1 read-model.
          break;
      }
    } catch (e) {
      debugPrint('[V2Projector] project failed for $eventId: $e');
    }
  }

  Future<void> _ingest({
    required String eventId,
    required int v1EventType,
    required int urgency,
    required List<int> payload,
    required DispatchAccepted accepted,
    double? lat,
    double? lng,
  }) async {
    final env = accepted.envelope;
    await _handler.ingestVerifiedEvent(
      eventId: eventId,
      eventType: v1EventType,
      urgency: urgency,
      payload: payload,
      senderPubKey: env.authorKey,
      hlcTimestamp: env.createdAtHlc.msSinceEpoch,
      hlcCounter: env.createdAtHlc.counter,
      ttl: env.maxHops,
      lat: lat,
      lng: lng,
      sourceNodeId: accepted.peerId ?? 'v2',
    );
    if (!_projected.isClosed) _projected.add(eventId);
  }

  Future<void> _projectChat(DispatchAccepted a, String eventId) async {
    // v2 chat payload is already the v1 chat JSON shape; pass it through.
    await _ingest(
      eventId: eventId,
      v1EventType: EventType.chatMessage,
      urgency: 0,
      payload: a.envelope.payload,
      accepted: a,
    );
  }

  Future<void> _projectHazard(DispatchAccepted a, String eventId) async {
    final decoded = jsonDecode(utf8.decode(a.envelope.payload));
    if (decoded is! Map) return;
    final j = Map<String, dynamic>.from(decoded);
    final lat = (j['lat'] as num?)?.toDouble() ?? 0;
    final lng = (j['lng'] as num?)?.toDouble() ?? 0;
    // _handleHazardEvent requires non-zero coordinates to project.
    if (lat == 0 || lng == 0) return;
    final hazard = pb.HazardData()
      ..hazardId = eventId
      ..hazardType = (j['type'] as String?) ?? 'UNKNOWN'
      ..severity = (j['severity'] as num?)?.toInt() ?? 1
      ..centerLat = lat
      ..centerLng = lng
      ..radiusMeters = (j['radius_m'] as num?)?.toDouble() ?? 200.0
      ..observedAt = fixnum.Int64(a.envelope.createdAtHlc.msSinceEpoch)
      ..description = (j['description'] as String?) ?? ''
      ..isConfirmation = false;
    await _ingest(
      eventId: eventId,
      v1EventType: EventType.hazardMarker,
      urgency: 0,
      payload: hazard.writeToBuffer(),
      accepted: a,
      lat: lat,
      lng: lng,
    );
  }

  Future<void> _projectStatus(DispatchAccepted a, String eventId) async {
    final s = StatusUpdateData.decode(a.envelope.payload);
    // Stage 0.5 SCOPE: urgency is derived from safetyState ONLY. The spec
    // §5.3 priority floor also raises an URGENT `need` (while SAFE) to
    // SOS_YELLOW; we deliberately DO NOT project that here, because "safe but
    // urgently needs water" belongs on the v0.3 status/needs surface (Now
    // tab), not shoehorned into the v1 SOS list. TODO(v0.3 Now tab): project
    // needs-based urgency once that read-model exists. Until then such updates
    // are intentionally invisible to the v1 read-model.
    final urgency = _safetyStateToUrgency(s.safetyState);
    if (urgency < 2) {
      // Non-SOS status (SAFE / UNSAFE) has no v1 UI surface yet (v0.3 Now tab).
      debugPrint(
          '[V2Projector] skip non-SOS status safetyState=${s.safetyState}');
      return;
    }
    // Represent as a v1 SOS (requestBroadcast + urgency>=2), matching how the
    // legacy path models SOS. StatusUpdateData carries no location.
    final req = pb.RequestData()
      ..requestId = eventId
      ..resourceType = ''
      ..quantityNeeded = 0
      ..note = _noteForSafetyState(s.safetyState)
      ..mobilityMode = 'CAN_GO';
    await _ingest(
      eventId: eventId,
      v1EventType: EventType.requestBroadcast,
      urgency: urgency,
      payload: req.writeToBuffer(),
      accepted: a,
    );
  }

  static int _safetyStateToUrgency(int safetyState) {
    switch (safetyState) {
      case SafetyState.trapped:
        return 3;
      case SafetyState.injured:
        return 2;
      case SafetyState.unsafe:
        return 1;
      default:
        return 0;
    }
  }

  static String _noteForSafetyState(int safetyState) {
    switch (safetyState) {
      case SafetyState.trapped:
        return '受困';
      case SafetyState.injured:
        return '受傷';
      default:
        return 'SOS';
    }
  }
}
