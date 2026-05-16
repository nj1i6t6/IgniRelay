// v0.3 Stage 0c — tests for the §6 priority×event_type matrix.

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/priority_matrix_v2.dart';

void main() {
  group('PriorityMatrixV2', () {
    test('STATUS_UPDATE accepts SOS_RED and STATUS', () {
      expect(
        PriorityMatrixV2.check(EventTypeV2.statusUpdate, PriorityV2.sosRed).outcome,
        MatrixOutcome.accept,
      );
      expect(
        PriorityMatrixV2.check(EventTypeV2.statusUpdate, PriorityV2.status).outcome,
        MatrixOutcome.accept,
      );
    });

    test('STATUS_UPDATE downgrades NORMAL → STATUS', () {
      final d = PriorityMatrixV2.check(EventTypeV2.statusUpdate, PriorityV2.normal);
      expect(d.outcome, MatrixOutcome.downgrade);
      expect(d.downgradeTo, PriorityV2.status);
    });

    test('CHAT_MESSAGE on SOS_RED is dropped (priority abuse)', () {
      final d = PriorityMatrixV2.check(EventTypeV2.chatMessage, PriorityV2.sosRed);
      expect(d.outcome, MatrixOutcome.drop);
      expect(d.dropReason, 'priority-mismatch');
    });

    test('CHAT_MESSAGE on NORMAL accepts', () {
      expect(
        PriorityMatrixV2.check(EventTypeV2.chatMessage, PriorityV2.normal).outcome,
        MatrixOutcome.accept,
      );
    });

    test('SUPPLY_REQUEST: SOS_RED downgrades to SOS_YELLOW', () {
      final d = PriorityMatrixV2.check(EventTypeV2.supplyRequest, PriorityV2.sosRed);
      expect(d.outcome, MatrixOutcome.downgrade);
      expect(d.downgradeTo, PriorityV2.sosYellow);
    });

    test('SUPPLY_REQUEST: NORMAL upgrades to RESOURCE', () {
      final d = PriorityMatrixV2.check(EventTypeV2.supplyRequest, PriorityV2.normal);
      expect(d.outcome, MatrixOutcome.downgrade);
      expect(d.downgradeTo, PriorityV2.resource);
    });

    test('OFFICIAL_ALERT_CAP requires OFFICIAL_VERIFIED for SOS attempt', () {
      // Without OFFICIAL_VERIFIED, SOS attempt drops.
      final unverified = PriorityMatrixV2.check(
        EventTypeV2.officialAlertCap,
        PriorityV2.sosRed,
      );
      expect(unverified.outcome, MatrixOutcome.drop);

      // With OFFICIAL_VERIFIED, SOS attempt downgrades to ALERT.
      final verified = PriorityMatrixV2.check(
        EventTypeV2.officialAlertCap,
        PriorityV2.sosRed,
        context: const MatrixContext(sourceTrust: SourceTrust.officialVerified),
      );
      expect(verified.outcome, MatrixOutcome.downgrade);
      expect(verified.downgradeTo, PriorityV2.alert);
    });

    test('OFFICIAL_ALERT_SUMMARY: SOS attempt always drops', () {
      expect(
        PriorityMatrixV2.check(
          EventTypeV2.officialAlertSummary,
          PriorityV2.sosRed,
          context: const MatrixContext(sourceTrust: SourceTrust.officialVerified),
        ).outcome,
        MatrixOutcome.drop,
      );
    });

    test('PROTOCOL_HELLO and HEARTBEAT only accept NORMAL', () {
      expect(
        PriorityMatrixV2.check(EventTypeV2.protocolHello, PriorityV2.normal).outcome,
        MatrixOutcome.accept,
      );
      expect(
        PriorityMatrixV2.check(EventTypeV2.protocolHello, PriorityV2.alert).outcome,
        MatrixOutcome.drop,
      );
      expect(
        PriorityMatrixV2.check(EventTypeV2.heartbeat, PriorityV2.normal).outcome,
        MatrixOutcome.accept,
      );
      expect(
        PriorityMatrixV2.check(EventTypeV2.heartbeat, PriorityV2.sosRed).outcome,
        MatrixOutcome.drop,
      );
    });

    test('PROTOCOL_NOTICE only accepts ALERT', () {
      expect(
        PriorityMatrixV2.check(EventTypeV2.protocolNotice, PriorityV2.alert).outcome,
        MatrixOutcome.accept,
      );
      expect(
        PriorityMatrixV2.check(EventTypeV2.protocolNotice, PriorityV2.normal).outcome,
        MatrixOutcome.drop,
      );
    });

    test('unknown event_type drops', () {
      final d = PriorityMatrixV2.check(9999, PriorityV2.normal);
      expect(d.outcome, MatrixOutcome.drop);
      expect(d.dropReason, 'unknown-event-type');
    });
  });
}
