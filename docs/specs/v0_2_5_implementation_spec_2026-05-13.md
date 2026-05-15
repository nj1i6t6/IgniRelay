# v0.2.5 Implementation Spec — Technical Debt & Architecture Hardening

Date: 2026-05-13
Source brief: `text/resqmesh_v0.2.5_tech_debt_architecture_hardening_brief_2026-05-13.md`
Status: READY FOR IMPLEMENTATION — reviewed for v0.2.5 handoff
Package: `ignirelay_app` (Flutter, Dart >=3.2.0)
Current version: 0.2.0+30

---

## Table of Contents

1. [Scope & Constraints](#1-scope--constraints)
2. [Stage 1: Protocol Boundary Facade](#2-stage-1-protocol-boundary-facade)
   - 2.1 New Files & Exact APIs
   - 2.2 Existing File Extensions
   - 2.3 UI Migration Order (13 files, 4 waves)
   - 2.4 `app/mesh/` Directory Cleanup
   - 2.5 `platform/` Cleanup
   - 2.6 Stage 1 Commit Plan
   - 2.7 Stage 1 Rollback Plan
   - 2.8 Stage 1 Test Plan
   - 2.9 Stage 1 Acceptance Criteria
3. [Stage 2A: UI God File Splits (Critical Path)](#3-stage-2a-ui-god-file-splits-critical-path)
   - 3.1 station_supply_screen.dart
   - 3.2 match_screen.dart
   - 3.3 physical_handoff.dart
   - 3.4 survival_mode_screen.dart
   - 3.5 Stage 2A Commit Plan
   - 3.6 Stage 2A Rollback Plan
   - 3.7 Stage 2A Test Plan
   - 3.8 Stage 2A Acceptance Criteria
4. [Stage 2B: UI God File Splits (Parallel)](#4-stage-2b-ui-god-file-splits-parallel)
   - 4.1 medical_card_screen.dart
   - 4.2 profile_screen.dart
   - 4.3 Stage 2B Commit Plan
   - 4.4 Stage 2B Rollback Plan
   - 4.5 Stage 2B Test Plan
   - 4.6 Stage 2B Acceptance Criteria
5. [Stage 3: CI Enforcement](#5-stage-3-ci-enforcement)
6. [Stage 4: Wire-Format Golden Tests](#6-stage-4-wire-format-golden-tests)
7. [Stage 5: Documentation](#7-stage-5-documentation)
8. [Cross-Stage Testing Matrix](#8-cross-stage-testing-matrix)
9. [Completion Criteria Checklist](#9-completion-criteria-checklist)
10. [Out-of-Scope Confirmations](#10-out-of-scope-confirmations)

---

## 1. Scope & Constraints

- **No new features.** v0.2.5 is debt-only.
- **No behavior changes.** All existing tests must pass before and after each commit.
- **No protocol redesign.** Wire format stays as-is. EventType/proto mismatch (15-18) is deferred to v0.3.
- **No mesh-layer god-file splits.** `event_manager.dart`, `mesh_event_handler.dart`, `ble_manager.dart` are NOT split in v0.2.5.
- **No generated-file edits.** `lib/app/proto/*.pb*.dart` and `lib/l10n/generated/*` are not touched.
- **Use raw `wc -l`** for all line-count references.
- **Controller/View/Repository pattern** follows `map_screen_controller.dart` as reference.
- **No new singleton entry points.** Newly added v0.2.5 facades, repositories, and controllers must NOT expose `.instance`, private singleton constructors, or factory-singleton constructors. They use constructor injection, are constructed at the app root, and are exposed to UI through Provider. Existing legacy singletons may be passed in as dependencies, but must not leak into UI or new public APIs. See §2.1.0 for DI wiring.
- **No UI direct access to legacy singletons.** Existing singleton classes may remain internally, but `lib/ui/` must not call `.instance`, `EventManager()`, `MeshEventHandler()`, `DatabaseHelper()`, `LocationService()`, `ChatService()`, or other app-layer singleton constructors directly after v0.2.5. UI receives app-layer dependencies through Provider or injected controllers/facades only.

### Stage Ordering

```text
Stage 1: Protocol boundary facade
  -> 1A: Create facades & repos (new files)
  -> 1B: Migrate UI callsites (4 waves)
  -> 1C: Move map/geo files from app/mesh/
  -> 1D: Move transport files from platform/

Stage 2A: UI god file splits (critical path, after Stage 1)
  -> station_supply_screen split
  -> match_screen audit + split
  -> physical_handoff split
  -> survival_mode_screen split

Stage 2B: UI god file splits (can overlap 2A end or v0.3 Stage 0)
  -> medical_card_screen split
  -> profile_screen split

Stage 3: CI enforcement (after Stage 1+2 complete)
Stage 4: Wire-format golden tests (independent, can run in parallel)
Stage 5: Documentation (after all stages)
```

---

## 2. Stage 1: Protocol Boundary Facade

### 2.1 New Files & Exact APIs

#### 2.1.0 DI Wiring Pattern

All new facades/repos/controllers created by v0.2.5 are regular injectable classes. They must have public constructors with explicit dependencies and must NOT define `static final instance`, private singleton constructors, or factory constructors that hide a singleton.

Register all facades/repos as `Provider` at the app root in `main.dart`. The app root owns dependency construction. UI obtains dependencies with `context.read<T>()`.

`main.dart` root wiring is the only permitted place in v0.2.5 to touch legacy singleton entry points for dependency registration. Do not copy `EventManager()`, `DatabaseHelper()`, `LocationService()`, `ChatService()`, or `*.instance` access into UI files or feature controllers. Feature controllers receive the registered dependency through constructors.

```dart
// main.dart — startup wiring (excerpt)
MultiProvider(
  providers: [
    Provider<EventDecoder>(
      create: (_) => EventDecoder(),
    ),
    Provider<EventPublisher>(
      create: (_) => EventPublisher(eventManager: EventManager()),
    ),
    Provider<EventStore>(
      create: (_) => EventStore(databaseHelper: DatabaseHelper()),
    ),
    Provider<StationSupplyRepo>(
      create: (_) => StationSupplyRepo(databaseHelper: DatabaseHelper()),
    ),
    Provider<ProfileRepo>(
      create: (_) => ProfileRepo(databaseHelper: DatabaseHelper()),
    ),
    // NegotiationRepo already exists as a legacy factory singleton.
    // UI still receives it through Provider, not by constructing it directly.
    Provider<NegotiationRepo>(
      create: (_) => NegotiationRepo(),
    ),
    // Existing legacy services/controllers are exposed through Provider
    // only at the app root, so UI stops calling singleton entry points directly.
    Provider<ChatService>(
      create: (_) => ChatService(),
    ),
    Provider<LocationService>(
      create: (_) => LocationService(),
    ),
    Provider<DeviceInfoController>(
      create: (_) => DeviceInfoController.instance,
    ),
    Provider<BleScanController>(
      create: (_) => BleScanController.instance,
    ),
    Provider<MeshRuntimeController>(
      create: (_) => MeshRuntimeController.instance,
    ),
    Provider<EmergencyModeController>(
      create: (_) => EmergencyModeController.instance,
    ),
    Provider<HandoffController>(
      create: (_) => HandoffController.instance,
    ),
    Provider<EventStream>(
      create: (context) => EventStream(
        handler: MeshEventHandler(),
        decoder: context.read<EventDecoder>(),
        store: context.read<EventStore>(),
      )..start(),
      dispose: (_, stream) => stream.dispose(),
    ),
  ],
  child: MaterialApp(...)
)
```

**UI access pattern** (all files):

```dart
// In any widget or State:
final publisher = context.read<EventPublisher>();
await publisher.publishHazard(...);
```

**App-layer access pattern** (controllers, services — NOT UI):

```dart
class StationSupplyController extends ChangeNotifier {
  StationSupplyController({
    required EventPublisher publisher,
    required StationSupplyRepo repo,
  })  : _publisher = publisher,
        _repo = repo;

  final EventPublisher _publisher;
  final StationSupplyRepo _repo;
}
```

**Rule summary**:
| Layer | Allowed access | Forbidden access |
|---|---|---|
| `lib/ui/` | `context.read<EventPublisher>()`, injected controllers/facades/services | `.instance`, `EventManager()`, `MeshEventHandler()`, `DatabaseHelper()`, other app-layer singleton constructors |
| `lib/app/controllers/` | constructor-injected `EventPublisher` | `EventPublisher.instance` |
| `lib/app/services/` | constructor-injected collaborators | `EventPublisher.instance` |
| `main.dart` root wiring | may wrap legacy singleton instances in Provider | creating new v0.2.5 facade/repo/controller singletons |

This means the `check_layers` CI rule `ui-cannot-import-mesh` catches the layer boundary, while constructor injection + root Provider wiring prevents newly added global entry points from replacing the old direct coupling.

#### 2.1.1 `app/controllers/event_publisher.dart` (NEW)

Wraps all `EventManager().publish*()` calls. UI imports this instead of `app/mesh/event_manager.dart`.

```dart
import 'package:ignirelay_app/app/mesh/event_manager.dart';

class EventPublisher {
  EventPublisher({required EventManager eventManager})
      : _em = eventManager;

  final EventManager _em;

  /// Publish a general SOS/event.
  /// Returns the event ID string.
  Future<String> publishEvent({
    required int urgency,
    required String description,
    double? lat,
    double? lng,
    double maxRangeMeters = 1000.0,
    bool attachMedicalCard = false,
  }) => _em.publishEvent(
    urgency: urgency,
    description: description,
    lat: lat,
    lng: lng,
    maxRangeMeters: maxRangeMeters,
    attachMedicalCard: attachMedicalCard,
  );

  /// Publish a supply offer.
  Future<String> publishSupply({
    required String resourceType,
    required int quantity,
    String unit = '份',
    required double maxRangeMeters,
    String deliveryMode = 'PICKUP',
    double? lat,
    double? lng,
  }) => _em.publishSupply(
    resourceType: resourceType,
    quantity: quantity,
    unit: unit,
    maxRangeMeters: maxRangeMeters,
    deliveryMode: deliveryMode,
    lat: lat,
    lng: lng,
  );

  /// Publish a resource request.
  Future<String> publishRequest({
    required String resourceType,
    required int quantity,
    required String note,
    required double maxRangeMeters,
    String mobilityMode = 'CAN_GO',
    double? lat,
    double? lng,
  }) => _em.publishRequest(
    resourceType: resourceType,
    quantity: quantity,
    note: note,
    maxRangeMeters: maxRangeMeters,
    mobilityMode: mobilityMode,
    lat: lat,
    lng: lng,
  );

  /// Publish a hazard marker.
  Future<String> publishHazard({
    required String type,
    required int severity,
    required double lat,
    required double lng,
    double radiusMeters = 200.0,
    String description = '',
  }) => _em.publishHazard(
    type: type,
    severity: severity,
    lat: lat,
    lng: lng,
    radiusMeters: radiusMeters,
    description: description,
  );

  /// Publish a chat message.
  Future<String> publishChatMessage({
    required String roomId,
    required String roomType,
    required String content,
    String? replyTo,
  }) => _em.publishChatMessage(
    roomId: roomId,
    roomType: roomType,
    content: content,
    replyTo: replyTo,
  );

  /// Match negotiation methods.
  Future<String?> publishMatchOffer({
    required String resourceId,
    required String requestId,
    required List<int> requesterPubKey,
    required double offeredQty,
    required double matchScore,
  }) => _em.publishMatchOffer(
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
  }) => _em.publishMatchRequest(
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
  }) => _em.publishMatchAccept(
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
  }) => _em.publishMatchDecline(
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
  }) => _em.publishHandshakeComplete(
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
  }) => _em.publishMatchCancel(
    negotiationId: negotiationId,
    resourceId: resourceId,
    requestId: requestId,
    reason: reason,
  );

  Future<void> publishLocationUpdate({
    required String negotiationId,
    required double lat,
    required double lng,
  }) => _em.publishLocationUpdate(
    negotiationId: negotiationId,
    lat: lat,
    lng: lng,
  );

  /// Cancel a supply or request.
  Future<void> cancelSupply(String eventId) => _em.cancelSupply(eventId);
  Future<void> cancelRequest(String eventId) => _em.cancelRequest(eventId);

  /// Hazard read operations (delegated to HazardManager inside EventManager).
  Future<List<Map<String, dynamic>>> getActiveHazards() => _em.getActiveHazards();
  Future<String> getReporterHex() => _em.getReporterHex();
  Future<void> confirmHazard(String hazardId) => _em.confirmHazard(hazardId);
  Future<void> updateHazard(String hazardId, {String? type, int? severity, double? lat, double? lng, double? radiusMeters, String? description})
    => _em.updateHazard(hazardId, type: type, severity: severity, lat: lat, lng: lng, radiusMeters: radiusMeters, description: description);
  Future<void> deleteHazard(String hazardId) => _em.deleteHazard(hazardId);
}
```

**Return types**: All methods return `Future<String>` (event ID) or `Future<String?>` (match methods) or `Future<void>`. No protobuf types leak.

**UI replacement mapping** (all via `context.read<EventPublisher>()` — see §2.1.0):

| UI file | Old call | New call |
|---|---|---|
| `hazard_dialog.dart:35` | `EventManager().publishHazard(...)` | `context.read<EventPublisher>().publishHazard(...)` |
| `supply_registration.dart:74` | `_eventManager.publishSupply(...)` | `context.read<EventPublisher>().publishSupply(...)` |
| `resource_request_sheet.dart:67` | `_eventManager.publishRequest(...)` | `context.read<EventPublisher>().publishRequest(...)` |
| `station_supply_screen.dart:218,1244` | `EventManager().publishSupply/cancelSupply` | `context.read<EventPublisher>().publishSupply/cancelSupply(...)` |
| `match_screen.dart:49,448-597` | `_eventManager.*` (8 calls) | `context.read<EventPublisher>().*(...)` |
| `navigation_screen.dart:39` | `_eventManager = EventManager()` | `context.read<EventPublisher>()` |
| `physical_handoff.dart:45` | `_eventManager = EventManager()` | `context.read<EventPublisher>()` |
| `survival_mode_screen.dart:82` | `EventManager().getRecentEvents(...)` | `context.read<EventStore>().queryRecent(...)` |

**Note**: `survival_mode_screen.dart:82` uses `EventStore.queryRecent()` (not EventPublisher) because `getRecentEvents` is a read query, not a publish action.

#### 2.1.2 `app/controllers/event_stream.dart` (NEW)

Wraps `MeshEventHandler().events` and exposes typed, decoded streams. UI subscribes to this instead of raw `MeshDataReceived`.

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';

/// Typed domain events emitted by EventStream.
class SosAlert {
  final String eventId;
  final int urgency;
  final String description;
  final double? lat;
  final double? lng;
  final DateTime timestamp;
  SosAlert({required this.eventId, required this.urgency, required this.description, this.lat, this.lng, required this.timestamp});
}

class MatchUpdate {
  final String eventId;
  final int eventType;
  final String? negotiationId;
  final String? resourceId;
  final String? requestId;
  final Object? decodedPayload;
  MatchUpdate({required this.eventId, required this.eventType, this.negotiationId, this.resourceId, this.requestId, this.decodedPayload});
}

class HazardEvent {
  final String eventId;
  final String type;
  final int severity;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String description;
  HazardEvent({required this.eventId, required this.type, required this.severity, required this.lat, required this.lng, required this.radiusMeters, required this.description});
}

class SupplyChange {
  final String eventId;
  final String resourceType;
  final int quantity;
  final String unit;
  SupplyChange({required this.eventId, required this.resourceType, required this.quantity, required this.unit});
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

  // Typed broadcast streams
  final StreamController<SosAlert> _sosController = StreamController<SosAlert>.broadcast();
  final StreamController<MatchUpdate> _matchController = StreamController<MatchUpdate>.broadcast();
  final StreamController<HazardEvent> _hazardController = StreamController<HazardEvent>.broadcast();
  final StreamController<SupplyChange> _supplyController = StreamController<SupplyChange>.broadcast();

  Stream<SosAlert> get sosAlerts => _sosController.stream;
  Stream<MatchUpdate> get matchUpdates => _matchController.stream;
  Stream<HazardEvent> get hazardEvents => _hazardController.stream;
  Stream<SupplyChange> get supplyChanges => _supplyController.stream;

  /// Raw stream passthrough for debug screens ONLY.
  /// SURVIVAL_MODE_SCREEN is the only permitted consumer.
  /// All production UI must use typed streams above.
  /// Will be removed in v0.3.
  Stream<MeshDataReceived> get rawEvents => _handler.events;

  /// In-memory debug logs from MeshEventHandler (debug screen only).
  List<String> get debugLogs => _handler.debugLogs;

  /// Initialize subscription. Call once at app startup.
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
          final data = payload == null ? null : _decoder.decodeRequestData(payload);
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
          final data = payload == null ? null : _decoder.decodeResourceData(payload);
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
          final data = payload == null ? null : _decoder.decodeHazardData(payload);
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
            decodedPayload: _decoder.decodeByType(eventType, payload ?? const <int>[]),
          ));
          break;
        default:
          // chatMessage, deprecated, and unknown event types are intentionally ignored by v0.2.5 typed UI streams.
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
```

**Dispatch table**:

| EventType | Typed stream | Notes |
|---|---|---|
| `requestBroadcast` with `urgency >= 2` | `sosAlerts` | Main shell alert path |
| `requestBroadcast` with `urgency < 2` | `supplyChanges` | Resource request path |
| `resourceRegister` | `supplyChanges` | Supply offer path |
| `hazardMarker` | `hazardEvents` | Map hazard updates |
| `matchOffer`, `matchRequest`, `matchAccept`, `matchDecline`, `matchCancel`, `physicalHandshake`, `handshakeComplete`, `locationUpdate` | `matchUpdates` | Match / navigation / handoff refresh path |
| `chatMessage`, deprecated types, unknown types | ignored by typed streams | Chat screens keep their own `ChatService` path in v0.2.5 |

**UI replacement mapping** (via `context.read<EventStream>()` — see §2.1.0):

| UI file | Old code | New code |
|---|---|---|
| `main_shell.dart:77` | `MeshEventHandler().events.listen(...)` | `context.read<EventStream>().sosAlerts.listen(...)` or `matchUpdates.listen(...)` (typed stream — see note) |
| `navigation_screen.dart:97` | `MeshEventHandler().events.listen(...)` | `context.read<EventStream>().matchUpdates.listen(...)` (typed stream) |
| `match_screen.dart:80` | `MeshEventHandler().events.listen(...)` | `context.read<EventStream>().matchUpdates.listen(...)` (typed stream) |
| `survival_mode_screen.dart:111` | `MeshEventHandler().events.listen(...)` | `context.read<EventStream>().rawEvents.listen(...)` (**debug-only exception**) |
| `survival_mode_screen.dart:311-312` | `MeshEventHandler().debugLogs` | `context.read<EventStream>().debugLogs` (**debug-only exception**) |

**Note on typed streams**: `main_shell.dart:77` currently subscribes to ALL mesh events and dispatches by EventType internally. After migration, it subscribes to multiple typed streams (`sosAlerts`, `matchUpdates`, `hazardEvents`) instead of one raw stream. This may require refactoring the event-dispatch switch in `main_shell.dart` into separate listeners per typed stream.

**Forbidden**: No production UI file may use `rawEvents`. The `rawEvents` getter is restricted to `survival_mode_screen.dart` (debug page). If a new screen needs raw access, add a typed stream instead.

| Allowed in production UI | Forbidden in production UI |
|---|---|
| `sosAlerts` | `rawEvents` |
| `matchUpdates` | |
| `hazardEvents` | |
| `supplyChanges` | |

#### 2.1.3 `app/services/event_decoder.dart` (NEW)

All `pb.X.fromBuffer(...)` calls live here. Returns plain Dart objects, never protobuf types.

```dart
import 'dart:typed_data';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;

/// Plain Dart data classes (no protobuf dependency).
class RequestData {
  final String resourceType;
  final int quantity;
  final String note;
  final String mobilityMode;
  RequestData({required this.resourceType, required this.quantity, required this.note, required this.mobilityMode});
}

class MatchOfferData {
  final String resourceId;
  final String requestId;
  final List<int> requesterPubKey;
  final double offeredQty;
  final double matchScore;
  MatchOfferData({required this.resourceId, required this.requestId, required this.requesterPubKey, required this.offeredQty, required this.matchScore});
}

class MatchRequestData {
  final String resourceId;
  final String requestId;
  final List<int> providerPubKey;
  final double requestedQty;
  MatchRequestData({required this.resourceId, required this.requestId, required this.providerPubKey, required this.requestedQty});
}

class ResourceData {
  final String resourceType;
  final int quantity;
  final String unit;
  final String deliveryMode;
  ResourceData({required this.resourceType, required this.quantity, required this.unit, required this.deliveryMode});
}

class HazardDataDecoded {
  final String hazardId;
  final String hazardType;
  final int severity;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final int observedAt;
  final String description;
  final bool isConfirmation;
  HazardDataDecoded({
    required this.hazardId,
    required this.hazardType,
    required this.severity,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.observedAt,
    required this.description,
    required this.isConfirmation,
  });
}

class MatchOfferDecoded {
  final String negotiationId;
  final String resourceId;
  final String requestId;
  final double agreedQty;
  MatchOfferDecoded({required this.negotiationId, required this.resourceId, required this.requestId, required this.agreedQty});
}

class MatchDeclineDecoded {
  final String negotiationId;
  final String resourceId;
  final String requestId;
  final String reason;
  MatchDeclineDecoded({required this.negotiationId, required this.resourceId, required this.requestId, required this.reason});
}

class HandshakeCompleteDecoded {
  final String negotiationId;
  final String resourceId;
  final String requestId;
  final List<int> providerPubKey;
  final List<int> requesterPubKey;
  final double actualDeliveredQty;
  final String method;
  HandshakeCompleteDecoded({
    required this.negotiationId,
    required this.resourceId,
    required this.requestId,
    required this.providerPubKey,
    required this.requesterPubKey,
    required this.actualDeliveredQty,
    required this.method,
  });
}

class MatchCancelDecoded {
  final String negotiationId;
  final String resourceId;
  final String requestId;
  final String reason;
  MatchCancelDecoded({
    required this.negotiationId,
    required this.resourceId,
    required this.requestId,
    required this.reason,
  });
}

class EventDecoder {
  EventDecoder();

  RequestData? decodeRequestData(List<int> payload) {
    try {
      final pb.RequestData rd = pb.RequestData.fromBuffer(payload);
      return RequestData(resourceType: rd.resourceType, quantity: rd.quantity, note: rd.note, mobilityMode: rd.mobilityMode);
    } catch (_) { return null; }
  }

  MatchOfferData? decodeMatchOfferData(List<int> payload) {
    try {
      final pb.MatchOfferData d = pb.MatchOfferData.fromBuffer(payload);
      return MatchOfferData(resourceId: d.resourceId, requestId: d.requestId, requesterPubKey: d.requesterPubKey, offeredQty: d.offeredQty, matchScore: d.matchScore);
    } catch (_) { return null; }
  }

  MatchRequestData? decodeMatchRequestData(List<int> payload) {
    try {
      final pb.MatchRequestData d = pb.MatchRequestData.fromBuffer(payload);
      return MatchRequestData(resourceId: d.resourceId, requestId: d.requestId, providerPubKey: d.providerPubKey, requestedQty: d.requestedQty);
    } catch (_) { return null; }
  }

  ResourceData? decodeResourceData(List<int> payload) {
    try {
      final pb.ResourceData d = pb.ResourceData.fromBuffer(payload);
      return ResourceData(resourceType: d.resourceType, quantity: d.quantity, unit: d.unit, deliveryMode: d.deliveryMode);
    } catch (_) { return null; }
  }

  HazardDataDecoded? decodeHazardData(List<int> payload) {
    try {
      final pb.HazardData d = pb.HazardData.fromBuffer(payload);
      return HazardDataDecoded(
        hazardId: d.hazardId,
        hazardType: d.hazardType,
        severity: d.severity,
        centerLat: d.centerLat,
        centerLng: d.centerLng,
        radiusMeters: d.radiusMeters,
        observedAt: d.observedAt.toInt(),
        description: d.description,
        isConfirmation: d.isConfirmation,
      );
    } catch (_) { return null; }
  }

  MatchOfferDecoded? decodeMatchAccept(List<int> payload) {
    try {
      final pb.MatchAcceptData d = pb.MatchAcceptData.fromBuffer(payload);
      return MatchOfferDecoded(negotiationId: d.negotiationId, resourceId: d.resourceId, requestId: d.requestId, agreedQty: d.agreedQty);
    } catch (_) { return null; }
  }

  MatchDeclineDecoded? decodeMatchDecline(List<int> payload) {
    try {
      final pb.MatchDeclineData d = pb.MatchDeclineData.fromBuffer(payload);
      return MatchDeclineDecoded(negotiationId: d.negotiationId, resourceId: d.resourceId, requestId: d.requestId, reason: d.reason);
    } catch (_) { return null; }
  }

  HandshakeCompleteDecoded? decodeHandshakeComplete(List<int> payload) {
    try {
      final pb.HandshakeCompleteData d = pb.HandshakeCompleteData.fromBuffer(payload);
      return HandshakeCompleteDecoded(negotiationId: d.negotiationId, resourceId: d.resourceId, requestId: d.requestId, providerPubKey: d.providerPubKey, requesterPubKey: d.requesterPubKey, actualDeliveredQty: d.actualDeliveredQty, method: d.method);
    } catch (_) { return null; }
  }

  MatchCancelDecoded? decodeMatchCancel(List<int> payload) {
    try {
      final pb.MatchCancelData d = pb.MatchCancelData.fromBuffer(payload);
      return MatchCancelDecoded(negotiationId: d.negotiationId, resourceId: d.resourceId, requestId: d.requestId, reason: d.reason);
    } catch (_) { return null; }
  }

  Object? decodeByType(int eventType, List<int> payload) {
    switch (eventType) {
      case EventType.resourceRegister:
        return decodeResourceData(payload);
      case EventType.requestBroadcast:
        return decodeRequestData(payload);
      case EventType.hazardMarker:
        return decodeHazardData(payload);
      case EventType.matchOffer:
        return decodeMatchOfferData(payload);
      case EventType.matchRequest:
        return decodeMatchRequestData(payload);
      case EventType.matchAccept:
        return decodeMatchAccept(payload);
      case EventType.matchDecline:
        return decodeMatchDecline(payload);
      case EventType.matchCancel:
        return decodeMatchCancel(payload);
      case EventType.handshakeComplete:
        return decodeHandshakeComplete(payload);
      default:
        return null;
    }
  }
}
```

**UI replacement mapping** (via `context.read<EventDecoder>()` — see §2.1.0):

| UI file | Old code | New code |
|---|---|---|
| `main_shell.dart:111` | `pb.RequestData.fromBuffer(payload)` | `context.read<EventDecoder>().decodeRequestData(payload)` |
| `main_shell.dart:154` | `pb.MatchOfferData.fromBuffer(payload)` | `context.read<EventDecoder>().decodeMatchOfferData(payload)` |
| `main_shell.dart:157` | `pb.MatchRequestData.fromBuffer(payload)` | `context.read<EventDecoder>().decodeMatchRequestData(payload)` |
| `event_info_sheet.dart:119` | `pb.ResourceData.fromBuffer(payload)` | `context.read<EventDecoder>().decodeResourceData(payload)` |
| `event_info_sheet.dart:125` | `pb.RequestData.fromBuffer(payload)` | `context.read<EventDecoder>().decodeRequestData(payload)` |
| `station_supply_screen.dart:81` | `pb.ResourceData.fromBuffer(payload)` | `context.read<EventDecoder>().decodeResourceData(payload)` |

#### 2.1.4 `app/services/event_store.dart` (NEW)

Narrow scope: `Event_Logs` table ONLY. Does NOT cover `Match_Negotiations`, `Station_Quotas`, etc.

```dart
import 'package:sqflite/sqflite.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';

class EventStore {
  EventStore({required DatabaseHelper databaseHelper})
      : _dbHelper = databaseHelper;

  final DatabaseHelper _dbHelper;
  Future<Database> get _database => _dbHelper.database;

  /// Query recent SOS events within [window].
  Future<List<Map<String, dynamic>>> queryRecentSos({Duration window = const Duration(hours: 24), int minUrgency = 2}) async {
    final db = await _database;
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    return db.query('Event_Logs',
      where: 'event_type = ? AND urgency >= ? AND hlc_timestamp > ?',
      whereArgs: [EventType.requestBroadcast, minUrgency, cutoff],
      orderBy: 'hlc_timestamp DESC',
    );
  }

  /// Query event logs by type.
  Future<List<Map<String, dynamic>>> queryByType(int eventType, {int limit = 100}) async {
    final db = await _database;
    return db.query('Event_Logs',
      where: 'event_type = ?',
      whereArgs: [eventType],
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );
  }

  /// Query event logs by primary key.
  Future<Map<String, dynamic>?> queryById(String eventId) async {
    final db = await _database;
    final rows = await db.query('Event_Logs', where: 'event_id = ?', whereArgs: [eventId]);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Query recent events (generic, for debug/survival mode).
  Future<List<Map<String, dynamic>>> queryRecent({int limit = 20}) async {
    final db = await _database;
    return db.query('Event_Logs', orderBy: 'hlc_timestamp DESC', limit: limit);
  }

  /// Query markers in geographic bounds (for map overlay).
  Future<List<Map<String, dynamic>>> queryMarkersInBounds({
    required double south, required double west,
    required double north, required double east,
    List<int>? eventTypes,
  }) async {
    final db = await _database;
    String where = 'lat >= ? AND lat <= ? AND lng >= ? AND lng <= ?';
    List<dynamic> whereArgs = [south, north, west, east];
    if (eventTypes != null && eventTypes.isNotEmpty) {
      final placeholders = List.filled(eventTypes.length, '?').join(',');
      where += ' AND event_type IN ($placeholders)';
      whereArgs.addAll(eventTypes);
    }
    return db.query('Event_Logs', where: where, whereArgs: whereArgs, orderBy: 'hlc_timestamp DESC');
  }
}
```

**Note**: `EventType` constants are imported from `app/mesh/event_types.dart`. This is allowed because `EventStore` lives in `app/services/`, which may import `app/mesh/`. The boundary rule is `ui-cannot-import-mesh`, not `services-cannot-import-mesh`.

**Forbidden in EventStore**: Do not query negotiation-related events by `payload LIKE`. `Event_Logs.payload` is BLOB protobuf data, so string LIKE matching is unreliable and belongs neither in `EventStore` nor in UI. v0.2.5 exposes structured `Match_Negotiations` reads through `NegotiationRepo`; richer event-to-negotiation projection is deferred to v0.3 Envelope v2 unless a structured key already exists.

**UI replacement mapping** (via `context.read<EventStore>()` — see §2.1.0):

| UI file | Old code | New code |
|---|---|---|
| `main_shell.dart:85` | `db.query('Event_Logs', where: ...)` | `context.read<EventStore>().queryRecentSos(...)` |
| `main_shell.dart:131` | `db.query('Event_Logs', ...)` | `context.read<EventStore>().queryByType(...)` |
| `map_screen_controller.dart:524` | `DatabaseHelper().database` -> query Event_Logs | `context.read<EventStore>().queryMarkersInBounds(...)` |
| `survival_mode_screen.dart:82` | `EventManager().getRecentEvents(...)` | `context.read<EventStore>().queryRecent(...)` |

#### 2.1.5 `app/services/negotiation_repo.dart` (EXTEND — already exists, 301 lines)

Extend with methods that UI currently queries directly via `DatabaseHelper`.

**Existing file**: `lib/app/services/negotiation_repo.dart` (singleton, wraps `DatabaseHelper`)

**New methods to add**:

```dart
/// Query a negotiation by ID (for navigation_screen, physical_handoff).
Future<Map<String, dynamic>?> queryNegotiation(String negotiationId) async {
  final db = await _database;
  final rows = await db.query('Match_Negotiations', where: 'negotiation_id = ?', whereArgs: [negotiationId]);
  return rows.isNotEmpty ? rows.first : null;
}

/// Query peer location for a negotiation (for navigation_screen map display).
Future<Map<String, dynamic>?> queryPeerLocationForNegotiation(String negotiationId) async {
  final db = await _database;
  final rows = await db.query('Match_Negotiations',
    columns: ['peer_lat', 'peer_lng'],
    where: 'negotiation_id = ?',
    whereArgs: [negotiationId],
  );
  return rows.isNotEmpty ? rows.first : null;
}

/// Query all active negotiations (for physical_handoff status check).
Future<List<Map<String, dynamic>>> queryActiveNegotiations() async {
  final db = await _database;
  return db.query('Match_Negotiations',
    where: 'status IN (?, ?, ?)',
    whereArgs: ['OFFERED', 'ACCEPTED', 'HANDSHAKE_PENDING'],
    orderBy: 'updated_at DESC',
  );
}

/// Query negotiations by status.
Future<List<Map<String, dynamic>>> queryByStatus(String status) async {
  final db = await _database;
  return db.query('Match_Negotiations',
    where: 'status = ?',
    whereArgs: [status],
    orderBy: 'updated_at DESC',
  );
}
```

**UI replacement mapping**:
| UI file | Old code | New code |
|---|---|---|
| `navigation_screen.dart:136` | `db.query('Match_Negotiations', ...)` | `context.read<NegotiationRepo>().queryNegotiation(...)` |
| `physical_handoff.dart:85` | `db.query('Match_Negotiations', ...)` | `context.read<NegotiationRepo>().queryNegotiation(...)` |
| `physical_handoff.dart:471` | `db.query('Match_Negotiations', ...)` | `context.read<NegotiationRepo>().queryActiveNegotiations(...)` or similar |

#### 2.1.6 `app/services/station_supply_repo.dart` (NEW)

Covers `Station_Quotas` and station-supply-related tables.

```dart
import 'package:sqflite/sqflite.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

class StationSupplyRepo {
  StationSupplyRepo({required DatabaseHelper databaseHelper})
      : _dbHelper = databaseHelper;

  final DatabaseHelper _dbHelper;
  Future<Database> get _database => _dbHelper.database;

  /// Query station quotas, optionally filtered by stationId.
  Future<List<Map<String, dynamic>>> queryStationQuotas({String? stationId}) async {
    final db = await _database;
    if (stationId != null) {
      return db.query('Station_Quotas', where: 'station_id = ?', whereArgs: [stationId]);
    }
    return db.query('Station_Quotas');
  }

  /// Update a station quota.
  Future<void> updateStationQuota(String stationId, String resourceType, int newQuota) async {
    final db = await _database;
    await db.update('Station_Quotas',
      {'quota': newQuota, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'station_id = ? AND resource_type = ?',
      whereArgs: [stationId, resourceType],
    );
  }

  /// Reset station usage counters.
  Future<void> resetStationUsage(String stationId) async {
    final db = await _database;
    await db.update('Station_Quotas',
      {'used': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'station_id = ?',
      whereArgs: [stationId],
    );
  }

  /// Query station by ID.
  Future<Map<String, dynamic>?> queryStation(String stationId) async {
    final db = await _database;
    final rows = await db.query('Station_Quotas', where: 'station_id = ?', whereArgs: [stationId]);
    return rows.isNotEmpty ? rows.first : null;
  }
}
```

**UI replacement mapping** (via `context.read<StationSupplyRepo>()` — see §2.1.0):

| UI file | Old code | New code |
|---|---|---|
| `station_supply_screen.dart:1182` | `db.update('Station_Quotas', ...)` | `context.read<StationSupplyRepo>().updateStationQuota(...)` |

#### 2.1.7 `app/db/medical_card_repo.dart` (EXTEND — already exists, 48 lines)

Currently only has `saveMedicalCard` and `getMedicalCard`. Extend if `medical_card_screen.dart` (Stage 2B) needs additional queries.

**Potential additions** (determined during Stage 2B):
```dart
/// Delete medical card for a user.
Future<void> deleteMedicalCard(List<int> pubKey) async {
  final db = await _dbHelper.database;
  await db.update('Local_Users',
    {'medical_card': null},
    where: 'pub_key = ?',
    whereArgs: [pubKey],
  );
}

/// Check if medical card exists.
Future<bool> hasMedicalCard(List<int> pubKey) async {
  final db = await _dbHelper.database;
  final rows = await db.query('Local_Users',
    columns: ['medical_card'],
    where: 'pub_key = ?',
    whereArgs: [pubKey],
  );
  return rows.isNotEmpty && rows.first['medical_card'] != null;
}
```

#### 2.1.8 `app/services/profile_repo.dart` (NEW)

Profile data and debug log queries used by `profile_screen.dart` and `survival_mode_screen.dart`.

```dart
import 'package:sqflite/sqflite.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

class ProfileRepo {
  ProfileRepo({required DatabaseHelper databaseHelper})
      : _dbHelper = databaseHelper;

  final DatabaseHelper _dbHelper;
  Future<Database> get _database => _dbHelper.database;

  /// Export debug logs (wraps DatabaseHelper.exportDebugLogs).
  Future<List<Map<String, dynamic>>> exportDebugLogs() async {
    return _dbHelper.exportDebugLogs();
  }

  /// Purge debug logs.
  Future<void> purgeDebugLogs() async {
    await _dbHelper.purgeDebugLogs();
  }

  /// Write a debug log entry.
  Future<void> writeDebugLog(String tag, String message) async {
    await _dbHelper.writeDebugLog(tag, message);
  }

  /// Query local user profile.
  Future<Map<String, dynamic>?> queryLocalProfile(List<int> pubKey) async {
    final db = await _database;
    final rows = await db.query('Local_Users', where: 'pub_key = ?', whereArgs: [pubKey]);
    return rows.isNotEmpty ? rows.first : null;
  }
}
```

**UI replacement mapping** (via `context.read<ProfileRepo>()` — see §2.1.0):

| UI file | Old code | New code |
|---|---|---|
| `survival_mode_screen.dart:57` | `DatabaseHelper().purgeDebugLogs()` | `context.read<ProfileRepo>().purgeDebugLogs()` |
| `survival_mode_screen.dart:143` | `DatabaseHelper().writeDebugLog(...)` | `context.read<ProfileRepo>().writeDebugLog(...)` |
| `survival_mode_screen.dart:292` | `DatabaseHelper().exportDebugLogs()` | `context.read<ProfileRepo>().exportDebugLogs()` |
| `profile_screen.dart:42` | `_db = DatabaseHelper()` | `context.read<ProfileRepo>().queryLocalProfile(...)` |

### 2.2 File Summary: New vs Extended

| File | Status | Action |
|---|---|---|
| `app/controllers/event_publisher.dart` | **NEW** | Create |
| `app/controllers/event_stream.dart` | **NEW** | Create |
| `app/services/event_decoder.dart` | **NEW** | Create |
| `app/services/event_store.dart` | **NEW** | Create |
| `app/services/station_supply_repo.dart` | **NEW** | Create |
| `app/services/profile_repo.dart` | **NEW** | Create |
| `app/services/negotiation_repo.dart` | EXISTS (301 lines) | Extend with 3-4 methods |
| `app/db/medical_card_repo.dart` | EXISTS (48 lines) | Extend if needed in Stage 2B |

### 2.3 UI Migration Order

Rationale: lowest-risk, lowest-coupling files first. Highest-coupling files last (they validate the facade design under stress).

#### Wave 1: Single-facade, single-violation files (low risk, fast validation)

| Order | File | Violations | Facade(s) used |
|---|---|---|---|
| 1 | `ui/sheets/hazard_dialog.dart` | 1 (EventManager publishHazard) | EventPublisher |
| 2 | `ui/sheets/resource_request_sheet.dart` | 2 (EventManager publishRequest, GeoContextResolver) | EventPublisher (+ GeoContextResolver move) |
| 3 | `ui/secondary/supply_registration.dart` | 2 (EventManager publishSupply, GeoContextResolver) | EventPublisher (+ GeoContextResolver move) |
| 4 | `ui/screens/map/sheets/event_info_sheet.dart` | 2 (pb.ResourceData.fromBuffer, pb.RequestData.fromBuffer) | EventDecoder |

**Why first**: Each file has 1-2 violations, isolated scope, easy to verify behavior parity. Any facade API mistake surfaces here cheaply.

#### Wave 2: Single-facade, multi-violation files (medium risk)

| Order | File | Violations | Facade(s) used |
|---|---|---|---|
| 5 | `ui/secondary/navigation_screen.dart` | 4 (EventManager, MeshEventHandler, DatabaseHelper -> Event_Logs query, mbtiles_loader import) | EventPublisher, EventStream, EventStore, mbtiles_loader path update |
| 6 | `ui/screens/match/match_screen.dart` | 9 (EventManager x8, MeshEventHandler x1) | EventPublisher, EventStream |
| 7 | `ui/secondary/physical_handoff.dart` | 3 (EventManager, DatabaseHelper x2 -> Match_Negotiations) | EventPublisher, NegotiationRepo |

**Why next**: These files have moderate coupling but all violations are well-understood. `match_screen.dart` has 8 EventManager calls — validates the EventPublisher facade exhaustively.

#### Wave 3: Multi-facade, multi-domain files (higher risk)

| Order | File | Violations | Facade(s) used |
|---|---|---|---|
| 8 | `ui/secondary/station_supply_screen.dart` | 5 (DatabaseHelper, EventManager x2, pb.ResourceData.fromBuffer, Station_Quotas SQL) | EventPublisher, EventDecoder, StationSupplyRepo |
| 9 | `ui/shell/main_shell.dart` | 6 (MeshEventHandler, DatabaseHelper x2, pb.fromBuffer x3, EventType literal in SQL) | EventStream, EventStore, EventDecoder |
| 10 | `ui/secondary/survival_mode_screen.dart` | 6 (MeshEventHandler x3, EventManager, DatabaseHelper x3) | EventStream, EventStore, ProfileRepo |
| 11 | `ui/screens/map/map_screen_controller.dart` | 4 (EventManager, MeshEventHandler, DatabaseHelper, mbtiles_loader, poi_query) | EventPublisher, EventStream, EventStore, mbtiles_loader path update, poi_query path update |
| 12 | `ui/screens/me/profile_screen.dart` | 1 (DatabaseHelper) | ProfileRepo |
| 13 | `ui/screens/map/widgets/map_location_header.dart` | 1 (poi_query import) | poi_query path update |

**Why last**: `main_shell.dart` and `station_supply_screen.dart` have the most complex multi-domain violations. `map_screen_controller.dart` is the reference pattern — migrating it last confirms the facade design matches its own documented principles.

#### Wave 3b: Map/geo file path updates (after file moves in §2.4)

| Order | File | Old import | New import |
|---|---|---|---|
| 14 | `ui/screens/map/map_screen_controller.dart:53` | `app/mesh/mbtiles_loader.dart` | `app/map/mbtiles_loader.dart` |
| 15 | `ui/screens/map/map_screen_controller.dart:55` | `app/mesh/poi_query.dart` | `app/map/poi_query.dart` |
| 16 | `ui/screens/map/widgets/map_location_header.dart:4` | `app/mesh/poi_query.dart` | `app/map/poi_query.dart` |
| 17 | `ui/secondary/navigation_screen.dart:13` | `app/mesh/mbtiles_loader.dart` | `app/map/mbtiles_loader.dart` |

**Note**: `geo_context_resolver.dart` moves to `app/geo/geo_context_resolver.dart`. UI files that import it (`supply_registration.dart:4`, `resource_request_sheet.dart:4`) update to `app/geo/geo_context_resolver.dart`. This is a path-only change, no API change.

#### Wave 4: Legacy app singleton UI access sweep

After Waves 1-3b, remove all remaining direct UI access to app-layer singleton entry points. Existing singleton classes may stay internally, but UI must receive dependencies from Provider or from injected controllers/facades.

| UI area | Current direct access | Required replacement |
|---|---|---|
| chat screens | `ChatService()` | `context.read<ChatService>()` |
| chat join / navigation / match / map | `LocationService()` | `context.read<LocationService>()` or injected controller dependency |
| profile mesh status / battery optimization / survival mode | `DeviceInfoController.instance` | `context.read<DeviceInfoController>()` |
| navigation / survival mode | `BleScanController.instance` | `context.read<BleScanController>()` |
| survival mode | `MeshRuntimeController.instance` | `context.read<MeshRuntimeController>()` |
| main shell | `EmergencyModeController.instance` | `context.read<EmergencyModeController>()` |
| physical handoff | `HandoffController.instance` | `context.read<HandoffController>()` or `PhysicalHandoffController` constructor dependency |
| triage input / medical card / profile / station supply | `DatabaseHelper()` | domain repo or Provider-injected repo/service |

**Mechanical gate**:

```powershell
rg "EventManager\(\)|MeshEventHandler\(\)|DatabaseHelper\(\)|BleManager\(\)|LocationService\(\)|ChatService\(|[A-Za-z]+Controller\.instance" resqmesh_app/lib/ui
```

Expected result after v0.2.5: no matches. This intentionally targets app-layer singleton entry points while avoiding framework APIs such as `WidgetsBinding.instance`.

### 2.4 `app/mesh/` Directory Cleanup

Move non-mesh files out of `lib/app/mesh/` before activating `ui-cannot-import-mesh` CI rule.

| Current path | New path | Rationale |
|---|---|---|
| `lib/app/mesh/mbtiles_loader.dart` | `lib/app/map/mbtiles_loader.dart` | Offline vector map tile loader; not mesh networking |
| `lib/app/mesh/poi_query.dart` | `lib/app/map/poi_query.dart` | POI lookup on offline map; not mesh networking |
| `lib/app/mesh/geo_context_resolver.dart` | `lib/app/geo/geo_context_resolver.dart` | Geographic region resolution; belongs with `admin_name_resolver.dart` and `village_geofence.dart` |

**New directory**: `lib/app/map/` must be created. `lib/app/geo/` already exists with 2 files.

**Internal imports to update** (non-UI files that import these):
- Grep for `import.*mbtiles_loader` across `lib/app/` -> update any internal references
- Grep for `import.*poi_query` across `lib/app/` -> update any internal references
- Grep for `import.*geo_context_resolver` across `lib/app/` -> update any internal references

**After the move**: `lib/app/mesh/` contains only mesh-networking files:
`ble_manager.dart`, `event_manager.dart`, `event_types.dart`, `hazard_manager.dart`, `iblt.dart`, `mesh_constants.dart`, `mesh_event_handler.dart`, `mesh_router.dart`, `native_ble_transport_adapter.dart` (new name), `tier_manager.dart`, `transport_factory.dart`, `triage_queue.dart`.

### 2.5 `platform/` Cleanup

Move files that import `app/` out of `lib/platform/`.

| Current path | New path | Rationale |
|---|---|---|
| `lib/platform/native_ble_transport.dart` | `lib/app/mesh/native_ble_transport_adapter.dart` | Imports 4 mesh files + 1 crypto file; mesh-aware transport orchestration |
| `lib/platform/transport_factory.dart` | `lib/app/mesh/transport_factory.dart` | Imports `NativeBleTransport`; would violate `platform-cannot-import-app` |

**Files that remain in `lib/platform/`** (pure native adapter):
| File | Imports of `app/` |
|---|---|
| `mesh_transport.dart` | None (abstract interface) |
| `native_bridge.dart` | None (MethodChannel wrapper) |
| `native_bridge_facade.dart` | None (test seam) |

**Import updates required**:
| File | Old import | New import |
|---|---|---|
| `main.dart:22` | `platform/transport_factory.dart` | `app/mesh/transport_factory.dart` |
| `transport_factory.dart` | `platform/native_ble_transport.dart` | `app/mesh/native_ble_transport_adapter.dart` (relative) |
| `native_ble_transport_adapter.dart` | `platform/mesh_transport.dart` | `platform/mesh_transport.dart` (unchanged; app -> platform is allowed) |

**Verification**: `grep -r "import 'package:ignirelay_app/app/" lib/platform/` must return empty after the move.

### 2.6 Stage 1 Commit Plan

Each migration row in §2.3 should be committed separately unless it is a pure path-only import update. This keeps rollback local to one UI surface.

| Commit | Scope | Description |
|---|---|---|
| 1.1 | New files | Create `event_publisher.dart`, `event_stream.dart`, `event_decoder.dart`, `event_store.dart`, `station_supply_repo.dart`, `profile_repo.dart`. Extend `negotiation_repo.dart`. All new files compile but are not yet imported by UI. |
| 1.2 | Wave 1 migration | Migrate each Wave 1 file in its own commit. Remove old imports, add facade imports. Run tests after each commit. |
| 1.3 | Wave 2 migration | Migrate each Wave 2 file in its own commit. Run tests after each commit. |
| 1.4 | Wave 3 migration | Migrate each Wave 3 file in its own commit. Run tests after each commit. |
| 1.5 | Wave 4 legacy singleton access sweep | Remove remaining direct UI calls to legacy app-layer singleton entry points. Run the singleton grep gate and tests. |
| 1.6 | Directory cleanup - map/geo | Create `lib/app/map/`. Move `mbtiles_loader.dart`, `poi_query.dart`. Move `geo_context_resolver.dart` to `lib/app/geo/`. Update all imports. Run tests. |
| 1.7 | Directory cleanup - platform | Move `native_ble_transport.dart` -> `native_ble_transport_adapter.dart` to `lib/app/mesh/`. Move `transport_factory.dart` to `lib/app/mesh/`. Update `main.dart` import. Run tests. |
| 1.8 | Verification | Full `flutter test`, `flutter analyze`, automated tests, manual smoke tests. Verify grep returns empty for all forbidden import patterns. |

### 2.7 Stage 1 Rollback Plan

| Scenario | Rollback action |
|---|---|
| Commit 1.1 breaks compilation | Fix import issues in new files; no existing code is touched yet so blast radius is zero. |
| Commit 1.2 causes UI regression in hazard_dialog / resource_request_sheet / supply_registration / event_info_sheet | `git revert <commit-1.2-hash>`. Revert restores original imports. Re-run tests to confirm green. Investigate facade API mismatch. |
| Commit 1.3 causes regression in navigation / match / handoff | `git revert <commit-1.3-hash>`. Same procedure. |
| Commit 1.4 causes regression in station_supply / main_shell / survival_mode / map_controller / profile | `git revert <commit-1.4-hash>`. Highest-risk commit; individual file reverts possible if only one file regresses. |
| Commit 1.5 causes regression in legacy singleton access sweep | Revert only the affected UI surface. Keep Provider registration changes if other surfaces already use them. |
| Commit 1.6 breaks map functionality | `git revert <commit-1.6-hash>`. Files move back to `app/mesh/`. |
| Commit 1.7 breaks BLE transport | `git revert <commit-1.7-hash>`. Files move back to `platform/`. Revert `main.dart` import. |
| Any commit causes test failure | Do NOT proceed to next commit. Fix or revert before continuing. |

**Global rollback**: If Stage 1 as a whole proves unworkable, `git revert --no-commit 1.1..1.8` to undo all Stage 1 changes. This is unlikely because each commit is independent and reversible.

### 2.8 Stage 1 Test Plan

| Test type | Command | When |
|---|---|---|
| Unit tests | `flutter test` | After each commit |
| Static analysis | `flutter analyze` | After each commit |
| Layer boundary check | `dart run tool/check_layers.dart` | After commit 1.8 (before CI rules activated, uses baseline comparison) |
| Import grep verification | See §2.9 mechanical checks | After commit 1.8 |
| Automated facade tests | `flutter test test/controllers/event_stream_test.dart test/services/event_decoder_test.dart test/services/event_store_test.dart` | Added in commit 1.1 and kept green |
| Widget provider smoke tests | Minimal widget tests for Provider access on migrated screens | Added alongside each migration wave |
| Manual smoke test - hazard dialog | Open hazard dialog -> create hazard -> verify publish succeeds | After commit 1.2 |
| Manual smoke test - resource request | Open resource request sheet -> submit -> verify publish succeeds | After commit 1.2 |
| Manual smoke test - supply registration | Register supply -> verify publish succeeds | After commit 1.2 |
| Manual smoke test - event info sheet | Tap event marker -> verify proto decode shows correct data | After commit 1.2 |
| Manual smoke test - match flow | Create request -> receive offer -> accept -> verify negotiation progresses | After commit 1.3 |
| Manual smoke test - physical handoff | Complete match -> enter handoff flow -> verify DB queries | After commit 1.3 |
| Manual smoke test - main shell SOS | Trigger SOS -> verify event appears in main shell | After commit 1.4 |
| Manual smoke test - map screen | Pan/zoom -> verify hazards/events/markers display | After commit 1.4 |
| Manual smoke test - station supply | Create/edit station quota -> verify DB update | After commit 1.4 |

**Automated tests required before Stage 1 is accepted**:

| Test file | Purpose |
|---|---|
| `test/controllers/event_stream_test.dart` | Feeds synthetic `Event_Logs` rows through a fake `EventStore` and verifies every dispatch-table row in §2.1.2 emits the correct typed stream. |
| `test/services/event_decoder_test.dart` | Verifies each decoder returns plain Dart objects and returns `null` instead of throwing on malformed payloads. |
| `test/services/event_store_test.dart` | Verifies `EventStore` only queries `Event_Logs` and does not use `payload LIKE` for negotiation lookups. |
| `test/ui/provider_wiring_smoke_test.dart` | Pumps a minimal app with the root Providers and verifies migrated widgets can read required dependencies without directly constructing singletons. |

Manual smoke tests remain required for end-to-end confidence, but they are not the only behavioral gate.

### 2.9 Stage 1 Acceptance Criteria

#### Mechanical checks (must all pass)
- [ ] `grep -r "import 'package:ignirelay_app/app/mesh/" lib/ui/` returns empty
- [ ] `grep -r "import 'package:ignirelay_app/app/proto/" lib/ui/` returns empty
- [ ] `grep -r "import 'package:ignirelay_app/app/db/" lib/ui/` returns empty
- [ ] `grep -r "import 'package:ignirelay_app/app/" lib/platform/` returns empty
- [ ] `rg "EventManager\(\)|MeshEventHandler\(\)|DatabaseHelper\(\)|BleManager\(\)|LocationService\(\)|ChatService\(|[A-Za-z]+Controller\.instance" lib/ui` returns empty
- [ ] `rg "static final .*instance|factory .*=> .*_instance|factory .*\\(\\) => _instance" lib/app/controllers/event_publisher.dart lib/app/controllers/event_stream.dart lib/app/services/event_decoder.dart lib/app/services/event_store.dart lib/app/services/station_supply_repo.dart lib/app/services/profile_repo.dart` returns empty
- [ ] `grep -r "rawEvents" lib/ui/` matches only `survival_mode_screen.dart`
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes (414 passed / 3 skipped - same baseline)
- [ ] All new facade files compile
- [ ] No protobuf types (`pb.*`) referenced in any `lib/ui/` file

#### Behavioral checks
- [ ] All 13 UI files listed in §2.3 have identical behavior (verified by automated tests where practical plus manual smoke test per §2.8)
- [ ] EventStream dispatch unit tests cover every row in the dispatch table in §2.1.2
- [ ] No new test failures introduced
- [ ] Existing test expectations are not weakened; new tests are added for facades/provider wiring

#### Documentation checks (deferred to Stage 5 but tracked here)
- [ ] New facade files have doc comments on public API

---

## 3. Stage 2A: UI God File Splits (Critical Path)

All line counts use raw `wc -l`.

### 3.1 `station_supply_screen.dart` (1344 lines -> target <=500 lines)

**Current state**: 1344 lines, imports EventManager, DatabaseHelper, proto.

**After Stage 1**: All `app/mesh/`, `app/proto/`, `app/db/` imports replaced by EventPublisher, EventDecoder, StationSupplyRepo. File is now ~1200 lines of pure UI + state.

**Split plan**:

| New file | Contents | Target lines |
|---|---|---|
| `ui/secondary/station_supply_controller.dart` | `StationSupplyController` (ChangeNotifier): state, generation tokens, disposed guard. Uses `StationSupplyRepo`, `EventPublisher`. No BuildContext. | ~350 |
| `ui/secondary/station_supply_list_view.dart` | `StationSupplyListView` widget: list display, pull-to-refresh. | ~200 |
| `ui/secondary/station_supply_detail_sheet.dart` | `StationSupplyDetailSheet` widget: detail view for a single station. | ~200 |
| `ui/secondary/station_supply_edit_dialog.dart` | `StationSupplyEditDialog` widget: create/edit form. | ~200 |
| `ui/secondary/station_supply_screen.dart` | Thin shell: creates controller, wires tabs/sheets. | ~150 |

**Total**: ~1100 lines across 5 files, each <=350 lines.

**Controller API** (extracted from current State class):
```dart
class StationSupplyController extends ChangeNotifier {
  List<Map<String, dynamic>> get stations;
  bool get isLoading;
  String? get error;

  Future<void> loadStations();
  Future<void> createStation({required String name, required Map<String, int> quotas});
  Future<void> updateQuota(String stationId, String resourceType, int newQuota);
  Future<void> resetUsage(String stationId);
  Future<void> cancelSupply(String eventId);

  @override
  void dispose();
}
```

**APPROVED DEVIATION (2026-05-15)** — the original list/detail/edit split assumed
a single browsing surface (list → detail sheet → edit dialog). The actual screen
is a 2-tab `TabBarView` (register a new station vs. manage existing ones), so the
view files were split along the tabs instead:

| New file | Contents | Lines |
|---|---|---|
| `ui/secondary/station_supply_controller.dart` | `StationSupplyController` (ChangeNotifier): access check, station list state, load orchestration. Uses `StationSupplyRepo`, `EventStore`, `EventDecoder`, `EventPublisher`. No BuildContext. | 121 |
| `ui/secondary/station_supply_register_tab.dart` | `StationSupplyRegisterTab` widget: register/publish form. | 419 |
| `ui/secondary/station_supply_manage_tab.dart` | `StationSupplyManageTab` widget: browse/manage registered stations, quota reset. | 345 |
| `ui/secondary/station_supply_models.dart` | Shared plain-data models for the two tabs. | 75 |
| `ui/secondary/station_supply_screen.dart` | Thin shell: creates controller, wires the 2 tabs + access gate. | 160 |

All files are <=500 lines. The register form and manage/detail behaviour from the
original plan are preserved, just grouped by tab rather than by list/detail/edit.

### 3.2 `match_screen.dart` (972 lines -> audit first)

**Current state**: 972 lines, imports EventManager, MeshEventHandler.

**After Stage 1**: All mesh imports replaced by EventPublisher, EventStream.

**Audit required** (per brief §4.2.3): Check if the screen is already a thin shell around 4 tab files:
- `match_tab_requests.dart`
- `match_tab_negotiations.dart`
- `match_tab_supplies.dart`
- `match_tab_community.dart`

If the shell is thin (<=300 lines of orchestration + shared actions), document and skip further split. If not:

| New file | Contents | Target lines |
|---|---|---|
| `ui/screens/match/match_screen_controller.dart` | `MatchScreenController` (ChangeNotifier): shared state across tabs, match actions (accept/decline/cancel). Uses `EventPublisher`, `EventStream`. | ~300 |
| `ui/screens/match/match_screen.dart` | Thin shell: TabBarView + controller creation. | ~200 |

**Audit outcome must be documented in this spec before split begins.**

### 3.3 `physical_handoff.dart` (778 lines -> target <=500 lines)

**Current state**: 778 lines, imports EventManager, DatabaseHelper.

**After Stage 1**: Replaced by EventPublisher, NegotiationRepo.

**Split plan** (original):

| New file | Contents | Target lines |
|---|---|---|
| `ui/secondary/physical_handoff_controller.dart` | `PhysicalHandoffController` (ChangeNotifier): FSM (PENDING -> CONFIRMING -> COMPLETING -> DONE / FAILED), PIN generation/verification, BLE handoff orchestration. | ~300 |
| `ui/secondary/handoff_prep_view.dart` | `HandoffPrepView`: preparation step UI. | ~120 |
| `ui/secondary/handoff_confirm_view.dart` | `HandoffConfirmView`: confirmation step UI (PIN entry). | ~120 |
| `ui/secondary/handoff_success_view.dart` | `HandoffSuccessView`: success state UI. | ~80 |
| `ui/secondary/handoff_failure_view.dart` | `HandoffFailureView`: failure/retry state UI. | ~80 |
| `ui/secondary/physical_handoff.dart` | Thin shell: creates controller, switches on FSM state. | ~100 |

**FSM states**: `PENDING` -> `CONFIRMING` (PIN entry) -> `COMPLETING` (BLE handshake) -> `DONE` / `FAILED`.

**APPROVED DEVIATION (2026-05-14)** — the original prep/confirm/success/failure split
assumed a single linear FSM. The actual screen has two orthogonal axes: **role**
(provider vs. requester) and **method** (`PIN_4DIGIT`/`BLE` vs. `DROP_OFF`), which
produce four distinct step views rather than a prep→confirm sequence. The view files
were therefore split along those axes instead:

| New file | Contents | Lines |
|---|---|---|
| `ui/secondary/physical_handoff_controller.dart` | `PhysicalHandoffController` (ChangeNotifier): PIN FSM (`idle`→`completing`→`done`/`failed`), lockout state machine, BLE/drop-off orchestration. | 285 |
| `ui/secondary/handoff_pin_views.dart` | `HandoffProviderPinView` (PIN display + wait) and `HandoffRequesterPinView` (PIN entry + lockout UI). | ~235 |
| `ui/secondary/handoff_dropoff_views.dart` | `HandoffDropOffProviderView` and `HandoffDropOffRequesterView`. | ~215 |
| `ui/secondary/handoff_result_views.dart` | `HandoffSuccessView` and `HandoffCancelledView` (= original success/failure views). | 76 |
| `ui/secondary/physical_handoff.dart` | Thin shell: creates controller, switches on role × method. | ~153 |

All files are <=500 lines; the success/failure state views from the original plan
are preserved as `handoff_result_views.dart`.

### 3.4 `survival_mode_screen.dart` (775 lines -> target <=500 lines)

**Current state**: 775 lines, imports MeshEventHandler, EventManager, DatabaseHelper.

**After Stage 1**: Replaced by EventStream, EventStore, ProfileRepo.

**Split plan** (minimum viable, per brief §4.2.3):

| New file | Contents | Target lines |
|---|---|---|
| `ui/secondary/survival_mode_controller.dart` | `SurvivalModeController` (ChangeNotifier): BLE status, device info, mesh runtime state. Uses `EventStream`, `ProfileRepo`. | ~250 |
| `ui/secondary/debug_log_viewer.dart` | `DebugLogViewer` widget: displays debug logs, export button. | ~150 |
| `ui/secondary/survival_mode_screen.dart` | Main screen: controller + settings + log viewer. | ~250 |

### 3.5 Stage 2A Commit Plan

| Commit | Scope | Description |
|---|---|---|
| 2A.1 | station_supply_screen | Extract `StationSupplyController`. Verify existing tests pass. |
| 2A.2 | station_supply_screen | Extract `StationSupplyListView`, `StationSupplyDetailSheet`, `StationSupplyEditDialog`. Thin shell. Verify. |
| 2A.3 | match_screen | Audit: determine if shell is already thin. Document result. |
| 2A.4 | match_screen | If needed: extract `MatchScreenController`. Thin shell. Verify. |
| 2A.5 | physical_handoff | Extract `PhysicalHandoffController`. Verify. |
| 2A.6 | physical_handoff | Extract step views. Thin shell. Verify. |
| 2A.7 | survival_mode_screen | Extract `SurvivalModeController`, `DebugLogViewer`. Thin shell. Verify. |
| 2A.8 | Verification | Full `flutter test`, `flutter analyze`, manual smoke tests on all 4 screens. |

### 3.6 Stage 2A Rollback Plan

| Scenario | Rollback action |
|---|---|
| station_supply_screen split causes regression | `git revert 2A.1..2A.2`. Revert to post-Stage-1 state. Re-investigate extraction boundary. |
| match_screen audit shows split is unnecessary | Document and skip. No rollback needed. |
| match_screen split causes regression | `git revert 2A.4`. Restore pre-split state. |
| physical_handoff split causes FSM regression (most likely risk) | `git revert 2A.5..2A.6`. Revert to post-Stage-1 state. The FSM is the highest-risk extraction; consider lighter extraction (controller only, no view split). |
| survival_mode_screen split causes regression | `git revert 2A.7`. Simple debug page; low risk. |
| Any commit causes test failure | Do NOT proceed. Fix or revert. |

### 3.7 Stage 2A Test Plan

| Test type | Command | When |
|---|---|---|
| Unit tests | `flutter test` | After each commit |
| Static analysis | `flutter analyze` | After each commit |
| Controller tests — station supply | `flutter test test/ui/station_supply_controller_test.dart` | Added with 2A.1 |
| Controller tests — match screen | `flutter test test/ui/match_screen_controller_test.dart` if a controller is extracted | Added with 2A.4 |
| Controller tests — physical handoff | `flutter test test/ui/physical_handoff_controller_test.dart` | Added with 2A.5 |
| Controller tests — survival mode | `flutter test test/ui/survival_mode_controller_test.dart` | Added with 2A.7 |
| Widget smoke tests | Minimal widget tests that pump each thin shell with fake repos/facades/providers | Added alongside each split |
| Manual smoke — station supply | Create station -> edit quota -> reset usage -> verify all tabs work | After 2A.2 |
| Manual smoke — match flow | Create request -> receive offer -> accept/decline -> verify all 4 tabs | After 2A.4 |
| Manual smoke — physical handoff | Full handoff flow: prep -> PIN entry -> completion -> verify FSM transitions | After 2A.6 |
| Manual smoke — survival mode | Open survival mode -> verify BLE status, debug logs, device info display | After 2A.7 |
| Line count verification | `wc -l` on each new file -> all <=500 (or documented exception) | After 2A.8 |

### 3.8 Stage 2A Acceptance Criteria

- [ ] `station_supply_screen.dart` <=500 lines (or >500 only with documented exception comment)
- [ ] `match_screen.dart` <=500 lines, OR documented audit result showing it is already thin
- [ ] `physical_handoff.dart` <=500 lines
- [ ] `survival_mode_screen.dart` <=500 lines
- [ ] All new sub-files <=500 lines each
- [ ] `flutter test` passes (no new failures)
- [ ] `flutter analyze` passes
- [ ] All 4 affected screens have identical behavior (controller/widget tests where practical plus manual smoke test)
- [ ] Controller tests exist for every newly extracted controller, or the audit explicitly documents why no controller was extracted
- [ ] Widget smoke tests cover each thin shell with fake dependencies
- [ ] Controller/View pattern consistent across all splits (matches `map_screen_controller.dart` reference)

---

## 4. Stage 2B: UI God File Splits (Parallel)

Can overlap with Stage 2A end or v0.3 Stage 0. Must complete before v0.3 Stage 1.

### 4.1 `medical_card_screen.dart` (1031 lines -> target <=500 lines)

**Current state**: 1031 lines, imports DatabaseHelper.

**After Stage 1**: DatabaseHelper import replaced by MedicalCardRepo (extended).

**Split plan** (original):

| New file | Contents | Target lines |
|---|---|---|
| `ui/secondary/medical_card_controller.dart` | `MedicalCardController` (ChangeNotifier): form state, validation, save/load. Uses `MedicalCardRepo`. | ~300 |
| `ui/secondary/basic_info_section.dart` | `BasicInfoSection` widget. | ~120 |
| `ui/secondary/medical_conditions_section.dart` | `MedicalConditionsSection` widget. | ~120 |
| `ui/secondary/allergies_section.dart` | `AllergiesSection` widget. | ~100 |
| `ui/secondary/medications_section.dart` | `MedicationsSection` widget. | ~100 |
| `ui/secondary/emergency_contact_section.dart` | `EmergencyContactSection` widget. | ~100 |
| `ui/secondary/privacy_flags_section.dart` | `PrivacyFlagsSection` widget. | ~80 |
| `ui/secondary/medical_card_screen.dart` | Thin shell: form scaffold, controller, section list. | ~150 |

**APPROVED DEVIATION (2026-05-14)** — the original 6-section split assumed conditions /
allergies / medications / privacy-flags were each their own screen section. The actual
screen has **3 section headers** (基本生理 / 醫療背景 / 急救資訊); "privacy flags" are not
a section but a per-field SOS toggle threaded through every field. The split follows the
real 3-section structure plus a shared field-widgets file:

| New file | Contents | Lines |
|---|---|---|
| `ui/secondary/medical_card_controller.dart` | `MedicalCardController` (ChangeNotifier): `MedicalCard` + 11 `TextEditingController`s, load/save, preset apply, SOS-flag toggle, allergy add/remove, Health Connect import. Sealed `MedicalSaveOutcome` / `HealthImportOutcome`. Uses `MedicalCardRepo` + `IdentityManager`. | 336 |
| `ui/secondary/medical_card_fields.dart` | Shared `MedicalSectionHeader`, `MedicalSosToggle`, `MedicalTextField`, `MedicalNumberField`. | 216 |
| `ui/secondary/medical_basic_section.dart` | `MedicalBasicSection` (name/age/height/weight/blood-type). | 120 |
| `ui/secondary/medical_background_section.dart` | `MedicalBackgroundSection` (conditions / allergies multi-entry / medications). | 176 |
| `ui/secondary/medical_emergency_section.dart` | `MedicalEmergencySection` (emergency contact / organ donor / language). | 169 |
| `ui/secondary/medical_card_header.dart` | `MedicalCardHeader` (SOS info banner, preset chips, Health Connect import button). | 146 |
| `ui/secondary/medical_card_screen.dart` | Thin shell: Scaffold + AnimatedBuilder + section list; save / preset / health-import snackbars & dialogs. | 207 |

All files <=500 lines.

### 4.2 `profile_screen.dart` (866 lines -> target <=500 lines)

**Current state**: 866 lines, imports DatabaseHelper.

**After Stage 1**: DatabaseHelper import replaced by ProfileRepo.

**Split plan** (original):

| New file | Contents | Target lines |
|---|---|---|
| `ui/screens/me/identity_section.dart` | `IdentitySection` widget: public key display, nickname. | ~150 |
| `ui/screens/me/medical_card_entry_section.dart` | `MedicalCardEntrySection` widget: link to medical card screen. | ~100 |
| `ui/screens/me/settings_section.dart` | `SettingsSection` widget: language, theme, battery optimization. | ~200 |
| `ui/screens/me/debug_section.dart` | `DebugSection` widget: debug tools entry. | ~100 |
| `ui/screens/me/profile_screen.dart` | Thin shell: section list. | ~200 |

Note: `profile_mesh_status_card.dart` already exists and is separate. No changes needed.

**APPROVED DEVIATION (2026-05-14)** — the screen has no standalone "debug section"
(debug tools were already removed earlier; mesh detail is reached via the existing
`ProfileMeshStatusCard`). The medical-card entry is a single `ProfileQuickAction` row,
too small for its own file — it lives with the identity widgets. The trust/tier list
(`_TierList` + detail rows, ~190 lines in the god file) was the real extraction
candidate and got its own file. Actual split:

| New file | Contents | Lines |
|---|---|---|
| `ui/screens/me/profile_identity_section.dart` | `ProfileIdentityCard` (avatar / nickname / badge / pubkey) + `ProfileQuickAction`. | 181 |
| `ui/screens/me/profile_tier_section.dart` | `ProfileTierList` (collapsible) + tier detail rows + dots. | 206 |
| `ui/screens/me/profile_settings_section.dart` | `ProfileSettingsCard` (theme / text-scale / language / battery / privacy rows). | 223 |
| `ui/screens/me/profile_screen.dart` | Thin shell: `IgniProfileScreen` state (nickname / level / pubkey / has-medical-card) + `ListView` layout. | 289 |

No controller extracted — the screen state is a handful of fields loaded once; the
spec did not call for a `ProfileController` and one is not warranted. All files
<=500 lines. `profile_mesh_status_card.dart` unchanged as noted.

### 4.3 Stage 2B Commit Plan

| Commit | Scope | Description |
|---|---|---|
| 2B.1 | medical_card_screen | Extract `MedicalCardController`. Extend `MedicalCardRepo` if needed. Verify. |
| 2B.2 | medical_card_screen | Extract section widgets. Thin shell. Verify. |
| 2B.3 | profile_screen | Extract section widgets. Thin shell. Verify. |
| 2B.4 | Verification | Full `flutter test`, `flutter analyze`, manual smoke tests. |

### 4.4 Stage 2B Rollback Plan

| Scenario | Rollback action |
|---|---|
| medical_card_screen split causes form regression | `git revert 2B.1..2B.2`. Revert to post-Stage-1 state. |
| profile_screen split causes regression | `git revert 2B.3`. |
| Any commit causes test failure | Do NOT proceed. Fix or revert. |

### 4.5 Stage 2B Test Plan

| Test type | Command | When |
|---|---|---|
| Unit tests | `flutter test` | After each commit |
| Static analysis | `flutter analyze` | After each commit |
| Controller tests — medical card | `flutter test test/ui/medical_card_controller_test.dart` | Added with 2B.1 |
| Widget smoke tests — medical card | Pump medical card thin shell with fake `MedicalCardRepo` | Added with 2B.2 |
| Widget smoke tests — profile | Pump profile thin shell with fake `ProfileRepo` / controller dependencies | Added with 2B.3 |
| Manual smoke — medical card | Create -> edit -> save medical card -> verify all sections render and persist | After 2B.2 |
| Manual smoke — profile | Open profile -> verify identity, mesh status, settings, debug sections | After 2B.3 |
| Line count verification | `wc -l` on each new file | After 2B.4 |

### 4.6 Stage 2B Acceptance Criteria

- [ ] `medical_card_screen.dart` <=500 lines
- [ ] `profile_screen.dart` <=500 lines
- [ ] All new sub-files <=500 lines each
- [ ] `flutter test` passes (no new failures)
- [ ] `flutter analyze` passes
- [ ] Both screens have identical behavior (controller/widget tests where practical plus manual smoke test)
- [ ] Controller tests exist for every newly extracted controller
- [ ] Widget smoke tests cover each thin shell with fake dependencies

---

## 5. Stage 3: CI Enforcement

**Prerequisites**: Stage 1 complete (all grep checks pass). Stage 2 complete (all god files <=500 lines or documented).

### 5.1 New Rules in `tool/check_layers.dart`

Add to `_rules` const list:

```dart
_Rule(name: 'ui-cannot-import-mesh',  sourcePrefix: 'lib/ui/',     forbiddenPrefix: 'lib/app/mesh/'),
_Rule(name: 'ui-cannot-import-proto', sourcePrefix: 'lib/ui/',     forbiddenPrefix: 'lib/app/proto/'),
_Rule(name: 'ui-cannot-import-db',    sourcePrefix: 'lib/ui/',     forbiddenPrefix: 'lib/app/db/'),
_Rule(name: 'platform-cannot-import-app', sourcePrefix: 'lib/platform/', forbiddenPrefix: 'lib/app/'),
```

### 5.2 Exception List Mechanism

```dart
class _Exception {
  final String rule;
  final String file;
  final String reason;
  const _Exception({required this.rule, required this.file, required this.reason});
}

const _exceptions = <_Exception>{
  // Example (expected to be empty after v0.2.5):
  // _Exception(rule: 'ui-cannot-import-mesh', file: 'lib/ui/screens/map/widgets/map_view.dart', reason: 'flutter_map TileLayer types'),
};
```

Implementation: when scanning, if a violation matches an entry in `_exceptions`, skip it. Log skipped exceptions in `--warn` mode for visibility.

### 5.3 Baseline Policy

- After v0.2.5, `tool/layer_violations_baseline.txt` must contain only comments (lines starting with `#`).
- Run `dart run tool/check_layers.dart --update-baseline` after all stages complete to reset.
- CI gate: `dart run tool/check_layers.dart --strict` - any violation fails CI.

### 5.4 Commit Plan

| Commit | Description |
|---|---|
| 3.1 | Add 4 new rules + exception list mechanism. Run `--strict`. Verify zero violations. Update baseline. |

### 5.5 Rollback Plan

| Scenario | Rollback action |
|---|---|
| New rules flag false positives | Add entries to `_exceptions` list with documented reason. Do NOT disable the rule. |
| Baseline is non-empty after v0.2.5 | Indicates unfinished migration. Re-open Stage 1 for the violating files. |

### 5.6 Test Plan

| Test | Command | Expected |
|---|---|---|
| Strict mode | `dart run tool/check_layers.dart --strict` | Zero violations, exit 0 |
| Baseline mode | `dart run tool/check_layers.dart` | Zero violations (baseline is clean) |
| CI integration | Add to CI pipeline as gate | Future PRs with violations fail |

### 5.7 Acceptance Criteria

- [ ] `dart run tool/check_layers.dart --strict` passes with zero violations
- [ ] Baseline file contains only comments
- [ ] Exception list mechanism works (test by adding a temporary exception, verifying it suppresses the violation, then removing it)
- [ ] 6 total rules enforced (2 existing + 4 new)

---

## 6. Stage 4: Wire-Format Golden Tests

Independent of other stages. Can run in parallel.

### 6.1 EventType Drift Test

**File**: `test/proto/event_type_enum_test.dart`

**Current test** (line 40-42):
```dart
test('valueOf(15) returns null (out of range)', () {
  expect(EventType.valueOf(15), isNull);
});
```

**Replace with**:
```dart
test('Dart EventType constants must all have proto counterparts', () {
  final dartValues = <int>{
    EventType.resourceRegister,    // 0
    EventType.requestBroadcast,    // 1
    EventType.matchOffer,          // 2
    EventType.physicalHandshake,   // 3
    EventType.hazardMarker,        // 4
    EventType.quarantineVote,      // 5
    EventType.matchCancel,         // 6
    EventType.fireAlarmRf,         // 7
    EventType.matchAccept,         // 8
    EventType.matchDecline,        // 9
    EventType.matchInquiry,        // 10
    EventType.matchAvailable,      // 11
    EventType.matchGone,           // 12
    EventType.chatMessage,         // 13
    EventType.locationUpdate,      // 14
    EventType.matchRequest,        // 15
    EventType.handshakeComplete,   // 16
    EventType.stationClaim,        // 17
    EventType.stationResponse,     // 18
  };
  for (final v in dartValues) {
    expect(pb.EventType.valueOf(v), isNotNull,
      reason: 'EventType constant $v has no matching proto enum value. '
              'Sync protos/mesh_protocol.proto before adding new EventType constants.');
  }
}, skip: 'Resolved by v0.3 Envelope v2 reset');
```

**Key decisions**:
- Marked `@Skip` because 15-18 gap exists and v0.2.5 does NOT fix it.
- `@Skip` reference: `v0.3 Envelope v2 reset` - tracked to v0.3 milestone.
- When v0.3 ships the new EventType layout, remove `skip:` parameter.
- CI stays green during v0.2.5.

### 6.2 Wire Format Golden Tests

**New file**: `test/proto/wire_format_golden_test.dart`

**Golden directory**: `test/proto/goldens/`

**Coverage**: One golden per working EventType (0-14). Total: 15 golden files.

**Test pattern**:
```dart
test('EventType $type wire format golden', () {
  final event = _buildFixedEvent(type);  // deterministic inputs
  final bytes = event.writeToBuffer();
  final golden = File('test/proto/goldens/event_type_$type.bin').readAsBytesSync();
  expect(bytes, equals(golden),
    reason: 'Wire format for EventType $type changed. '
            'If intentional, update golden with: dart run tool/update_goldens.dart');
});
```

**Golden update tool**: Document command to regenerate goldens when intentional changes occur.

### 6.3 Commit Plan

| Commit | Description |
|---|---|
| 4.1 | Add EventType drift test (marked @Skip). Verify existing tests pass. |
| 4.2 | Add wire format golden tests + golden files for EventType 0-14. Verify. |

### 6.4 Rollback Plan

| Scenario | Rollback action |
|---|---|
| Drift test breaks CI | Verify `skip:` is set. If still failing, investigate test framework issue. |
| Golden tests fail on current code | Indicates encode behavior changed. If unintentional, fix encoder. If intentional (v0.2.5 side effect), update goldens. |

### 6.5 Test Plan

| Test | Command | Expected |
|---|---|---|
| All proto tests | `flutter test test/proto/` | All pass (drift test skipped, goldens match) |
| Golden regeneration | Update one golden -> verify test fails -> restore -> verify passes | Confirms golden tests actually check |

### 6.6 Acceptance Criteria

- [ ] EventType drift test exists, marked `@Skip('Resolved by v0.3 Envelope v2 reset')`
- [ ] 15 wire format golden files exist in `test/proto/goldens/`
- [ ] All proto tests pass
- [ ] `flutter test` overall still passes (no regressions)

---

## 7. Stage 5: Documentation

### 7.1 `CLAUDE.md` - New Section

File: `CLAUDE.md` (create if not exists)

Add section:

```markdown
## Architecture Layer Rules

### Forbidden Import Rules
1. `ui-cannot-import-platform`: `lib/ui/**` must NOT import `lib/platform/**`
2. `app-cannot-import-ui`: `lib/app/**` must NOT import `lib/ui/**`
3. `ui-cannot-import-mesh`: `lib/ui/**` must NOT import `lib/app/mesh/**`
4. `ui-cannot-import-proto`: `lib/ui/**` must NOT import `lib/app/proto/**`
5. `ui-cannot-import-db`: `lib/ui/**` must NOT import `lib/app/db/**`
6. `platform-cannot-import-app`: `lib/platform/**` must NOT import `lib/app/**`

Enforced by: `dart run tool/check_layers.dart --strict`

### Facade Access Pattern
All v0.2.5 facades/repos/controllers are constructed via `MultiProvider` at the root (`main.dart`). UI accesses them via `context.read<T>()`. App-layer controllers/services receive them through constructors. Newly added v0.2.5 code must not use `.instance`.

- UI: `context.read<EventPublisher>()`  (NEVER `EventPublisher.instance`)
- App layer: constructor-injected `EventPublisher` (NEVER `EventPublisher.instance`)

### Facade Locations
- `app/controllers/event_publisher.dart` - wraps all `EventManager().publish*()` calls
- `app/controllers/event_stream.dart` - wraps `MeshEventHandler().events`, exposes typed streams
- `app/services/event_decoder.dart` - wraps all `pb.X.fromBuffer()` calls, returns plain Dart
- `app/services/event_store.dart` - wraps `Event_Logs` table queries
- `app/services/negotiation_repo.dart` - wraps `Match_Negotiations` queries (extended)
- `app/services/station_supply_repo.dart` - wraps `Station_Quotas` queries
- `app/services/profile_repo.dart` - wraps profile and debug log queries

### Rules
- Do NOT add new `.instance` / factory-singleton entry points for v0.2.5 facades, repositories, or controllers.
- New dependencies are wired at the app root and injected through constructors. Existing legacy singletons may be wrapped as dependencies, but must not leak into UI or new public APIs.
- UI must not directly call legacy app-layer singleton entry points (`.instance`, `EventManager()`, `MeshEventHandler()`, `DatabaseHelper()`, `LocationService()`, `ChatService()`, etc.).
- Do NOT let UI files exceed 500 lines if they touch facade. Use Controller / View / Repository pattern.
- Do NOT use `EventStream.rawEvents` in production UI. It is restricted to `survival_mode_screen.dart` (debug page). Use typed streams (`sosAlerts`, `matchUpdates`, `hazardEvents`, `supplyChanges`) instead.
- Reference pattern: `ui/screens/map/map_screen_controller.dart`
```

**APPROVED DEVIATION (2026-05-15)** — the `rawEvents` rule above names
`survival_mode_screen.dart` as the sole allowed site. The Stage 2A split (§3.4)
extracted `survival_mode_controller.dart`, and the `rawEvents` subscription
naturally moved into that controller. The controller is part of the same
survival-mode debug feature, not general production UI, so the rule's intent is
unchanged. The shipped `CLAUDE.md` and `docs/PR_CHECKLIST.md` therefore name
both `survival_mode_screen.dart` and `survival_mode_controller.dart` as the
allowed debug surface. Moving the subscription back into the screen file would
re-violate the §3.4 god-file split, so it stays in the controller.

### 7.2 ADR-001: Layering Rules

**File**: `docs/architecture/ADR-001-layering-rules.md`

```markdown
# ADR-001: Layering Rules

Date: 2026-05-13
Status: Accepted

## Context
The project originally enforced only two import rules (`ui-cannot-import-platform`, `app-cannot-import-ui`). This allowed UI files to accumulate direct imports of `app/mesh/`, `app/proto/`, and `app/db/`, creating tight coupling that would make v0.3 protocol changes entangled with UI churn.

## Decision
Enforce six import rules:
1. ui-cannot-import-platform
2. app-cannot-import-ui
3. ui-cannot-import-mesh
4. ui-cannot-import-proto
5. ui-cannot-import-db
6. platform-cannot-import-app

All enforced by `tool/check_layers.dart --strict`. Zero baseline after v0.2.5.

## Consequences
- All cross-layer access from UI goes through facades in `app/controllers/` and `app/services/`.
- `platform/` is strictly pure native adapter (no business logic).
- Protocol changes in v0.3 can proceed inside `app/mesh/` with no UI file changes.
- PR review checklist updated to include layer rule verification.

## Status
Accepted on 2026-05-13.
```

### 7.3 ADR-002: Mesh-to-UI Contract

**File**: `docs/architecture/ADR-002-mesh-to-ui-contract.md`

```markdown
# ADR-002: Mesh-to-UI Contract

Date: 2026-05-13
Status: Accepted

## Context
UI files previously imported `EventManager`, `MeshEventHandler`, `DatabaseHelper`, and protobuf types directly. This created a leaky abstraction where protocol changes required UI changes.

## Decision
Four facade types mediate all mesh-to-UI communication:
1. **EventPublisher** - outbound: UI publishes events through this facade
2. **EventStream** - inbound: UI subscribes to typed event streams through this facade
3. **EventDecoder** - payload decoding: all proto decode lives here, returns plain Dart
4. **EventStore** + domain repos - data access: all SQL queries go through domain-specific repositories

All facades are constructed via `MultiProvider` at the app root. UI must access them through `context.read<T>()` - never through `.instance` directly. App-layer code receives them through constructors. v0.2.5 facades/repos/controllers must not expose `.instance` at all.

`EventStream.rawEvents` is restricted to debug screens only (`survival_mode_screen.dart`). Production UI must use typed streams: `sosAlerts`, `matchUpdates`, `hazardEvents`, `supplyChanges`.

New facades require an ADR amendment.

## Consequences
- UI never sees protobuf types, raw SQL, `EventManager`/`MeshEventHandler`, or raw `MeshDataReceived` directly.
- Constructor injection + root Provider wiring makes facade dependencies explicit and testable.
- v0.3 Envelope v2 can rewrite mesh internals without touching UI.
- Domain-specific repos (NegotiationRepo, StationSupplyRepo, MedicalCardRepo, ProfileRepo) prevent a god-EventStore anti-pattern.

## Open Questions
- How does this contract evolve under v0.3 Envelope v2? (Answer: EventStream's underlying stream type may change; typed streams stay stable.)
- Does EventPublisher survive v0.3? (Answer: likely yes, method signatures may evolve but facade pattern remains.)

## Status
Accepted on 2026-05-13.
```

### 7.4 PR Review Checklist

**File**: `docs/PR_CHECKLIST.md` (or `.github/pull_request_template.md`)

```markdown
## Architecture
- [ ] No new imports from `lib/ui/` to `lib/app/mesh/`, `lib/app/proto/`, or `lib/app/db/`.
- [ ] No new imports from `lib/platform/` to `lib/app/`.
- [ ] `dart run tool/check_layers.dart` passes locally.
- [ ] No new file exceeds 800 lines without Controller / View / Repository split.
- [ ] No new `.instance` / factory-singleton entry point added for v0.2.5 facades, repositories, or controllers.
- [ ] New dependencies are wired at the app root and injected through constructors.
- [ ] UI code accesses facades via `context.read<T>()`, not `.instance`.
- [ ] UI code does not directly call legacy app-layer singleton entry points (`.instance`, `EventManager()`, `MeshEventHandler()`, `DatabaseHelper()`, `LocationService()`, `ChatService()`, etc.).

## Wire Format
- [ ] No raw `pb.X.fromBuffer(...)` outside `app/services/event_decoder.dart`.
- [ ] No new EventType constant added without corresponding proto enum value.
- [ ] Wire format golden tests still pass.
- [ ] No production UI uses `EventStream.rawEvents` (debug-only).

## Tests
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] New behavior has test coverage.
```

### 7.5 Commit Plan

| Commit | Description |
|---|---|
| 5.1 | Create `CLAUDE.md` with Architecture Layer Rules section. |
| 5.2 | Create `docs/architecture/ADR-001-layering-rules.md`. |
| 5.3 | Create `docs/architecture/ADR-002-mesh-to-ui-contract.md`. |
| 5.4 | Create `docs/PR_CHECKLIST.md`. |

### 7.6 Acceptance Criteria

- [ ] `CLAUDE.md` exists and contains all 6 rules, facade locations, and rules
- [ ] `docs/architecture/ADR-001-layering-rules.md` exists with standard ADR format
- [ ] `docs/architecture/ADR-002-mesh-to-ui-contract.md` exists with standard ADR format
- [ ] PR checklist exists and matches enforced rules

---

## 8. Cross-Stage Testing Matrix

| Test | Stage 1 | Stage 2A | Stage 2B | Stage 3 | Stage 4 | Stage 5 |
|---|---|---|---|---|---|---|
| `flutter test` | after each commit | after each commit | after each commit | yes | yes | N/A |
| `flutter analyze` | after each commit | after each commit | after each commit | yes | yes | N/A |
| `check_layers --strict` | after 1.8 | yes | yes | baseline reset | N/A | N/A |
| Import grep | after 1.8 | yes | yes | yes | N/A | N/A |
| Manual smoke - hazard dialog | after 1.2 | N/A | N/A | N/A | N/A | N/A |
| Manual smoke - resource request | after 1.2 | N/A | N/A | N/A | N/A | N/A |
| Manual smoke - supply registration | after 1.2 | N/A | N/A | N/A | N/A | N/A |
| Manual smoke - event info sheet | after 1.2 | N/A | N/A | N/A | N/A | N/A |
| Manual smoke - match flow | after 1.3 | after 2A.4 | N/A | N/A | N/A | N/A |
| Manual smoke - physical handoff | after 1.3 | after 2A.6 | N/A | N/A | N/A | N/A |
| Manual smoke - main shell SOS | after 1.4 | N/A | N/A | N/A | N/A | N/A |
| Manual smoke - station supply | after 1.4 | after 2A.2 | N/A | N/A | N/A | N/A |
| Manual smoke - map screen | after 1.4 | N/A | N/A | N/A | N/A | N/A |
| Manual smoke - medical card | N/A | N/A | after 2B.2 | N/A | N/A | N/A |
| Manual smoke - profile | after 1.4 | N/A | after 2B.3 | N/A | N/A | N/A |
| Manual smoke - survival mode | after 1.4 | after 2A.7 | N/A | N/A | N/A | N/A |
| Line count verification | N/A | after 2A.8 | after 2B.4 | N/A | N/A | N/A |
| Golden tests | N/A | N/A | N/A | N/A | after 4.2 | N/A |
| Documentation existence | N/A | N/A | N/A | N/A | N/A | after 5.4 |

---
## 9. Completion Criteria Checklist

### 9.1 Mechanical Checks

- [ ] `dart run tool/check_layers.dart --strict` passes. Baseline file contains only comments.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes. Exactly one new `@Skip`-marked test allowed: EventType drift test.
- [ ] `grep -r "import 'package:ignirelay_app/app/mesh/" lib/ui/` returns empty.
- [ ] `grep -r "import 'package:ignirelay_app/app/proto/" lib/ui/` returns empty.
- [ ] `grep -r "import 'package:ignirelay_app/app/db/" lib/ui/` returns empty.
- [ ] `grep -r "import 'package:ignirelay_app/app/" lib/platform/` returns empty.
- [ ] `rg "EventManager\(\)|MeshEventHandler\(\)|DatabaseHelper\(\)|BleManager\(\)|LocationService\(\)|ChatService\(|[A-Za-z]+Controller\.instance" lib/ui` returns empty.
- [ ] `rg "static final .*instance|factory .*=> .*_instance|factory .*\\(\\) => _instance" lib/app/controllers/event_publisher.dart lib/app/controllers/event_stream.dart lib/app/services/event_decoder.dart lib/app/services/event_store.dart lib/app/services/station_supply_repo.dart lib/app/services/profile_repo.dart` returns empty.
- [ ] `grep -r "rawEvents" lib/ui/` matches only `survival_mode_screen.dart`.
- [ ] `wc -l lib/ui/secondary/station_supply_screen.dart` reports <=500 lines (was 1344).
- [ ] `wc -l lib/ui/secondary/medical_card_screen.dart` reports <=500 lines (was 1031).
- [ ] Each god file in brief §2.4 (except `map_screen_controller.dart`) is <=500 lines OR has explicit exception comment.

### 9.2 Documentation Checks

- [ ] `CLAUDE.md` contains "Architecture Layer Rules" section.
- [ ] `docs/architecture/ADR-001-layering-rules.md` exists.
- [ ] `docs/architecture/ADR-002-mesh-to-ui-contract.md` exists.
- [ ] `docs/PR_CHECKLIST.md` (or `.github/pull_request_template.md`) exists.

### 9.3 Behavioral Checks

- [ ] All existing smoke tests of UI behavior pass.
- [ ] Automated controller/widget tests cover every split screen where practical.
- [ ] Manual smoke test of each affected UI screen confirms identical behavior:
  - SOS alert in main shell
  - Hazard dialog publish
  - Match negotiation flow end-to-end
  - Station supply create / claim / quota reset
  - Medical card create / edit / save
  - Physical handoff full flow
  - Map screen pan / zoom / hazard / event display
  - Profile screen display and settings
  - Survival mode debug log display

If any behavioral regression is detected, v0.2.5 is NOT complete regardless of mechanical checks.

---

## 10. Out-of-Scope Confirmations

The following are explicitly NOT done in v0.2.5:

| Item | Reason | Owner |
|---|---|---|
| Protocol redesign (EventType enum, envelope format, TTL, priority) | Wire format work is v0.3 | v0.3 Envelope v2 |
| Splitting `event_manager.dart`, `mesh_event_handler.dart`, `ble_manager.dart` | v0.3 rewrites these; double work otherwise | v0.3 |
| Removing every internal legacy singleton implementation | v0.2.5 removes UI direct access to legacy singleton entry points and blocks new singleton debt, but it does not rewrite every existing internal singleton class in the app | v0.4 or later |
| `map_screen_controller.dart` split | Already organized (Controller/View/Repository pattern) | Never |
| `design_showcase_screen.dart` cleanup | Demo file, no boundary coupling | Never |
| New features | v0.2.5 is debt-only | v0.3 Stage 1 |
| Performance optimization | Recent perf work covers current targets | v0.3 dogfood feedback |
| iOS support hardening | Independent track | TBD |
| L10n cleanup | Generated files, no boundary impact | Never |
| Test refactoring | Existing tests stay; new tests added | v0.2.5 |






