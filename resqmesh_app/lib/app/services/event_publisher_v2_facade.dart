// EventPublisherV2Facade — Dart-side broadcast facade for the v0.3
// EventEnvelope v2 send path (Stage 0c wave 3E / 3E-r2 / 3E-r3 partial).
//
// SCOPE NOTE — this facade is the Dart half of the v0.3 publish path.
// Cross-platform Stage 0c (§3.4 of the roadmap) requires all three
// lanes (0c1/0c2/0c3) green; the iOS native side is still in port
// (Swift Chunker + CanonicalEncoderV2 + debug hooks). 3E-r3 closes the
// Dart + Android-native gaps the QA review surfaced; iOS parity is a
// separate follow-up wave. Until iOS lands, the most we can claim is
// "Android-pair 0d-preflight ready" — not "Stage 0c complete".
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md + native_transport_v1.md.
//
// PURPOSE
//
// Stage 0c waves 3A-3D landed the per-peer v2 pipeline (MessagePublisherV2,
// BleV2Bridge.sendEnvelope). The 0d real-device gate (see brief §3.5)
// requires that the CORE event types it tests — SOS_RED, HAZARD_MARKER,
// STATUS_UPDATE, CHAT_MESSAGE — actually flow through that v2 pipeline,
// not through the legacy v0.2 EventPublisher → EventManager → raw
// MeshEvent path.
//
// This facade is the migration-window adapter: app-layer callers
// (EventPublisher dual-write, StatusController, HazardOverlay, ChatService)
// hold a `EventPublisherV2Facade` instead of (or in addition to) the
// legacy `EventPublisher`. The facade builds the envelope, iterates the
// registry's active peers, and dispatches via `BleV2Bridge.sendEnvelope`
// to each. Outcomes are aggregated into a `BroadcastOutcome` so callers
// see one accept/reject summary per call instead of per-peer noise.
//
// LIFECYCLE (3E-r2 fix — important)
//
// In wave 3E-r1 the facade was constructed inside the async `_startV2Bridge()`
// path, which meant the Provider for it was nullable AND value-based. UI
// reading from Provider almost always saw `null` because the async init
// finishes AFTER the first `build()` and Provider does not rebuild when
// a module-level variable mutates.
//
// 3E-r2 fix: the facade is now constructed EAGERLY at app startup with
// just the registry. The bridge is attached later via [attachBridge].
// Sends issued BEFORE the bridge arrives are recorded into an in-memory
// pending queue and replayed automatically once the bridge attaches AND
// a peer reaches `isReadyForTraffic`. Provider exposes a non-null facade
// from the first frame.
//
// LOCAL QUEUE (3E-r2 fix)
//
// When `_broadcast` finds zero active peers, it now enqueues the publish
// request into an in-memory pending queue (bounded; oldest is dropped at
// cap) and returns `BroadcastOutcome.queued()`. The queue is drained on
// `PeerCapabilityRegistry.changes` whenever any peer becomes
// `isReadyForTraffic`. Each queued entry retains its ORIGINAL HLC
// timestamp pair so spec §10.2 LWW semantics are preserved across the
// queue→peer window.
//
// PERSISTENCE (Stage 0c wave 3F + 3F-r3 — Outbox_V2):
//   The pending queue is mirrored to the `Outbox_V2` SQLite table
//   (schema v11, see `database_helper.dart` `_createOutboxV2Table`).
//   Behavior:
//     • The envelope_id (16-byte UUIDv7) is pre-allocated AT
//       `_broadcast()` time — BEFORE the queue-vs-immediate-send branch
//       and BEFORE disk write. Both paths use the same id, so the in-
//       memory `_PendingPublish` and its Outbox_V2 row agree, and a
//       restart-driven re-drain emits the SAME envelope_id the first
//       attempt did. This is what makes re-delivery idempotent —
//       receiver-side dedup on `Envelopes_V2.envelope_id` PK +
//       `Tombstones_V2` drops the duplicate.
//     • Wave 3F-r3 fix — earlier 3F implementation let
//       `MessagePublisherV2.send()` mint a fresh UUIDv7 every drain,
//       defeating receiver dedup for non-LWW events (SOS_RED,
//       HAZARD_MARKER, CHAT_MESSAGE) and producing duplicates on the
//       receiver after a restart-mid-drain. Now closed.
//     • On facade construction (with a non-null `db:` arg) hydration
//       reads up to `kMaxPendingEntries` rows ordered by `id ASC`
//       (= FIFO) and rebuilds the in-memory queue, restoring each
//       row's persisted envelope_id. Already-expired or
//       past-`kPendingEntryMaxAge` rows are pruned during hydration.
//     • Every `_enqueue` mirrors to disk (fire-and-forget — disk failure
//       degrades to pre-3F in-memory behavior, never blocks publish).
//     • Every successful drain delivery, TTL expiry, and cap-eviction
//       deletes the row.
//     • The per-entry `deliveredTo` Set is intentionally NOT persisted.
//       After a restart we may re-deliver to peers we already reached;
//       receiver-side dedup on the (now-stable) envelope_id makes that
//       idempotent. A junction table per peer would be cleaner but is
//       overkill for wave 3F.
//   Pass `db: null` (the default) in tests / in-memory mode to opt out.
//
// MIGRATION STATUS (Stage 0c wave 3E — KEEP THIS LIST CURRENT)
//
//   v2 routes today (eligible for 0d testing):
//     - PROTOCOL_HELLO  (already shipped per wave 3A; ProtocolHelloService)
//     - SOS_RED / SOS_YELLOW STATUS_UPDATE  (this facade, publishSosStatus)
//     - HAZARD_MARKER                       (this facade, publishHazardMarker)
//     - CHAT_MESSAGE                        (this facade, publishChatMessage)
//     - STATUS_UPDATE (non-SOS)             (this facade, publishStatusUpdate)
//   Dual-write entry points (legacy v0.2 + v2):
//     - EventPublisher.publishEvent              → publishStatusUpdate
//       (urgency mapped to safetyState; the facade applies the spec §5.3
//       payload-implied priority floor — SOS_RED for TRAPPED, SOS_YELLOW
//       for INJURED / urgent need, STATUS otherwise. The dispatch DOES
//       NOT branch into publishSosStatus from the legacy side; the floor
//       lives inside publishStatusUpdate so all callers go through ONE
//       priority-derivation path. publishSosStatus is now a thin
//       priority-hinted wrapper for direct callers that already know.)
//     - EventPublisher.publishHazard             → publishHazardMarker
//     - EventPublisher.publishChatMessage        → publishChatMessage
//     - ChatService.sendMessage                  → publishChatMessage
//       (the production chat UI calls ChatService directly, bypassing
//       EventPublisher, so ChatService also attaches this facade at
//       startup. Without that mirror path, local chat rows never traverse
//       the v0.3 chunked BLE bridge.)
//
//   Still on legacy path only (NOT 0d-eligible; legacy EventPublisher → v0.2):
//     - SUPPLY_REQUEST / SUPPLY_OFFER       (existing match/supply flow)
//     - MATCH_INTENT / NEGOTIATION          (existing match flow)
//     - RELAY_TO_CONTACT                    (existing relay flow)
//     - SHELTER_STATUS                      (UI surface not yet built)
//     - OFFICIAL_ALERT_CAP / SUMMARY        (no in-app authoring surface)
//     - BATTERY_STATUS / HEARTBEAT          (not user-facing)
//     - TRACE_PING / TRACE_ACK              (dev-mode only)
//
// 0d gate test runner MUST publish via this facade for the four core
// types; tests touching the still-on-legacy list MUST be flagged as
// "legacy path" so QA does not misread a v0.2 success as v0.3 acceptance.
//
// ARCHITECTURE NOTE — why a facade, not direct UI access to BleV2Bridge:
//   - UI layer per CLAUDE.md must not import `lib/app/mesh/**` or
//     `lib/app/proto/**`. The facade lives in `lib/app/services/` and
//     exposes only primitive types (int / Uint8List / String). UI calls
//     `context.read<EventPublisherV2Facade>().publishSos(...)` and gets a
//     `BroadcastOutcome` back. No protobuf types leak into UI.
//   - BleV2Bridge is per-peer; the facade is broadcast. Mixing the two
//     concerns in one class would force UI to know about peer discovery
//     state, which is the BLE layer's job.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:ignirelay_app/app/controllers/message_publisher_v2.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/ble_v2_bridge.dart';
import 'package:ignirelay_app/app/services/peer_capability_registry.dart';
import 'package:ignirelay_app/app/crdt/hlc.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

