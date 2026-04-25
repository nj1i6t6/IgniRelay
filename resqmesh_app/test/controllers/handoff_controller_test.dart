// handoff_controller_test.dart
//
// Stage 6 (commit #10)：驗證 HandoffController 對跨平台 native event 的歸一化。
//
// - 新版兩端皆送 type=handoff_result + {resourceId, success}
// - 舊版 iOS 送 type=handshake_data（無驗證資訊）→ controller fallback 為 success=false
//
// 不需要 DB / FFI；純函式驗證。

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/controllers/handoff_controller.dart';

void main() {
  group('HandoffController.debugNormalize', () {
    test('handoff_result 直接透傳', () {
      final input = {
        'type': 'handoff_result',
        'device': 'dev-1',
        'resourceId': 'res-A',
        'success': true,
      };
      final out = HandoffController.debugNormalize(input);
      expect(out['type'], 'handoff_result');
      expect(out['resourceId'], 'res-A');
      expect(out['success'], isTrue);
      // 不應加 legacy flag
      expect(out.containsKey('legacy'), isFalse);
    });

    test('handshake_data fallback 成 handoff_result + success=false + legacy=true',
        () {
      final input = {
        'type': 'handshake_data',
        'device': 'dev-2',
        'data': [0x01, 0x02, 0x03],
      };
      final out = HandoffController.debugNormalize(input);
      expect(out['type'], 'handoff_result');
      expect(out['device'], 'dev-2');
      expect(out['success'], isFalse);
      expect(out['legacy'], isTrue);
      // resourceId 從未提供 → ''
      expect(out['resourceId'], '');
    });

    test('未知 type 原樣返回（不會吃掉訊息）', () {
      final input = {'type': 'something_else', 'foo': 'bar'};
      final out = HandoffController.debugNormalize(input);
      expect(out, equals(input));
    });
  });
}
