// Priority × EventType validation matrix (v0.3 Stage 0c).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §6.
//
// Both sender and receiver run this matrix. The sender REJECTS at publish time
// when the (event_type, priority) pair would be downgraded or dropped; the
// receiver re-validates as defense in depth and either downgrades or drops
// (recording the outcome in `mesh_trace_logs`).
//
// `OFFICIAL_VERIFIED` source-trust short-circuits the OFFICIAL_ALERT_CAP rule
// (§6.2) — the dispatcher passes that bit through `MatrixContext`.

import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';

enum MatrixOutcome {
  /// Pair is allowed exactly as encoded; no priority change.
  accept,

  /// Pair is allowed only after downgrade to [downgradeTo].
  downgrade,

  /// Pair must be dropped; do NOT relay or surface.
  drop,
}

class MatrixDecision {
  final MatrixOutcome outcome;

  /// Set when outcome == [MatrixOutcome.downgrade].
  final int? downgradeTo;

  /// Drop reason string (one of the named codes in mesh_trace_logs §15.2).
  /// Set when outcome == [MatrixOutcome.drop] OR [MatrixOutcome.downgrade].
  final String? dropReason;

  const MatrixDecision.accept()
      : outcome = MatrixOutcome.accept,
        downgradeTo = null,
        dropReason = null;

  const MatrixDecision.downgrade(int to, {String reason = 'priority-downgraded'})
      : outcome = MatrixOutcome.downgrade,
        downgradeTo = to,
        dropReason = reason;

  const MatrixDecision.drop(String reason)
      : outcome = MatrixOutcome.drop,
        downgradeTo = null,
        dropReason = reason;
}

/// Source-trust enum mirrored locally; receivers populate this from the
/// `Official_Sources_V2` table or pairing store before invoking the matrix.
enum SourceTrust {
  self,
  paired,
  seenBefore,
  unverified,
  officialVerified,
}

class MatrixContext {
  final SourceTrust sourceTrust;

  const MatrixContext({this.sourceTrust = SourceTrust.unverified});
}

class PriorityMatrixV2 {
  /// Validate one (event_type, priority) pair. Spec §6.1 table is encoded
  /// below verbatim.
  static MatrixDecision check(
    int eventType,
    int priority, {
    MatrixContext context = const MatrixContext(),
  }) {
    switch (eventType) {
      case EventTypeV2.statusUpdate:
        return _allowedOrDowngrade(
          priority,
          allowed: const {PriorityV2.sosRed, PriorityV2.sosYellow, PriorityV2.status},
          downgradeTo: PriorityV2.status,
        );

      case EventTypeV2.batteryStatus:
        return _allowedOrDowngrade(
          priority,
          allowed: const {PriorityV2.status, PriorityV2.normal},
          downgradeTo: PriorityV2.status,
        );

      case EventTypeV2.supplyRequest:
        if (priority == PriorityV2.sosYellow || priority == PriorityV2.resource) {
          return const MatrixDecision.accept();
        }
        if (priority == PriorityV2.sosRed) {
          return const MatrixDecision.downgrade(PriorityV2.sosYellow);
        }
        if (priority == PriorityV2.normal) {
          return const MatrixDecision.downgrade(PriorityV2.resource);
        }
        return const MatrixDecision.drop('priority-mismatch');

      case EventTypeV2.supplyOffer:
        return _allowedOrDowngrade(
          priority,
          allowed: const {PriorityV2.resource},
          downgradeTo: PriorityV2.resource,
        );

      case EventTypeV2.matchIntent:
      case EventTypeV2.negotiation:
        return _allowedOrDowngrade(
          priority,
          allowed: const {PriorityV2.resource, PriorityV2.normal},
          downgradeTo: PriorityV2.resource,
        );

      case EventTypeV2.relayToContact:
        if (priority == PriorityV2.resource) {
          return const MatrixDecision.downgrade(PriorityV2.normal);
        }
        return _allowedOrDrop(
          priority,
          allowed: const {
            PriorityV2.sosRed,
            PriorityV2.sosYellow,
            PriorityV2.alert,
            PriorityV2.normal,
          },
          reason: 'priority-mismatch',
        );

      case EventTypeV2.hazardMarker:
        return _allowedOrDowngrade(
          priority,
          allowed: const {PriorityV2.sosRed, PriorityV2.sosYellow, PriorityV2.alert},
          downgradeTo: PriorityV2.alert,
        );

      case EventTypeV2.disasterReport:
        if (priority == PriorityV2.sosYellow || priority == PriorityV2.alert) {
          return const MatrixDecision.accept();
        }
        if (priority == PriorityV2.sosRed) {
          return const MatrixDecision.downgrade(PriorityV2.sosYellow);
        }
        return const MatrixDecision.drop('priority-mismatch');

      case EventTypeV2.shelterStatus:
        return _allowedOrDowngrade(
          priority,
          allowed: const {PriorityV2.alert, PriorityV2.status},
          downgradeTo: PriorityV2.alert,
        );

      case EventTypeV2.officialAlertCap:
        if (priority == PriorityV2.alert) return const MatrixDecision.accept();
        if (_isSos(priority)) {
          if (context.sourceTrust == SourceTrust.officialVerified) {
            return const MatrixDecision.downgrade(PriorityV2.alert);
          }
          return const MatrixDecision.drop('priority-mismatch');
        }
        return const MatrixDecision.drop('priority-mismatch');

      case EventTypeV2.officialAlertSummary:
        if (_isSos(priority)) {
          return const MatrixDecision.drop('priority-mismatch');
        }
        return _allowedOrDrop(
          priority,
          allowed: const {PriorityV2.alert, PriorityV2.normal},
          reason: 'priority-mismatch',
        );

      case EventTypeV2.protocolHello:
        return _allowedOrDrop(
          priority,
          allowed: const {PriorityV2.normal},
          reason: 'priority-mismatch',
        );

      case EventTypeV2.protocolNotice:
        return _allowedOrDrop(
          priority,
          allowed: const {PriorityV2.alert},
          reason: 'priority-mismatch',
        );

      case EventTypeV2.heartbeat:
      case EventTypeV2.tracePing:
      case EventTypeV2.traceAck:
        return _allowedOrDrop(
          priority,
          allowed: const {PriorityV2.normal},
          reason: 'priority-mismatch',
        );

      case EventTypeV2.chatMessage:
        return _allowedOrDrop(
          priority,
          allowed: const {PriorityV2.normal},
          reason: 'priority-mismatch',
        );

      default:
        // Unknown event_type — handled elsewhere (envelope_v2_spec §4.4); the
        // matrix simply abstains and lets the caller decide based on
        // is_experimental.
        return const MatrixDecision.drop('unknown-event-type');
    }
  }

  static bool _isSos(int p) =>
      p == PriorityV2.sosRed || p == PriorityV2.sosYellow;

  static MatrixDecision _allowedOrDowngrade(
    int priority, {
    required Set<int> allowed,
    required int downgradeTo,
  }) {
    if (allowed.contains(priority)) return const MatrixDecision.accept();
    return MatrixDecision.downgrade(downgradeTo);
  }

  static MatrixDecision _allowedOrDrop(
    int priority, {
    required Set<int> allowed,
    required String reason,
  }) {
    if (allowed.contains(priority)) return const MatrixDecision.accept();
    return MatrixDecision.drop(reason);
  }
}