/// Per-peer outcome aggregated into the broadcast summary.
class PeerSendOutcome {
  final String peerId;
  final bool sent;
  final String? dropReason;
  final String? detail;
  const PeerSendOutcome({
    required this.peerId,
    required this.sent,
    this.dropReason,
    this.detail,
  });
}

/// Returned to UI for one publish call. `anyAccepted` is the cheap
/// "did at least one peer ack this" signal; per-peer detail is in
/// `outcomes` for dev-mode trace inspection.
class BroadcastOutcome {
  /// True iff at least one active peer accepted the wire write. A `false`
  /// result is NOT necessarily a failure — see `queued`.
  final bool anyAccepted;

  /// Number of active peers attempted.
  final int attempted;

  /// Per-peer detail. May be empty when `attempted == 0`.
  final List<PeerSendOutcome> outcomes;

  /// True when the publish was held in the local pending queue because no
  /// active peer or no bridge was available. UI should treat this as
  /// "queued locally, will retry when peer arrives", NOT a failure.
  final bool queued;

  /// Depth of the local pending queue immediately after this call. Useful
  /// for trace inspection. Always 0 unless `queued`.
  final int pendingDepth;

  const BroadcastOutcome({
    required this.anyAccepted,
    required this.attempted,
    required this.outcomes,
    this.queued = false,
    this.pendingDepth = 0,
  });

