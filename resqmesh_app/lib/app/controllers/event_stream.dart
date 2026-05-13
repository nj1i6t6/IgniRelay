import 'dart:async';
import 'dart:typed_data';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';

class SosAlert {
  final String eventId;
  final int urgency;
  final String description;
  final double? lat;
  final double? lng;
  final DateTime timestamp;
  SosAlert(
      {required this.eventId,
      required this.urgency,
      required this.description,
      this.lat,
      this.lng,
      required this.timestamp});
}

class MatchUpdate {
  final String eventId;
  final int eventType;
  final String? negotiationId;
  final String? resourceId;
  final String? requestId;
  final Object? decodedPayload;
  MatchUpdate(
      {required this.eventId,
      required this.eventType,
      this.negotiationId,
      this.resourceId,
      this.requestId,
      this.decodedPayload});
}

class HazardEvent {
  final String eventId;
  final String type;
  final int severity;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String description;
  HazardEvent(
      {required this.eventId,
      required this.type,
      required this.severity,
      required this.lat,
      required this.lng,
      required this.radiusMeters,
      required this.description});
}

class SupplyChange {
  final String eventId;
  final String resourceType;
  final int quantity;
  final String unit;
  SupplyChange(
      {required this.eventId,
      required this.resourceType,
      required this.quantity,
      required this.unit});
}

class EventStream {
  EventStream({
    required MeshEventHandler handler,
    required EventDecoder decoder,
    required EventStore store,
  })  : _handler = handler,
        _decoder = decoder,
        _store = store;

  final MeshEventHandler _handler;
  final EventDecoder _decoder;
  final EventStore _store;
  StreamSubscription<MeshDataReceived>? _subscription;
  final Set<String> _dispatchedEventIds = <String>{};

  final StreamController<SosAlert> _sosController =
      StreamController<SosAlert>.broadcast();
  final StreamController<MatchUpdate> _matchController =
      StreamController<MatchUpdate>.broadcast();
  final StreamController<HazardEvent> _hazardController =
      StreamController<HazardEvent>.broadcast();
  final StreamController<SupplyChange> _supplyController =
      StreamController<SupplyChange>.broadcast();

  Stream<SosAlert> get sosAlerts => _sosController.stream;
  Stream<MatchUpdate> get matchUpdates => _matchController.stream;
  Stream<HazardEvent> get hazardEvents => _hazardController.stream;
  Stream<SupplyChange> get supplyChanges => _supplyController.stream;

  Stream<MeshDataReceived> get rawEvents => _handler.events;

  List<String> get debugLogs => _handler.debugLogs;

  void start() {
    _subscription ??= _handler.events.listen((_) {
      unawaited(_dispatchRecentEvents());
    });
  }

  Future<void> _dispatchRecentEvents() async {
    final rows = await _store.queryRecent(limit: 50);
    for (final row in rows.reversed) {
      final eventId = row['event_id'] as String? ?? '';
      if (eventId.isEmpty || !_dispatchedEventIds.add(eventId)) continue;

      final eventType = row['event_type'] as int? ?? -1;
      final urgency = row['urgency'] as int? ?? 0;
      final payload = row['payload'] as Uint8List?;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        (row['hlc_timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      );

      switch (eventType) {
        case EventType.requestBroadcast:
          final data =
              payload == null ? null : _decoder.decodeRequestData(payload);
          if (urgency >= 2) {
            _sosController.add(SosAlert(
              eventId: eventId,
              urgency: urgency,
              description: data?.note ?? '',
              lat: row['lat'] as double?,
              lng: row['lng'] as double?,
              timestamp: timestamp,
            ));
          } else if (data != null) {
            _supplyController.add(SupplyChange(
              eventId: eventId,
              resourceType: data.resourceType,
              quantity: data.quantity,
              unit: '',
            ));
          }
          break;
        case EventType.resourceRegister:
          final data =
              payload == null ? null : _decoder.decodeResourceData(payload);
          if (data != null) {
            _supplyController.add(SupplyChange(
              eventId: eventId,
              resourceType: data.resourceType,
              quantity: data.quantity,
              unit: data.unit,
            ));
          }
          break;
        case EventType.hazardMarker:
          final data =
              payload == null ? null : _decoder.decodeHazardData(payload);
          if (data != null) {
            _hazardController.add(HazardEvent(
              eventId: eventId,
              type: data.hazardType,
              severity: data.severity,
              lat: data.centerLat,
              lng: data.centerLng,
              radiusMeters: data.radiusMeters,
              description: data.description,
            ));
          }
          break;
        case EventType.matchOffer:
        case EventType.matchRequest:
        case EventType.matchAccept:
        case EventType.matchDecline:
        case EventType.matchCancel:
        case EventType.physicalHandshake:
        case EventType.handshakeComplete:
        case EventType.locationUpdate:
          _matchController.add(MatchUpdate(
            eventId: eventId,
            eventType: eventType,
            decodedPayload: _decoder.decodeByType(
                eventType, payload ?? const <int>[]),
          ));
          break;
        default:
          break;
      }
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _sosController.close();
    await _matchController.close();
    await _hazardController.close();
    await _supplyController.close();
  }
}
