// v0.3 Stage 0c — payload-budget validator tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/payload_budget_v2.dart';

void main() {
  group('PayloadBudgetV2.check', () {
    test('SOS_RED at 240B (cap) passes', () {
      final d = PayloadBudgetV2.check(
        priority: PriorityV2.sosRed,
        totalEnvelopeBytes: kSosEnvelopeBudgetBytes,
      );
      expect(d.ok, true);
      expect(d.cap, 240);
    });

    test('SOS_RED at 241B fails with sender drop_reason', () {
      final d = PayloadBudgetV2.check(
        priority: PriorityV2.sosRed,
        totalEnvelopeBytes: kSosEnvelopeBudgetBytes + 1,
        side: BudgetSide.sender,
      );
      expect(d.ok, false);
      expect(d.dropReason, 'over-budget-sos-rejected');
    });

    test('SOS_RED at 241B fails with receiver drop_reason', () {
      final d = PayloadBudgetV2.check(
        priority: PriorityV2.sosRed,
        totalEnvelopeBytes: kSosEnvelopeBudgetBytes + 1,
        side: BudgetSide.receiver,
      );
      expect(d.ok, false);
      expect(d.dropReason, 'over-budget-sos-received');
    });

    test('STATUS shares the SOS budget', () {
      expect(
        PayloadBudgetV2.check(
          priority: PriorityV2.status,
          totalEnvelopeBytes: 240,
        ).ok,
        true,
      );
      expect(
        PayloadBudgetV2.check(
          priority: PriorityV2.status,
          totalEnvelopeBytes: 241,
        ).dropReason,
        'over-budget-sos-rejected',
      );
    });

    test('RESOURCE budget is 400B', () {
      expect(
        PayloadBudgetV2.check(
          priority: PriorityV2.resource,
          totalEnvelopeBytes: 400,
        ).ok,
        true,
      );
      expect(
        PayloadBudgetV2.check(
          priority: PriorityV2.resource,
          totalEnvelopeBytes: 401,
        ).dropReason,
        'over-budget-priority',
      );
    });

    test('ALERT budget is 800B', () {
      expect(
        PayloadBudgetV2.check(
          priority: PriorityV2.alert,
          totalEnvelopeBytes: 800,
        ).ok,
        true,
      );
      expect(
        PayloadBudgetV2.check(
          priority: PriorityV2.alert,
          totalEnvelopeBytes: 801,
        ).dropReason,
        'over-budget-priority',
      );
    });

    test('NORMAL bounded by MAX_ENVELOPE_BYTES', () {
      expect(
        PayloadBudgetV2.check(
          priority: PriorityV2.normal,
          totalEnvelopeBytes: kMaxEnvelopeBytes,
        ).ok,
        true,
      );
      expect(
        PayloadBudgetV2.check(
          priority: PriorityV2.normal,
          totalEnvelopeBytes: kMaxEnvelopeBytes + 1,
        ).dropReason,
        'over-max-envelope-bytes',
      );
    });
  });
}