  factory BroadcastOutcome.noActivePeers() => const BroadcastOutcome(
        anyAccepted: false,
        attempted: 0,
        outcomes: [],
      );

  factory BroadcastOutcome.queued(int depth) => BroadcastOutcome(
        anyAccepted: false,
        attempted: 0,
        outcomes: const [],
        queued: true,
        pendingDepth: depth,
      );

  factory BroadcastOutcome.bridgeNotReady(int depth) => BroadcastOutcome(
        anyAccepted: false,
        attempted: 0,
        outcomes: const [],
        queued: true,
        pendingDepth: depth,
      );
}

/// Internal: an entry queued for later delivery. Holds the ORIGINAL HLC
/// timestamps so LWW semantics are preserved even if delivery is delayed.
class _PendingPublish {
  /// Pre-allocated 16-byte UUIDv7 (wave 3F-r3). Stable across the
  /// in-memory → Outbox_V2 → restart → re-drain cycle so receiver-side
  /// dedup on `Envelopes_V2.envelope_id` PK is idempotent.
  final Uint8List envelopeId;
  final int eventType;
  final int priority;
  final Uint8List payload;
  final HlcTimestampV2 createdAtHlc;
  final HlcTimestampV2 expiresAtHlc;
  final int maxHops;
  final DateTime enqueuedAt;
  final Set<String> deliveredTo = <String>{};

  /// SQLite `Outbox_V2.id` for entries that are mirrored to disk. `null`
  /// when running without a [DatabaseHelper] (tests / in-memory mode) or
  /// when persistence write failed (entry still lives in memory).
  int? outboxRowId;

