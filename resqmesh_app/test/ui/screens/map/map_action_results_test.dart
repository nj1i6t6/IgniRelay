// map_action_results_test.dart
//
// Stage 7-r2：outcome sealed class 的判別與資料攜帶測試。

import 'package:flutter_test/flutter_test.dart';

import 'package:ignirelay_app/ui/screens/map/models/map_action_results.dart';

void main() {
  group('PublishHazardOutcome', () {
    test('switch 可窮舉所有 case', () {
      String label(PublishHazardOutcome o) {
        return switch (o) {
          PublishHazardPublished() => 'published',
          PublishHazardUpdated() => 'updated',
          PublishHazardConfirmedExisting() => 'confirmed-existing',
          PublishHazardNearbyConflict() => 'nearby',
          PublishHazardFailure() => 'failure',
          PublishHazardNoop() => 'noop',
        };
      }

      expect(label(const PublishHazardPublished()), 'published');
      expect(label(const PublishHazardUpdated()), 'updated');
      expect(label(const PublishHazardConfirmedExisting(typeKey: 'FIRE')),
          'confirmed-existing');
      expect(
          label(const PublishHazardNearbyConflict(
            distanceMeters: 50,
            confirmCount: 2,
            typeKey: 'ROADBLOCK',
            nearbyId: 'hz-9',
          )),
          'nearby');
      expect(label(const PublishHazardFailure('boom')), 'failure');
      expect(label(const PublishHazardNoop()), 'noop');
    });

    test('NearbyConflict 攜帶 distance / confirmCount / typeKey / nearbyId', () {
      const o = PublishHazardNearbyConflict(
        distanceMeters: 120,
        confirmCount: 4,
        typeKey: 'FLOOD',
        nearbyId: 'hz-x',
      );
      expect(o.distanceMeters, 120);
      expect(o.confirmCount, 4);
      expect(o.typeKey, 'FLOOD');
      expect(o.nearbyId, 'hz-x');
    });
  });

  group('TriageOutcome / CancelSosOutcome / Confirm / Delete', () {
    test('Triage 三個 case 全列', () {
      String label(TriageOutcome o) => switch (o) {
            TriagePublished() => 'pub',
            TriageRateLimited() => 'rate',
            TriageFailure() => 'fail',
          };
      expect(label(const TriagePublished(urgency: 2, description: 'hi')),
          'pub');
      expect(label(const TriageRateLimited('slow down')), 'rate');
      expect(label(const TriageFailure('err')), 'fail');
    });

    test('CancelSos / Confirm / Delete 各兩 case', () {
      String c1(CancelSosOutcome o) => switch (o) {
            CancelSosSucceeded() => 'ok',
            CancelSosFailure() => 'err',
          };
      String c2(ConfirmHazardOutcome o) => switch (o) {
            ConfirmHazardSucceeded() => 'ok',
            ConfirmHazardFailure() => 'err',
          };
      String c3(DeleteHazardOutcome o) => switch (o) {
            DeleteHazardSucceeded() => 'ok',
            DeleteHazardFailure() => 'err',
          };

      expect(c1(const CancelSosSucceeded()), 'ok');
      expect(c1(const CancelSosFailure('e')), 'err');
      expect(c2(const ConfirmHazardSucceeded(newCount: 3, typeKey: 'FIRE')),
          'ok');
      expect(c2(const ConfirmHazardFailure('e')), 'err');
      expect(c3(const DeleteHazardSucceeded()), 'ok');
      expect(c3(const DeleteHazardFailure('e')), 'err');
    });
  });
}
