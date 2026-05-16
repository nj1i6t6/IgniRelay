// Payload-budget validator (v0.3 Stage 0c).
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §9.
//
// Sender REJECTS at publish time when an envelope's serialized total exceeds
// the per-priority cap. Receiver re-validates as defense in depth (treat
// over-budget SOS as priority abuse). Both sides emit the spec-named
// `drop_reason` strings into mesh_trace_logs.

import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';

enum BudgetSide { sender, receiver }

class BudgetDecision {
  final bool ok;

  /// drop_reason from the §15.2 named codes; null when ok == true.
  final String? dropReason;

  /// The cap that was checked (for log readability).
  final int cap;

  const BudgetDecision._(this.ok, this.dropReason, this.cap);

  const BudgetDecision.ok(int cap) : this._(true, null, cap);
  const BudgetDecision.violate(String reason, int cap) : this._(false, reason, cap);
}

class PayloadBudgetV2 {
  /// Validate a serialized envelope's total wire size against its priority
  /// budget. Pass the FULL serialized `EventEnvelope` length (i.e. the bytes
  /// that travel through the chunker — including signature, author_key, etc.).
  static BudgetDecision check({
    required int priority,
    required int totalEnvelopeBytes,
    BudgetSide side = BudgetSide.sender,
  }) {
    if (priority == PriorityV2.sosRed ||
        priority == PriorityV2.sosYellow ||
        priority == PriorityV2.status) {
      if (totalEnvelopeBytes > kSosEnvelopeBudgetBytes) {
        return BudgetDecision.violate(
          side == BudgetSide.sender
              ? 'over-budget-sos-rejected'
              : 'over-budget-sos-received',
          kSosEnvelopeBudgetBytes,
        );
      }
      return const BudgetDecision.ok(kSosEnvelopeBudgetBytes);
    }
    if (priority == PriorityV2.resource) {
      if (totalEnvelopeBytes > kResourceEnvelopeBudgetBytes) {
        return const BudgetDecision.violate(
          'over-budget-priority',
          kResourceEnvelopeBudgetBytes,
        );
      }
      return const BudgetDecision.ok(kResourceEnvelopeBudgetBytes);
    }
    if (priority == PriorityV2.alert) {
      if (totalEnvelopeBytes > kAlertEnvelopeBudgetBytes) {
        return const BudgetDecision.violate(
          'over-budget-priority',
          kAlertEnvelopeBudgetBytes,
        );
      }
      return const BudgetDecision.ok(kAlertEnvelopeBudgetBytes);
    }
    // NORMAL (chat / heartbeat / trace / hello) is bounded only by the
    // hard cap MAX_ENVELOPE_BYTES from native_transport_v1 §4.6.
    if (totalEnvelopeBytes > kMaxEnvelopeBytes) {
      return const BudgetDecision.violate(
        'over-max-envelope-bytes',
        kMaxEnvelopeBytes,
      );
    }
    return const BudgetDecision.ok(kMaxEnvelopeBytes);
  }
}