  _PendingPublish({
    required this.envelopeId,
    required this.eventType,
    required this.priority,
    required this.payload,
    required this.createdAtHlc,
    required this.expiresAtHlc,
    required this.maxHops,
    required this.enqueuedAt,
    this.outboxRowId,
  });
}

class EventPublisherV2Facade {
  /// Cap on the local pending queue. Older entries are dropped first
  /// (FIFO). Chosen so a small mesh with intermittent peers can absorb
  /// short outages but a wedged bridge cannot leak memory.
  static const int kMaxPendingEntries = 256;

  /// Pending entries older than this are dropped on drain attempts. Spec
  /// §11.2 default TTLs range 12-24 h; this is a SECOND-LEVEL guard for
  /// the in-memory queue, not the envelope-level TTL.
  static const Duration kPendingEntryMaxAge = Duration(hours: 24);

  final PeerCapabilityRegistry _registry;
  BleV2Bridge? _bridge;
  StreamSubscription<PeerCapabilityState>? _registrySub;
  final ListQueue<_PendingPublish> _pending = ListQueue<_PendingPublish>();
  final DateTime Function() _now;
  bool _draining = false;

  /// Optional persistence backing for the pending queue (wave 3F). When
  /// present, every `_enqueue` mirrors to `Outbox_V2` and successful drains
  /// / TTL expiries / cap-eviction delete the row. When `null` (tests,
  /// in-memory mode), the facade falls back to pre-3F behavior — queue
  /// lives only in RAM and dies with the process.
  final DatabaseHelper? _db;

  /// Pre-allocation factory for the 16-byte UUIDv7 envelope_id (wave
  /// 3F-r3). Defaults to [MessagePublisherV2.newEnvelopeId] so the
  /// generator is the spec-locked RFC 9562 §5.7 implementation; tests
  /// inject a deterministic factory to assert stability across the
  /// queue → restart → re-drain window.
  final Uint8List Function() _newEnvelopeId;

  /// Completes once the initial hydration from `Outbox_V2` has finished
  /// (or immediately when `_db == null`). Visible-for-testing so tests
  /// can `await facade.hydrationDone` before asserting queue depth.
  late final Future<void> _hydration;

  EventPublisherV2Facade({
    required PeerCapabilityRegistry registry,
    BleV2Bridge? bridge,
    DateTime Function()? now,
    DatabaseHelper? db,
    Uint8List Function()? envelopeIdFactory,
  })  : _registry = registry,
        _bridge = bridge,
        _now = now ?? DateTime.now,
        _db = db,
        _newEnvelopeId = envelopeIdFactory ?? MessagePublisherV2.newEnvelopeId {
    _registrySub = _registry.changes.listen(_onPeerStateChange);
    _hydration = _hydrateFromOutbox();
  }

  /// Visible-for-tests: resolves once the initial hydration from
  /// `Outbox_V2` has settled (immediately when no DB is provided).
  @visibleForTesting
  Future<void> get hydrationDone => _hydration;

  /// Number of entries currently waiting in the pending queue. Visible to
  /// UI / trace inspectors for diagnostic banners ("3 messages queued,
  /// waiting for peer").
  int get pendingQueueDepth => _pending.length;

  /// `true` once a bridge is attached. UI MAY use this to show a "v0.3
  /// transport not yet ready, queueing locally" hint, but generally
  /// callers can just publish and rely on the queue.
  bool get isBridgeReady => _bridge != null;

  /// Attach the BLE bridge once async init is done. Idempotent: calling
  /// twice with the same bridge is a no-op; calling with a different
  /// bridge replaces the prior one. Triggers an immediate drain attempt.
  void attachBridge(BleV2Bridge bridge) {
    if (identical(_bridge, bridge)) return;
    _bridge = bridge;
    unawaited(_drainQueue());
  }

  /// Detach the bridge (e.g., during teardown). Pending entries stay in
  /// the queue and will resume drain once `attachBridge` is called again.
  void detachBridge() {
    _bridge = null;
  }

  Future<void> dispose() async {
    await _registrySub?.cancel();
    _registrySub = null;
    _pending.clear();
  }

