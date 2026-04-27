// map_view_models_test.dart
//
// Stage 7-r2：地圖頁 view model 的純單元測試。
//
// 重點：
//   1. MarkingDraftVm.copyWith 支援把 nullable 欄位顯式設為 null（透過 sentinel）；
//   2. SosStateVm.idle / MarkingDraftVm.idle 的 isActive / isEditing 推論。

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ignirelay_app/ui/screens/map/models/map_view_models.dart';

void main() {
  group('MarkingDraftVm', () {
    test('idle 預設關閉', () {
      const m = MarkingDraftVm.idle;
      expect(m.isActive, isFalse);
      expect(m.isEditing, isFalse);
      expect(m.center, isNull);
      expect(m.editingHazardId, isNull);
      expect(m.type, 'ROADBLOCK');
      expect(m.severity, 3.0);
      expect(m.radiusMeters, 200.0);
      expect(m.isPublishing, isFalse);
    });

    test('copyWith：未指定欄位保留原值', () {
      final base = MarkingDraftVm.idle.copyWith(
        isActive: true,
        center: const LatLng(23.97, 120.97),
        type: 'FIRE',
      );
      expect(base.isActive, isTrue);
      expect(base.type, 'FIRE');
      expect(base.severity, 3.0); // 沿用 idle
      expect(base.radiusMeters, 200.0); // 沿用 idle

      final next = base.copyWith(severity: 5.0);
      expect(next.severity, 5.0);
      expect(next.type, 'FIRE');
      expect(next.center, isNotNull);
    });

    test('copyWith：可顯式把 center / editingHazardId 設為 null（sentinel）', () {
      final m = MarkingDraftVm.idle.copyWith(
        isActive: true,
        editingHazardId: 'hz-001',
        center: const LatLng(24, 120),
      );
      expect(m.editingHazardId, 'hz-001');
      expect(m.isEditing, isTrue);

      final cleared = m.copyWith(
        isActive: false,
        editingHazardId: null,
        center: null,
      );
      expect(cleared.isActive, isFalse);
      expect(cleared.editingHazardId, isNull);
      expect(cleared.isEditing, isFalse);
      expect(cleared.center, isNull);
    });
  });

  group('SosStateVm', () {
    test('idle 表示未廣播 SOS', () {
      const s = SosStateVm.idle;
      expect(s.isActive, isFalse);
      expect(s.activeEventId, isNull);
      expect(s.urgency, 0);
      expect(s.description, '');
    });

    test('帶 eventId 視為 active', () {
      const s = SosStateVm(
        activeEventId: 'evt-1',
        urgency: 3,
        description: 'help',
      );
      expect(s.isActive, isTrue);
      expect(s.urgency, 3);
    });
  });

  group('MbTilesStateVm', () {
    test('initial 為 loading=true / available=false', () {
      const s = MbTilesStateVm.initial;
      expect(s.loading, isTrue);
      expect(s.available, isFalse);
      expect(s.errorKey, isNull);
      expect(s.themeGeneration, 0);
    });
  });
}