  // ── 0d-eligible publish surfaces ──────────────────────────────────────

  /// Publish a SOS_RED STATUS_UPDATE — the highest-priority 0d gate path.
  /// Payload is a [StatusUpdateData] with `safetyState = TRAPPED` (or
  /// caller-supplied). Caller supplies the structured `needs` list; this
  /// facade does NOT auto-derive needs from UI state (that's the
  /// controller's job).
  ///
  /// The effective wire priority is `max(caller, payload-implied floor)`
  /// per spec §5.3 (`impliedPriorityFloor()`). Calling this method with
  /// `safetyState == SAFE` and no urgent needs WILL be downgraded to
  /// STATUS before publish — that is intentional. The dispatcher's
  /// `_resolvePriority` re-validates against the §6 matrix on the
  /// receiver side, but the SENDER is now spec-compliant too.
  Future<BroadcastOutcome> publishSosStatus({
    required int safetyState,
    List<NeedEntry> needs = const [],
  }) {
    return publishStatusUpdate(
      safetyState: safetyState,
      needs: needs,
      priority: PriorityV2.sosRed,
    );
  }

  /// Publish a STATUS_UPDATE (UI "I'm safe" / "I need water" / "trapped").
  ///
  /// Spec §5.3 — the sender computes envelope `priority` as the maximum
  /// (most severe) of the caller's hint and the payload-derived floor:
  ///
  /// | Payload condition                | Implied priority floor |
  /// |----------------------------------|------------------------|
  /// | `safetyState == TRAPPED`         | SOS_RED                |
  /// | `safetyState == INJURED`         | SOS_YELLOW             |
  /// | any `needs[].severity == URGENT` | SOS_YELLOW             |
  /// | otherwise                        | STATUS                 |
  ///
  /// Wave 3E-r3 fix: the 3E-r2 implementation passed `caller.priority`
  /// straight through, which let `urgency == 2` (INJURED) leave the
  /// device at PRIORITY_STATUS — the receiver would then never see this
  /// as an SOS-class event and never priority-route it across the mesh.
  /// We now apply the floor unconditionally before calling `_broadcast`.
  /// `StatusUpdateData.impliedPriorityFloor()` is the canonical source.
  Future<BroadcastOutcome> publishStatusUpdate({
    required int safetyState,
    List<NeedEntry> needs = const [],
    int priority = PriorityV2.status,
  }) {
    final data = StatusUpdateData(safetyState: safetyState, needs: needs);
    // Spec §5.3 — sender priority MUST be at least as severe as the
    // payload-implied floor. PriorityV2.moreSevere returns the smaller
    // numeric value (lower = more severe) per priority_matrix_v2.dart.
    final effectivePriority =
        PriorityV2.moreSevere(priority, data.impliedPriorityFloor());
    return _broadcast(
      eventType: EventTypeV2.statusUpdate,
      priority: effectivePriority,
      payload: data.encode(),
      ttlOffset: const Duration(hours: 12), // §11.2 STATUS_UPDATE default
      maxHops: EventTypeV2.maxHopsDefault(EventTypeV2.statusUpdate) ?? 6,
    );
  }

  /// Publish a HAZARD_MARKER (raw payload bytes; the facade does NOT yet
  /// decode HazardMarkerData because that proto is still in `lib/app/mesh/`
  /// legacy land. Callers SHOULD construct the bytes themselves until the
  /// v0.4 HazardMarkerData v2 proto lands).
  Future<BroadcastOutcome> publishHazardMarker({
    required Uint8List payload,
    int priority = PriorityV2.alert,
  }) {
    return _broadcast(
      eventType: EventTypeV2.hazardMarker,
      priority: priority,
      payload: payload,
      ttlOffset: const Duration(hours: 24), // §11.2 HAZARD_MARKER default
      maxHops: EventTypeV2.maxHopsDefault(EventTypeV2.hazardMarker) ?? 10,
    );
  }

  /// Publish a CHAT_MESSAGE. Payload is the UTF-8 encoded chat text plus
  /// any room-routing prefix the ChatService chooses. The facade is
  /// agnostic to chat envelope shape; it only wraps + signs + dispatches.
  Future<BroadcastOutcome> publishChatMessage({
    required Uint8List payload,
  }) {
    return _broadcast(
      eventType: EventTypeV2.chatMessage,
      priority: PriorityV2.normal,
      payload: payload,
      ttlOffset: const Duration(hours: 24), // §11.2 CHAT_MESSAGE default
      maxHops: EventTypeV2.maxHopsDefault(EventTypeV2.chatMessage) ?? 6,
    );
  }

  // ── Core broadcast loop ───────────────────────────────────────────────

  Future<BroadcastOutcome> _broadcast({
    required int eventType,
    required int priority,
    required Uint8List payload,
    required Duration ttlOffset,
    required int maxHops,
  }) async {
    final hlc = HLC.now();
    final createdAtHlc =
        HlcTimestampV2(msSinceEpoch: hlc.timestamp, counter: hlc.counter);
    final expiresAtHlc = HlcTimestampV2(
      msSinceEpoch: hlc.timestamp + ttlOffset.inMilliseconds,
      counter: 0,
    );

    // Wave 3F-r3 — pre-allocate envelope_id BEFORE the queue / immediate
    // branch so the in-memory queue, the Outbox_V2 row, and any
    // restart-driven re-drain all use the SAME id. Without this, receiver
    // dedup on `Envelopes_V2.envelope_id` PK would treat each restart-
    // driven attempt as a fresh event and surface duplicates for non-LWW
    // types (SOS / HAZARD / CHAT).
    final envelopeId = _newEnvelopeId();

    final bridge = _bridge;
    if (bridge == null) {
      _enqueue(_PendingPublish(
        envelopeId: envelopeId,
        eventType: eventType,
        priority: priority,
        payload: payload,
        createdAtHlc: createdAtHlc,
        expiresAtHlc: expiresAtHlc,
        maxHops: maxHops,
        enqueuedAt: _now(),
      ));
      return BroadcastOutcome.bridgeNotReady(_pending.length);
    }

    final active = _registry.allStates
        .where((s) => s.isReadyForTraffic)
        .map((s) => s.peerId)
        .toList(growable: false);
    if (active.isEmpty) {
      _enqueue(_PendingPublish(
        envelopeId: envelopeId,
        eventType: eventType,
        priority: priority,
        payload: payload,
        createdAtHlc: createdAtHlc,
        expiresAtHlc: expiresAtHlc,
        maxHops: maxHops,
        enqueuedAt: _now(),
      ));
      return BroadcastOutcome.queued(_pending.length);
    }

    return _sendToPeers(
      bridge: bridge,
      peers: active,
      envelopeId: envelopeId,
      eventType: eventType,
      priority: priority,
      payload: payload,
      createdAtHlc: createdAtHlc,
      expiresAtHlc: expiresAtHlc,
      maxHops: maxHops,
    );
  }

  Future<BroadcastOutcome> _sendToPeers({
    required BleV2Bridge bridge,
    required List<String> peers,
    required Uint8List envelopeId,
    required int eventType,
    required int priority,
    required Uint8List payload,
    required HlcTimestampV2 createdAtHlc,
    required HlcTimestampV2 expiresAtHlc,
    required int maxHops,
    Set<String>? skip,
  }) async {
    final outcomes = <PeerSendOutcome>[];
    var anyAccepted = false;
    for (final peerId in peers) {
      if (skip != null && skip.contains(peerId)) continue;
      final tx = await bridge.sendEnvelope(
        peerId: peerId,
        envelopeId: envelopeId,
        eventType: eventType,
        priority: priority,
        payload: payload,
        createdAtHlc: createdAtHlc,
        expiresAtHlc: expiresAtHlc,
        maxHops: maxHops,
      );
      if (tx.sent) anyAccepted = true;
      outcomes.add(PeerSendOutcome(
        peerId: peerId,
        sent: tx.sent,
        dropReason: tx.dropReason,
        detail: tx.detail,
      ));
    }
    return BroadcastOutcome(
      anyAccepted: anyAccepted,
      attempted: outcomes.length,
      outcomes: outcomes,
    );
  }

  // ── Pending queue plumbing ────────────────────────────────────────────

  void _enqueue(_PendingPublish entry) {
    if (_pending.length >= kMaxPendingEntries) {
      final dropped = _pending.removeFirst();
      debugPrint(
        '[EventPublisherV2Facade] pending queue at cap '
        '($kMaxPendingEntries); dropped oldest event_type=${dropped.eventType}',
      );
      unawaited(_deleteOutboxRow(dropped));
    }
    _pending.addLast(entry);
    unawaited(_persistEntry(entry));
  }

  // ── Outbox_V2 persistence (wave 3F) ───────────────────────────────────
  //
  // All three helpers are fire-and-forget by design: the in-memory queue
  // is the source of truth for delivery decisions, and SQLite is just a
  // restart-survival mirror. A failed disk write logs to debugPrint and
  // continues; correctness still depends on the in-memory state, so a
  // wedged disk doesn't wedge the mesh.

  Future<void> _hydrateFromOutbox() async {
    final db = _db;
    if (db == null) return;
    try {
      final rows = await (await db.database).query(
        'Outbox_V2',
        orderBy: 'id ASC',
        limit: kMaxPendingEntries,
      );
      if (rows.isEmpty) return;
      final now = _now();
      for (final row in rows) {
        final enqueuedAtMs = row['enqueued_at_ms'] as int;
        final expiresAtMs = row['expires_at_hlc_ms'] as int;
        final enqueuedAt = DateTime.fromMillisecondsSinceEpoch(enqueuedAtMs);
        // Drop stale-on-load entries up front so we don't hydrate
        // already-expired rows just to drop them on the next drain.
        if (now.difference(enqueuedAt) > kPendingEntryMaxAge ||
            expiresAtMs < now.millisecondsSinceEpoch) {
          final id = row['id'] as int;
          await (await db.database)
              .delete('Outbox_V2', where: 'id = ?', whereArgs: [id]);
          continue;
        }
        final entry = _PendingPublish(
          envelopeId: Uint8List.fromList(row['envelope_id'] as List<int>),
          eventType: row['event_type'] as int,
          priority: row['priority'] as int,
          payload: Uint8List.fromList(row['payload'] as List<int>),
          createdAtHlc: HlcTimestampV2(
            msSinceEpoch: row['created_at_hlc_ms'] as int,
            counter: row['created_at_hlc_ctr'] as int,
          ),
          expiresAtHlc: HlcTimestampV2(
            msSinceEpoch: expiresAtMs,
            counter: row['expires_at_hlc_ctr'] as int,
          ),
          maxHops: row['max_hops'] as int,
          enqueuedAt: enqueuedAt,
          outboxRowId: row['id'] as int,
        );
        _pending.addLast(entry);
      }
      debugPrint(
        '[EventPublisherV2Facade] hydrated ${_pending.length} pending '
        'entries from Outbox_V2',
      );
      // If a bridge is already attached (rare — usually hydration happens
      // before attachBridge) and the registry has ready peers, kick off
      // a drain so we don't wait for the next peer-state change.
      if (_bridge != null) {
        unawaited(_drainQueue());
      }
    } catch (e, st) {
      debugPrint(
        '[EventPublisherV2Facade] Outbox_V2 hydration failed: $e\n$st',
      );
    }
  }

  Future<void> _persistEntry(_PendingPublish entry) async {
    final db = _db;
    if (db == null) return;
    if (entry.outboxRowId != null) return; // already persisted
    try {
      final id = await (await db.database).insert('Outbox_V2', {
        'envelope_id': entry.envelopeId,
        'event_type': entry.eventType,
        'priority': entry.priority,
        'payload': entry.payload,
        'created_at_hlc_ms': entry.createdAtHlc.msSinceEpoch,
        'created_at_hlc_ctr': entry.createdAtHlc.counter,
        'expires_at_hlc_ms': entry.expiresAtHlc.msSinceEpoch,
        'expires_at_hlc_ctr': entry.expiresAtHlc.counter,
        'max_hops': entry.maxHops,
        'enqueued_at_ms': entry.enqueuedAt.millisecondsSinceEpoch,
      });
      entry.outboxRowId = id;
    } catch (e) {
      debugPrint('[EventPublisherV2Facade] Outbox_V2 insert failed: $e');
    }
  }

  Future<void> _deleteOutboxRow(_PendingPublish entry) async {
    final db = _db;
    if (db == null) return;
    final id = entry.outboxRowId;
    if (id == null) return;
    try {
      await (await db.database)
          .delete('Outbox_V2', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[EventPublisherV2Facade] Outbox_V2 delete failed: $e');
    }
  }

  void _onPeerStateChange(PeerCapabilityState s) {
    if (!s.isReadyForTraffic) return;
    if (_pending.isEmpty) return;
    if (_bridge == null) return;
    unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    if (_draining) return;
    final bridge = _bridge;
    if (bridge == null) return;
    _draining = true;
    try {
      // Drop stale entries up front so we never spend time re-encoding /
      // signing payloads that are already past TTL.
      final now = _now();
      while (_pending.isNotEmpty) {
        final head = _pending.first;
        final tooOld = now.difference(head.enqueuedAt) > kPendingEntryMaxAge;
        final ttlExpired =
            head.expiresAtHlc.msSinceEpoch < now.millisecondsSinceEpoch;
        if (tooOld || ttlExpired) {
          final dropped = _pending.removeFirst();
          unawaited(_deleteOutboxRow(dropped));
          continue;
        }
        break;
      }

      // Snapshot the list of currently active peers ONCE per drain pass
      // so a long burst of registry change events does not cause
      // re-entrant drains.
      final activePeers = _registry.allStates
          .where((s) => s.isReadyForTraffic)
          .map((s) => s.peerId)
          .toList(growable: false);
      if (activePeers.isEmpty) return;

      // Walk the queue from oldest to newest; each entry tries every
      // active peer it has not yet been delivered to. Entries that get
      // delivered to ALL currently-active peers are removed; entries
      // that get delivered to SOME are kept so a later peer can still
      // receive them.
      final remaining = <_PendingPublish>[];
      while (_pending.isNotEmpty) {
        final entry = _pending.removeFirst();
        final targets = activePeers
            .where((p) => !entry.deliveredTo.contains(p))
            .toList(growable: false);
        if (targets.isEmpty) {
          remaining.add(entry);
          continue;
        }
        final outcome = await _sendToPeers(
          bridge: bridge,
          peers: targets,
          envelopeId: entry.envelopeId,
          eventType: entry.eventType,
          priority: entry.priority,
          payload: entry.payload,
          createdAtHlc: entry.createdAtHlc,
          expiresAtHlc: entry.expiresAtHlc,
          maxHops: entry.maxHops,
        );
        for (final o in outcome.outcomes) {
          if (o.sent) entry.deliveredTo.add(o.peerId);
        }
        // If at least one peer accepted, we consider this entry
        // "delivered" enough to remove (the mesh will fan it out via
        // the standard sync paths). If none accepted, keep it for the
        // next registry change.
        if (outcome.anyAccepted) {
          // Persisted entry can drop off disk now.
          unawaited(_deleteOutboxRow(entry));
        } else {
          remaining.add(entry);
        }
      }
      for (final r in remaining) {
        _pending.addLast(r);
      }
    } finally {
      _draining = false;
    }
  }
}
